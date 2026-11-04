# Entity Spawner Addon Guidelines

## Purpose

This addon provides generic scene lookup and Node3D instantiation at configured
spawn points. The root `AGENTS.md` also applies.

The addon owns spawning mechanics only. Wave progression, barracks production,
factions, combat stats, costs, and entity balance belong to game code.

## Public API

- `EntitySpawnCatalog` maps stable `StringName` IDs to `PackedScene` resources.
- `EntitySpawner` accepts a catalog, a target parent, and `Marker3D` spawn
  points.
- `spawn_entity()` selects a configured point using the selected policy.
- `spawn_entity_at_index()` uses a specific configured point.
- `spawn_entity_at_point()` uses an explicit `Marker3D`.
- `spawn_entity_at_transform()` supports callers that calculate transforms.
- Every spawned scene root must inherit `Node3D`.
- Failed spawns return `null`, report an error, and emit `spawn_failed`.
- Successful spawns emit `entity_spawned` after parenting and positioning.

## Standalone Boundary

- Do not import EntityDatabase, wave code, barracks code, game enums, or game
  scenes.
- Receive all spawnable scenes through `EntitySpawnCatalog`.
- Treat catalog IDs as opaque identifiers. Do not interpret prefixes, factions,
  or entity types.
- Receive spawn locations through `Marker3D` references or a call argument.
- Do not discover game nodes by fixed paths, groups, names, or autoloads.
- Keep pooling optional and addon-owned if it is introduced later.

## Catalog Contract

- IDs use stable lowercase `snake_case` names supplied by the consuming game.
- An ID must not be empty and its scene must not be null.
- The catalog is the spawner's whitelist; unregistered IDs must fail clearly.
- Do not add fallback paths or dynamically construct `res://` paths from IDs.
- The game may share one catalog across multiple spawner instances.

## Spawn Points

- Prefer `Marker3D` nodes over hard-coded world coordinates.
- Read `global_transform` at spawn time so moving buildings and map sections
  remain supported.
- Ignore freed or invalid markers during automatic selection.
- Keep random and sequential selection deterministic when a nonzero seed is
  configured.
- An explicit index refers to the exported `spawn_points` array and must be
  bounds-checked.

## Ownership And Lifecycle

- Add the entity to its target parent before assigning `global_transform`.
- Use the spawner itself when no explicit parent is configured.
- Do not retain ownership of spawned entities in the base implementation.
- Do not free spawned entities when the spawner exits the tree unless an
  explicit ownership or pooling contract is added.
- Free a rejected scene instance when its root type is invalid.

## Editor Plugin

- Keep the catalog and spawner custom type registration symmetric.
- Register types in `_enter_tree()` and remove them in reverse order in
  `_exit_tree()`.
- The runtime scripts must remain usable through `class_name` without editor
  services.

## Verification

- Verify missing catalogs, unknown IDs, null scenes, invalid point indices,
  empty point lists, and non-Node3D scene roots.
- Verify random, seeded random, sequential, explicit point, and explicit
  transform spawning.
- Verify separate enemy and friendly spawner instances can share a catalog but
  use different parents and points.
- Enable, disable, and re-enable the plugin in a minimal Godot 4.6 project.
- Confirm the addon works without EntityDatabase or game code installed.
