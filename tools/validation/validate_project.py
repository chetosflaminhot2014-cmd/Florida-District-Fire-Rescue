#!/usr/bin/env python3
"""Static integrity checks for the F.D.F.R. Godot project."""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
errors = []
warnings = []

project_file = ROOT / "project.godot"
if not project_file.is_file():
    errors.append("Missing project.godot")
else:
    project = project_file.read_text(encoding="utf-8")
    scene_match = re.search(r'^run/main_scene="([^"]+)"', project, re.M)
    if not scene_match:
        errors.append("project.godot has no run/main_scene")
    else:
        scene_path = scene_match.group(1).replace("res://", "")
        scene = ROOT / scene_path
        if not scene.is_file():
            errors.append(f"Main scene does not exist: {scene_path}")
        else:
            scene_text = scene.read_text(encoding="utf-8", errors="replace")
            for path in re.findall(r'path="res://([^"]+)"', scene_text):
                if not (ROOT / path).is_file():
                    errors.append(f"Main scene references missing required resource: {path}")

# Validate required project scripts and scene resource references. Candidate GLB/map
# paths in scripts are optional fallbacks and are intentionally warnings, not failures.
for script in ROOT.rglob("*.gd"):
    if ".git" in script.parts or ".godot" in script.parts:
        continue
    content = script.read_text(encoding="utf-8", errors="replace")
    for resource in re.findall(r'"res://([^"]+)"', content):
        if any(token in resource for token in ("assets/earth2road/", "assets/florida_city/", ".glb", ".gltf", ".tscn")):
            if not (ROOT / resource).exists():
                warnings.append(f"Optional asset not present: {resource}")

for warning in sorted(set(warnings)):
    print(f"WARNING: {warning}")
for error in errors:
    print(f"ERROR: {error}")
if errors:
    sys.exit(1)
print("F.D.F.R. static integrity checks passed.")
