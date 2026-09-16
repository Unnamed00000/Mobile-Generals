# Mobile RTS - Infantry Prototype 0.1

Prototype 0.1 for an original mobile RTS inspired by classic real-time strategy pacing. The GitHub repository is currently named `Mobile-Generals`, while the active in-project prototype focuses only on the infantry command feel.

The active match scene now keeps the infantry command prototype and adds a small base-building loop: one battlefield, RTS camera, 6 player Riflemen, 1 Worker, 1 HQ, 4 enemy Riflemen, tap selection, SELECT drag multi-selection, formation movement, attack, health, death, victory, defeat, worker construction, HQ worker training, and simple Resource Center income.

Older production, minimap, and vehicle-era files remain in the repository for later stages, but tanks, cars, aircraft, multiplayer, Firebase, and large tech systems are not active in the current match scene.

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
- Tap one friendly Rifleman: select him.
- Tap the Worker: select him. The Worker can move, build, but cannot attack.
- With the Worker selected: build Resource Center, Power Plant, Barracks, or Defense Post.
- Place the Resource Center near the resource crates. A completed Resource Center adds money deliveries over time.
- Tap the HQ: train another Worker.
- Tap SELECT, drag over friendly units, then release: multi-select.
- Tap terrain with selected units: move there.
- Tap an enemy Rifleman with selected Riflemen: attack.
- Eliminate all enemy Riflemen to win.

### Desktop Debug

- Left click a unit: select it.
- Click SELECT, drag over friendly Riflemen, then release: multi-select.
- Left click ground with units selected: move selected units.
- Left click enemy with units selected: attack.
- Left click the Worker or HQ to use their contextual build/training buttons.
- Mouse wheel: zoom.
- Drag with middle mouse: pan the camera.

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

- Stage 1 active: landscape battlefield, camera drag/pinch, 6 Riflemen, 1 Worker, 4 enemy Riflemen, selection, drag multi-selection, movement, attack, health, and death.
- Early Stage 2/3 active by request: starting HQ, HQ Worker production, Worker construction, Resource Center placement near resources, and simple money deliveries.
- Stage 3 later refinement: visible human collectors walking between Resource Center and resource point.
- Stage 4 later: MG, RPG, Sniper, production queue, quick filters, and groups 1-4.

## Android Notes

The project is configured for landscape orientation in `project.godot`. Touch input and mouse debug controls both feed the same match command path, so Android controls can evolve without splitting game logic.
