# Game Development Guidelines

## Scope

This file applies to game code, game scenes, project configuration, and game
data outside `addons/`. The root `AGENTS.md` also applies. Addon changes must
follow the addon's local `AGENTS.md` instead of introducing game-specific logic
into the addon.

## Project Profile

- Engine: Godot 4.6.
- Language: GDScript.
- Renderer: Forward Plus.
- Physics: Jolt Physics.
- Main scene: `Main.tscn`.
- `GameManager/game_manager.gd` owns the high-level state transition and places
  the active state below `CurrentStateRoot`.
- The current states are the main menu and the PVE game run.

## Game Vision

The game combines the escalating horde pressure of the Vampire Survivors genre
with real-time strategy and tower-defense elements.

- The player directly controls one player character.
- Hordes of monsters attack the player.
- The player also controls a small defensive base and allied soldiers.
- Character combat, base defense, and unit support are parts of the same run.
- The initial implementation is single-player only.

The game should preserve constant pressure on the player while making building
placement and allied-unit support meaningful. RTS systems must support the
action-focused core rather than turn the game into a traditional economy-heavy
RTS.

## Core Player Assets

The baseline player setup contains exactly one of each initial building type:

1. **Tower**: Provides defensive support against attacking monsters.
2. **Barracks**: Spawns allied soldiers that fight the monster hordes.
3. **Storage**: Represents the player's resource storage and base economy.

The player character and these three buildings are separate gameplay entities
with separate health, behavior, and configuration. Shared behavior should come
from reusable components rather than checks for scene or node names.

Each of the three initial buildings exists exactly once. A building is either
held by the player or placed in the world. Held buildings can be cycled through
configured InputMap actions, previewed, placed, picked up again, and restored
from saved state.

The initial placeholder assets are game-owned:

- `buildings/tower.tscn`: 1x1 footprint with `AttackOrigin`.
- `buildings/barracks.tscn`: 2x2 footprint with `UnitSpawnPoint`.
- `buildings/storage.tscn`: 2x1 footprint with `DepositPoint`.
- `buildings/building_placement.tscn`: preconfigured placement inventory.

Standard building input actions are:

- `building_select_next`: physical E key.
- `building_select_previous`: physical Q key.
- `building_place`: left mouse button.
- `building_pickup`: right mouse button.
- `building_rotate`: physical R key.
- `building_cancel`: Escape key.

The standalone addon handles held-building selection actions. A game-owned
placement controller handles place, pickup targeting, rotation, cancellation,
map validation, costs, and authoritative occupancy updates.

Building types, unit types, monster types, teams, and gameplay states are
closed domains. Represent them with enums and data definitions instead of raw
strings or unexplained integer values.

## Core Gameplay Loop

The initial gameplay loop is:

1. The player controls the character and maintains the defensive base.
2. Monster hordes enter the map and pressure the player and their assets.
3. The tower contributes automated defensive damage.
4. The barracks reinforces the player by spawning allied soldiers.
5. The storage supports resources required by the base systems.
6. Horde pressure escalates until the run reaches its win or loss condition.

Exact wave timing, progression, resource types, construction rules, upgrades,
and win conditions are not defined yet. Do not hard-code assumptions about
them before their design is added to this document.

The current minimal playable loop implements:

- A fresh 32x32 generated map with heights from -2.0 to 2.0 in 0.5 steps for
  every run.
- Runtime terrain currently uses grass only; gold and silver remain entity
  resources and are never represented as terrain tiles.
- WASD player movement and automatic attacks against nearby enemies.
- Increasing waves of melee crawlers and ranged spitters that pursue and damage
  the player or the nearest placed building.
- Tower projectile attacks with a range indicator and Barracks soldier spawning
  with a visible spawn timer.
- Defeated enemies grant gold only while a living Storage is placed.
- Placed buildings have life and world-space health bars. Destroyed buildings
  return to held state, and every newly placed instance starts at full life.
