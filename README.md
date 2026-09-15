# Mobile RTS Prototype

Prototype 0.1 for an original mobile RTS inspired by classic real-time strategy pacing. The GitHub repository is currently named `Mobile-Generals`, while the in-project working title stays `Mobile RTS Prototype` to keep the game identity original.

This repository currently includes Milestones 1-8 basics: a playable match scene with a test map, angled RTS camera, touch/mouse camera controls, one Builder unit, a starting Mobile HQ, selection, movement commands, building placement, construction progress, automatic Resource Center harvesting, unit production, army filters, control groups, mobile command buttons, enemy targets, combat, damage, destruction, simple enemy attack waves, victory, defeat, and a tappable minimap.

## Requirements

- Godot 4.x
- Android export templates when building for Android

No paid SDKs or paid services are required. Online multiplayer is intentionally not implemented yet; the folder structure leaves room for future networking, profiles, rooms, lobbies, matchmaking, and a dedicated backend.

## How To Run

1. Open this folder in Godot 4.x.
2. Open `res://scenes/match/match.tscn`.
3. Press Play. The project main scene already points at the match scene.

## Phone Preview

Every push to `main` builds a Godot Web preview with GitHub Actions and publishes it through GitHub Pages.

Preview URL:

```text
https://unnamed00000.github.io/Mobile-Generals/
```

Open that URL on a phone after the `Web Preview` action finishes. On the first setup, GitHub may require Pages to be enabled with `Settings -> Pages -> Source -> GitHub Actions`.

## Current Controls

### Android / Touch

- Drag one finger on free terrain: pan the RTS camera.
- Pinch with two fingers: zoom in and out.
- Tap the minimap: move the camera to that map area.
- Tap the Builder: select it.
- Tap terrain while the Builder is selected: move it there.
- Select the Builder, tap a building button, drag/tap a placement location, then press Confirm.
- Build a Resource Center to deploy one Resource Truck. It automatically gathers resources and delivers +$500.
- Select Barracks to produce Rifleman/RPG Soldier. Select War Factory to produce a Tank.
- Use All/Infantry/RPG/Tanks filters to select combat units. Long-press group 1-4 to save, tap 1-4 to recall.
- Use Move, Attack Move, Attack, and Stop from the army panel. Enemy units and an Enemy HQ are placed across the map.
- Defend the Mobile HQ from periodic enemy attack waves. Destroy the Enemy HQ to win.

### Desktop Debug

- Left click a unit: select it.
- Left click ground with a unit selected: move selected units.
- Right click ground: move selected units.
- Mouse wheel: zoom.
- Drag with middle mouse: pan the camera.
- Click the minimap: move the camera to that map area.
- Select Builder, click a building button, move the ghost over terrain, then Confirm.
- Build a Resource Center to watch the Resource Truck loop between the resource field and the center.
- Select Barracks or War Factory, then click unit buttons to fill the production queue.
- Use Ctrl+1 through Ctrl+4 to save selected combat units into groups. Press 1 through 4 to recall.
- Enemy units periodically attack player buildings and combat units. Destroy the Enemy HQ to trigger victory.

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
- Milestone 4: Rifleman, RPG Soldier, Main Battle Tank, and production queues from Barracks and War Factory.
- Milestone 5: mobile army selection categories, groups 1-4, Move, Attack placeholder, Attack Move, Stop.
- Milestone 6: enemies, combat, damage, destruction, and automatic attack behavior.
- Milestone 7: starting Mobile HQ, simple AI attack waves, victory, and defeat flow.
- Milestone 8: tappable minimap with player/enemy blips and camera frame.
- Milestone 9 next: Android polish, touch selection improvements, and APK build automation.

## Android Notes

The project is configured for landscape orientation in `project.godot`. Touch input and mouse debug controls both feed the same match command path, so Android controls can evolve without splitting game logic.
