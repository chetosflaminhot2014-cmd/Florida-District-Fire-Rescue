#!/usr/bin/env python3
"""Static integrity checks for the F.D.F.R. Godot project."""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
errors = []
warnings = []

def resolve_godot_resource(reference: str):
    """Resolve res:// paths directly and uid:// scene references from scene headers."""
    if reference.startswith("res://"):
        path = ROOT / reference.removeprefix("res://")
        return path if path.is_file() else None
    if reference.startswith("uid://"):
        uid = reference
        for candidate in ROOT.rglob("*.tscn"):
            if ".git" in candidate.parts or ".godot" in candidate.parts:
                continue
            try:
                header = candidate.read_text(encoding="utf-8", errors="replace")[:1000]
            except OSError:
                continue
            if re.search(r'\buid="' + re.escape(uid) + r'"', header):
                return candidate
        return None
    return None

project_file = ROOT / "project.godot"
if not project_file.is_file():
    errors.append("Missing project.godot")
else:
    project = project_file.read_text(encoding="utf-8")
    scene_match = re.search(r'^run/main_scene="([^"]+)"', project, re.M)
    if not scene_match:
        errors.append("project.godot has no run/main_scene")
    else:
        scene_ref = scene_match.group(1)
        scene = resolve_godot_resource(scene_ref)
        if scene is None:
            errors.append(f"Cannot resolve main scene reference: {scene_ref}")
        else:
            scene_text = scene.read_text(encoding="utf-8", errors="replace")
            for resource in re.findall(r'path="(res://[^"]+)"', scene_text):
                if resolve_godot_resource(resource) is None:
                    errors.append(f"Main scene references missing required resource: {resource}")

for script in ROOT.rglob("*.gd"):
    if ".git" in script.parts or ".godot" in script.parts:
        continue
    content = script.read_text(encoding="utf-8", errors="replace")
    for resource in re.findall(r'"(res://[^"]+)"', content):
        if any(token in resource.lower() for token in ("assets/earth2road/", "assets/florida_city/", ".glb", ".gltf")):
            if resolve_godot_resource(resource) is None:
                warnings.append(f"Optional asset not present: {resource}")

for warning in sorted(set(warnings)):
    print(f"WARNING: {warning}")
for error in errors:
    print(f"ERROR: {error}")
if errors:
    sys.exit(1)
print("F.D.F.R. static integrity checks passed.")
