# Police Officer Simulator

A lightweight Godot 4 project for Windows PC and Android, set in the fictional Mirage Hills Police Department.

## Current playable prototype

- Procedural role-based NPCs: civilians, sheriff/police, EMS and firefighters.
- A fictional 911 call and department radio panel, with incident acceptance and a location marker.
- Multiplayer foundation: host/join menu, up to 8 peers, player-position synchronization and shared dispatch messages. Initial testing is intended for LAN; internet hosting requires reachable UDP port 7000 or a dedicated server.

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
- `PoliceOfficerSimulator.exe` for Windows x86_64, artifact `PoliceOfficerSimulator-Windows-PC`.
- `PoliceOfficerSimulator.apk` for Android arm64, artifact `PoliceOfficerSimulator-Android-APK`.

Open the repository's **Actions** tab and select the latest successful run. Download the Windows and Android artifacts separately.

## Important scope note

This is an early playable prototype, not a finished commercial simulator. The repository did not contain the officer `.glb` models mentioned in earlier development, so the current build uses generated placeholder characters and a primitive patrol car. NPCs use lightweight wandering behavior. The 911/radio loop and multiplayer are an early foundation and still need end-to-end testing on two devices; the prototype does not yet have full emergency response AI, traffic systems, arrest/citation mechanics, imported rigged character animations, sound, saves or production-quality vehicle physics.

## Engine

Godot 4.7.2 stable. Project scripts and export presets are maintained in this repository.