- Building selection, preview, placement, rotation, pickup, and held state.
- HUD for life, wave, enemies, elapsed time, gold, and selected building.
- A run-over screen with restart and main-menu actions.

This is a functional baseline, not final balance. Enemy archetype diversity,
upgrade modifiers, resource costs, navigation, win conditions, and polished
combat feedback remain later work.

## Delivery Scope

Implement features in this order unless a task explicitly changes the priority:

1. Single-player character movement and combat.
2. Monster spawning, navigation, targeting, and horde progression.
3. Tower, barracks, storage, and allied-soldier gameplay.
4. Run progression, balancing, user interface, and persistence.
5. Leaderboards.
6. Multiplayer.

Leaderboards and multiplayer are planned features, not current requirements.
Do not add networking, accounts, remote services, replication, lobbies, or
leaderboard backends during the initial single-player implementation.

Keep gameplay state separate from presentation so later systems can observe run
results and authoritative state without rewriting core combat. This future
compatibility must not add speculative infrastructure to current tasks.

## Architecture

- Keep scene lifecycle and orchestration in `Node`, `Node3D`, and `Control`
  scripts.
- Keep reusable data transformations in static `RefCounted` services.
- `MapSpawner/MapSpawner.gd` applies generated maps and exposes runtime
  rendering and grid queries.
- Services below `MapSpawner/` own terrain, grid, corners, resources, buildings,
  definitions, and rendering concerns.
- `addons/map_generator/` deterministically generates terrain and decoration
  records from an explicit seed and primitive configuration.
- `addons/MapBaker/` converts complete or bounded terrain data into runtime
  meshes and collision. It does not generate map content.
- `addons/entity_spawner/` owns generic catalog lookup and scene instantiation.
  It does not decide what the game should spawn or when.
- `addons/follow_camera/` owns input-free target following and camera smoothing.
  Game code selects the player target and supplies camera configuration.
- `addons/place_pickup_building/` owns held/placed building state, preview,
  selection cycling, pickup, and serializable snapshots.
- Game code remains authoritative for building placement validity, map
  occupancy, costs, blocked decorations, navigation, and placement input.
- Wave and barracks systems use separate `EntitySpawner` instances with
  game-owned catalogs, parents, and spawn points.
- The game may configure and consume addons. Addons must not reference these
  game directories directly.

Do not move responsibilities between these layers as part of an unrelated
change.

## Game Enums And IDs

`addons/EnumsMappings/enum_mappings.gd` currently defines the game's shared
enum IDs. Some values are used by persisted entity and building state.

- Treat existing integer values as a save-data contract.
- Add new persisted values at the end with explicit integer assignments.
- Do not reorder, recycle, or silently rename values.
- A rename or value change requires a data migration and compatibility plan.
- Use these enums in game code instead of raw strings or unexplained integers.
- Do not make standalone addons import `EnumMappings`.
- Translate game enum values into each addon's configuration or adapter at the
  game/addon boundary.

## Runtime Map Data

Maps exist only in memory and are freshly generated for every gameplay run.
There is no map save, load, reset, or baked-scene persistence path.

Terrain is row-major:

```text
map_data[y][x] = {
    "type": int,
    "height": float,
    "corners": {
        "sw": float,
        "se": float,
        "nw": float,
        "ne": float
    }
}
```

- X maps to world X, map Y maps to world Z, and height maps to world Y.
- Keep terrain, resource, and building dimensions synchronized.
- Build meshes and collision in memory through MapBaker.

## Runtime Map Generation

- Every new normal run receives a newly generated map and a new random seed.
- Shared leaderboard challenges may deliberately use a common seed later.
- Maps and generation seeds are not persisted between runs.
- Runtime meshes and collision are rebuilt in memory through MapBaker.
- `MapSpawner.generate_new_run_map()` applies a `MapGenerationResult` without
  writing files.
