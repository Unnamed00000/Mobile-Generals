# Mobile RTS Prototype

Prototype 0.1 for an original mobile RTS inspired by classic real-time strategy pacing. The GitHub repository is currently named `Mobile-Generals`, while the in-project working title stays `Mobile RTS Prototype` to keep the game identity original.

This repository currently includes Milestones 1-3 basics: a playable match scene with a test map, angled RTS camera, touch/mouse camera controls, one Builder unit, selection, movement commands, building placement, construction progress, and automatic Resource Center harvesting.

## Requirements

- Godot 4.x
- Android export templates when building for Android

No paid SDKs or paid services are required. Online multiplayer is intentionally not implemented yet; the folder structure leaves room for future networking, profiles, rooms, lobbies, matchmaking, and a dedicated backend.

## How To Run

1. Open this folder in Godot 4.x.
2. Open `res://scenes/match/match.tscn`.
3. Press Play. The project main scene already points at the match scene.

## Current Controls

### Android / Touch

- Drag one finger on free terrain: pan the RTS camera.
- Pinch with two fingers: zoom in and out.
- Tap the Builder: select it.
- Tap terrain while the Builder is selected: move it there.
- Select the Builder, tap a building button, drag/tap a placement location, then press Confirm.
- Build a Resource Center to deploy one Resource Truck. It automatically gathers resources and delivers +$500.

### Desktop Debug

- Left click a unit: select it.
- Left click ground with a unit selected: move selected units.
- Right click ground: move selected units.
- Mouse wheel: zoom.
- Drag with middle mouse: pan the camera.
- Select Builder, click a building button, move the ghost over terrain, then Confirm.
- Build a Resource Center to watch the Resource Truck loop between the resource field and the center.

## Project Structure

```text
res://
    scenes/
        match/
        maps/
        units/
        buildings/
        ui/
    scripts/
        core/
        units/
        buildings/
        economy/
        ai/
        camera/
        input/
        combat/
        ui/
        networking/
    assets/
        models/
        textures/
        audio/
        effects/
    data/
        units/
        buildings/
        factions/
```

## Milestone Status

- Milestone 1: map, camera, zoom, Builder, selection, movement.
- Milestone 2: construction placement, Power Plant, Resource Center, Barracks, War Factory, Defense Turret placeholders.
- Milestone 3: Resource Center economy loop, Resource Truck, and +$500 deliveries.
- Milestone 4 next: Rifleman, RPG, Tank, and production queues from Barracks and War Factory.
- Later milestones: army controls, combat, AI, minimap, Android polish.

## Android Notes

The project is configured for landscape orientation in `project.godot`. Touch input and mouse debug controls both feed the same match command path, so Android controls can evolve without splitting game logic.
