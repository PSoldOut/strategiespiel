# Minimal Game Loop

`game_run.tscn` is the current playable PVE state.

## Run Flow

1. Generate a new flat 32x32 map from a random seed.
2. Spawn the player at the map center and attach the follow camera.
3. Start increasingly large enemy waves around the map perimeter.
4. Let the player move and automatically attack nearby enemies.
5. Allow Tower, Barracks, and Storage to be placed or picked up.
6. Let enemies attack the nearest player or placed building.
7. End the run when player life reaches zero.

## Controls

- WASD: move the player.
- E/Q: select the next or previous held building.
- Left mouse button: place the active preview.
- Right mouse button: pick up a placed building.
- R: rotate the active building preview.
- Escape: cancel or resume the building preview.

## Building Roles

- Tower displays its range and automatically attacks nearby enemies.
- Barracks displays its spawn timer and periodically creates friendly soldiers.
- Storage enables gold collection from defeated enemies while placed and alive.
- Every building has life and a world-space health bar. New placements start at
  full life.

The loop intentionally uses direct movement on a flat generated map. Navigation,
multiple enemy archetypes, upgrades, costs, and final visual effects are later
systems.