- An explicit seed is used only for deterministic tests or future shared
  challenges.

The generation order is:

1. Game code selects the run seed and creates `MapGeneratorConfig` through the
   game adapter.
2. `SeededMapGenerator` generates terrain, shared corners, and decoration
   records.
3. Game post-processing reserves the player/base area, validates navigation,
   and applies gameplay placement policy.
4. MapBaker creates chunk meshes and collision using the complete map as
   neighbor context.
5. EntitySpawner instantiates decoration scenes from the generated records.

## Generated Decorations

- A decoration record contains a stable ID, grid position, quarter-turn
  rotation, and collision classification.
- `CollisionMode.NONE` selects a visual-only decoration scene.
- `CollisionMode.BLOCKING` selects a scene that must contain a
  `CollisionShape3D` and participate in navigation/placement blocking.
- The generator never loads decoration scenes or creates collision geometry.
- The game-owned spawn catalog maps decoration IDs to concrete `PackedScene`
  resources.
- `MapDecorationSpawner` places generated records through `EntitySpawner` and
  warns when a blocking scene contains no collision shape.
- Decoration scenes own their hitboxes: visual-only scenes omit collision;
  blocking scenes include `StaticBody3D`/`CollisionShape3D` nodes.
- Blocking decorations must be excluded from the player start area, required
  paths, building footprints, and reserved monster entrances during game
  post-processing.

## Entity Definitions

- The game currently reads `entity_definitions.json` from the repository root.
- Keep persisted IDs synchronized with `EnumMappings`.
- Treat the definition schema as a data contract; do not mix symbolic and
  numeric key formats without migration logic.
- Validate changed definition files as JSON.
- The separate EntityDatabase addon has its own contract and instructions. Do
  not assume its data file is interchangeable with the game file.

The target EntityDatabase content for the current game consists of:

- Resources: Gold and Silver.
- Buildings: Tower (1x1), Barracks (2x2), and Storage (2x1).
- Units: ten enemy archetypes and four friendly archetypes.
- Unit stat dimensions: range, speed, life, and damage.

EntityDatabase stores only the relative `LOW`, `NORMAL`, and `HIGH` stat tier
for each unit stat. It does not own final combat values.

- Resolve enemy values through a separate game-owned wave and difficulty
  balance configuration.
- Resolve friendly values from base balance and the active run's accumulated
  Vampire Survivors-style modifiers.
- Keep modifiers in a separate definition system. A modifier needs a stable ID,
  target filters, affected stat, operation, value, stacking rule, and optional
  limits.
- Do not embed selected modifiers or wave-scaled values in unit archetypes.
- Do not assume a fixed formula such as `wave * tier` until the balance model is
  explicitly designed and documented.

## Scenes And Resources

- Update scene hierarchy, node paths, exported references, and signal
  connections together.
- Prefer exported node references or unique names over fragile deep node paths.
- Do not rename existing scene or addon paths merely to normalize casing.
- Runtime map generation must not write project files.

## Known Baseline Constraints

Do not attribute these pre-existing issues to an unrelated change, and do not
silently fix them outside the requested scope:

- Parts of `ResourceSystem/` refer to obsolete enum names.
- There is no game-wide automated test suite or export preset.

## Verification

- Use Godot 4.6 for parser, import, editor, and runtime checks.
- Run `git diff --check`.
- Parse every changed JSON file, for example with
  `python3 -m json.tool <file> >/dev/null`.
- Check changed scenes for valid, case-correct `res://` references.
- Exercise the smallest affected flow: main menu, state transition, game run,
  map generation, or map bake.
- Run `godot --headless --path . --script gameplay/tests/game_loop_test.gd`
  after changing the PVE loop.
- Run `godot --headless --path . --script gameplay/entities/tests/entities_test.gd`
  after changing combat entities.
- Run import-heavy Godot checks in a temporary copy when possible, then inspect
  the original working tree for generated changes.
