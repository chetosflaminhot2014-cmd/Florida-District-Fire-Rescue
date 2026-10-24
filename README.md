# Police Officer Simulator

A lightweight Godot 4 project for Windows PC and Android, set in the fictional Mirage Hills Police Department.

## Current playable prototype

- Main menu, character selection, settings and credits.
- Procedurally generated city blocks, a road grid, sidewalks, lane markings, a police station and trees.
- Third-person officer movement and camera control.
- Civilian NPCs that wander around the city.
- A simple patrol vehicle that can be entered/exited and driven.
- On-screen movement, run and vehicle buttons for touch devices.
- Keyboard controls for PC: WASD/arrows to move, Shift to run, E to enter/exit the patrol car, mouse to look, Esc to release/capture the mouse.
- Low-detail procedural geometry and Godot's Compatibility renderer to target modest hardware.

## Build downloads

GitHub Actions workflow **Build Police Officer Simulator (PC + Android)** exports:
- `PoliceOfficerSimulator.exe` for Windows x86_64.
- `PoliceOfficerSimulator.apk` for Android arm64.

Open the repository's **Actions** tab and select the latest successful run, then download the `Police-Officer-Simulator-PC-Android` artifact.

## Important scope note

This is an early playable prototype, not a finished commercial simulator. The repository did not contain the officer `.glb` models mentioned in earlier development, so the current build uses generated placeholder characters and a primitive patrol car. NPCs use lightweight wandering behavior; traffic systems, missions, arrest/citation mechanics, animation, sound, saves and production-quality vehicle physics are not implemented yet.

## Engine

Godot 4.7.2 stable. Project scripts and export presets are maintained in this repository.