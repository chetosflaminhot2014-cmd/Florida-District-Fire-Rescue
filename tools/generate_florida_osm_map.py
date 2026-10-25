#!/usr/bin/env python3
"""Build a compact, drivable Tampa, Florida map from OpenStreetMap data.

The generated JSON contains real road geometry and building footprints simplified
for a lightweight Godot mobile/desktop scene. OpenStreetMap attribution is required.
"""
from __future__ import annotations
import json
import math
import os
import sys
import time
import urllib.parse
import urllib.request

# Downtown Tampa and the adjacent waterfront. A small local area keeps mobile
# performance manageable; the airport and emergency facilities remain gameplay landmarks.
SOUTH, WEST, NORTH, EAST = 27.9360, -82.4770, 27.9650, -82.4390
CENTER_LAT = (SOUTH + NORTH) / 2.0
CENTER_LON = (WEST + EAST) / 2.0
WORLD_SPAN = 410.0
WORLD_LIMIT = WORLD_SPAN / 2.0
METERS_PER_DEG_LAT = 111320.0
METERS_PER_DEG_LON = 111320.0 * math.cos(math.radians(CENTER_LAT))
SCALE_X = WORLD_SPAN / ((EAST - WEST) * METERS_PER_DEG_LON)
SCALE_Z = WORLD_SPAN / ((NORTH - SOUTH) * METERS_PER_DEG_LAT)
OUT_PATH = "assets/florida_city/tampa_osm_map.json"
ENDPOINTS = [
    "https://overpass-api.de/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter",
]
QUERY = f"""[out:json][timeout:60];
(
  way["highway"~"^(motorway|trunk|primary|secondary|tertiary|residential|unclassified|service|living_street)$"]({SOUTH},{WEST},{NORTH},{EAST});
  way["building"]({SOUTH},{WEST},{NORTH},{EAST});
);
out body;
>;
out skel qt;"""

def request_map():
    encoded = urllib.parse.urlencode({"data": QUERY}).encode()
    last_error = None
    for endpoint in ENDPOINTS:
        for attempt in range(3):
            try:
                req = urllib.request.Request(encoded and endpoint, data=encoded, headers={
                    "User-Agent": "FDFR-Game-MapBuilder/1.0 (OpenStreetMap attribution in game)",
                    "Accept": "application/json",
                })
                with urllib.request.urlopen(req, timeout=100) as response:
                    return json.loads(response.read().decode("utf-8"))
            except Exception as exc:
                last_error = exc
                print(f"Overpass attempt {attempt + 1} failed at {endpoint}: {exc}", flush=True)
                time.sleep(3 + attempt * 3)
    raise RuntimeError(f"All Overpass endpoints failed: {last_error}")

def local_xy(lat, lon):
    x = (lon - CENTER_LON) * METERS_PER_DEG_LON * SCALE_X
    z = (CENTER_LAT - lat) * METERS_PER_DEG_LAT * SCALE_Z
    return round(max(-WORLD_LIMIT, min(WORLD_LIMIT, x)), 2), round(max(-WORLD_LIMIT, min(WORLD_LIMIT, z)), 2)

def main():
    data = request_map()
    nodes = {el["id"]: (el["lat"], el["lon"]) for el in data.get("elements", []) if el.get("type") == "node"}
    roads = []
    buildings = []
    for way in data.get("elements", []):
        if way.get("type") != "way":
            continue
        tags = way.get("tags", {})
        coords = [nodes[n] for n in way.get("nodes", []) if n in nodes]
        if len(coords) < 2:
            continue
        if "highway" in tags:
            highway = tags["highway"]
            width = {
                "motorway": 9.0, "trunk": 8.5, "primary": 7.5, "secondary": 6.5,
                "tertiary": 5.5, "residential": 4.4, "unclassified": 4.4,
                "living_street": 3.8, "service": 3.0,
            }.get(highway, 4.0)
            roads.append({
                "name": tags.get("name", ""),
                "kind": highway,
                "width": width,
                "points": [list(local_xy(lat, lon)) for lat, lon in coords],
            })
        if "building" in tags and len(coords) >= 4:
            ring = coords[:-1] if coords[0] == coords[-1] else coords
            xs = [(lon - CENTER_LON) * METERS_PER_DEG_LON * SCALE_X for lat, lon in ring]
            zs = [(CENTER_LAT - lat) * METERS_PER_DEG_LAT * SCALE_Z for lat, lon in ring]
            min_x, max_x = min(xs), max(xs)
            min_z, max_z = min(zs), max(zs)
            raw_w, raw_d = max_x - min_x, max_z - min_z
            if raw_w < 1.0 or raw_d < 1.0:
                continue
            area = raw_w * raw_d
            if area < 2.0:
                continue
            x, z = (min_x + max_x) / 2.0, (min_z + max_z) / 2.0
            if abs(x) > WORLD_LIMIT or abs(z) > WORLD_LIMIT:
                continue
            # Building models are intentionally scaled to readable gameplay size.
            width = round(max(5.0, min(17.0, raw_w)), 2)
            depth = round(max(5.0, min(17.0, raw_d)), 2)
            height = 5.5
            if tags.get("building") in ("apartments", "commercial", "office", "hotel", "hospital"):
                height = 10.0
            if tags.get("building:levels", "").isdigit():
                height = max(5.5, min(30.0, int(tags["building:levels"]) * 2.8))
            footprint = [list(local_xy(lat, lon)) for lat, lon in ring]
            buildings.append({
                "x": round(x, 2), "z": round(z, 2), "w": width, "d": depth,
                "h": round(height, 2), "kind": tags.get("building", "yes"),
                "levels": tags.get("building:levels", ""),
                "footprint": footprint,
            })
    # Keep a balanced mix of expressways, arterial roads, and local streets.
    # Sorting all roads by class first would fill the limit with highways and erase
    # the real neighborhood street pattern that makes Tampa recognizable.
    road_quotas = {
        "motorway": 45, "trunk": 45, "primary": 100, "secondary": 120,
        "tertiary": 130, "residential": 180, "unclassified": 35,
        "service": 35, "living_street": 10,
    }
    selected_roads = []
    for kind, quota in road_quotas.items():
        matching = [road for road in roads if road["kind"] == kind]
        matching.sort(key=lambda road: len(road["points"]), reverse=True)
        selected_roads.extend(matching[:quota])
    selected_ids = {id(road) for road in selected_roads}
    remaining = [road for road in roads if id(road) not in selected_ids]
    remaining.sort(key=lambda road: len(road["points"]), reverse=True)
    roads = selected_roads + remaining[:max(0, 700 - len(selected_roads))]
    roads = roads[:700]
    buildings.sort(key=lambda b: (b["kind"] not in ("hospital", "commercial", "apartments", "office"), -(b["w"] * b["d"])))
    buildings = buildings[:650]
    result = {
        "source": "OpenStreetMap contributors",
        "license": "ODbL-1.0",
        "area": "Downtown Tampa, Florida, USA",
        "bounds": {"south": SOUTH, "west": WEST, "north": NORTH, "east": EAST},
        "world_span": WORLD_SPAN,
        "roads": roads,
        "buildings": buildings,
    }
    os.makedirs(os.path.dirname(OUT_PATH), exist_ok=True)
    with open(OUT_PATH, "w", encoding="utf-8") as out:
        json.dump(result, out, separators=(",", ":"), ensure_ascii=False)
    print(f"Wrote {OUT_PATH}: {len(roads)} roads, {len(buildings)} buildings", flush=True)

if __name__ == "__main__":
    main()
