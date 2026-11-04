# Place Pickup Building Addon Guidelines

## Purpose

This addon manages a fixed inventory of unique buildings that alternate between
held and placed states. It owns preview, selection, placement, pickup, and
serializable state mechanics. The root `AGENTS.md` also applies.

## Standalone Boundary

- Depend only on Godot and files inside this addon.
- Do not reference MapSpawner, EntityDatabase, EntitySpawner, game enums,
  resources, costs, navigation, or concrete building IDs.
- Receive building scenes, IDs, and footprints through
  `PlaceableBuildingDefinition` resources.
- Treat building IDs as opaque stable identifiers.
- Game code calculates candidate transforms and placement validity.

## State Contract

- Every definition represents one unique building.
- A building is either `HELD` or `PLACED`.
- A held building has no final scene instance managed by the system.
- A placed building has one final scene instance and a saved transform.
- Picking up a building frees its placed instance and returns it to held state.
- `PlacePickupBuildingSave` stores all states and the selected held building.
- The consuming game owns file paths and calls `ResourceSaver`/`ResourceLoader`.

## Placement Lifecycle

- Begin preview only for held buildings.
- Preview instances have processing and collision disabled.
- Game code calls `update_preview(transform, valid)` after authoritative map,
  occupancy, decoration, and navigation checks.
- Confirm only a valid preview; instantiate a separate final scene.
- Cancel always frees the preview without changing held state.
- Cycle selection only through held buildings in definition order.
- Do not commit game map data inside this addon. The game observes typed signals
  and performs or rolls back its own authoritative state changes.

## Scene Contract

- Building scene roots must inherit `Node3D`.
- Concrete scenes own visuals, hitboxes, health, tower logic, barracks logic,
  and storage logic.
- Preview tint is applied recursively as a material overlay.
- Final instances receive the stable building ID as addon-owned metadata.

## Input

- Only held-building selection input belongs to the base addon.
- Input action names are injected through `PlacePickupBuildingConfig`.
- Missing actions must be ignored safely.
- Placement, pickup targeting, rotation, and cancellation input remain game
  policy and should call the public API.

## Verification

- Test unique IDs, invalid scenes, and invalid footprints.
- Test held selection cycling, including zero and one held building.
- Test begin/update/confirm/cancel preview and collision disabling.
- Test pickup and re-placement.
- Test save/restore for mixed held and placed buildings.
- Enable, disable, and re-enable the plugin in a minimal Godot 4.6 project.
- Confirm the addon parses without any other addon or game code.
