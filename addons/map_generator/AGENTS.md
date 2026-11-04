# Map Generator Addon Guidelines

## Purpose

This addon deterministically generates row-major terrain cells and decoration
records from an explicit seed. The root `AGENTS.md` also applies.

## Standalone Boundary

- Depend only on Godot and files inside `addons/map_generator/`.
- Do not reference MapBaker, EntityDatabase, EntitySpawner, EnumMappings, game
  autoloads, game scenes, or game-specific enums.
- Treat terrain and decoration IDs as opaque values. Never derive paths or
  behavior from them.
- Keep all random and noise state local to a generation call.

## Public Data Contract

- `MapGeneratorConfig` owns dimensions, terrain IDs, height and noise settings,
  and decoration rules.
- `MapDecorationRule` owns a stable decoration ID, allowed terrain IDs,
  density, and collision classification.
- `MapGenerationResult` owns the seed, generator version, row-major map data,
  and decoration records.
- A cell contains `type`, `height`, and `corners`. Corners use `sw`, `se`,
  `nw`, and `ne` keys.
- A decoration record contains `id`, `grid_position`, `rotation_steps`, and
  `collision_mode`.

## Generation Invariants

- Generation requires an explicit integer seed and valid configuration.
- Generate complete rectangular data in `map_data[y][x]` order.
- Quantize cell heights using the configured height step and clamp them to the
  configured minimum and maximum.
- Calculate shared corner heights as the mean of adjacent in-bounds cell
  heights, so neighboring cells store identical values for their shared
  corners.
- Decoration placement and rotation must be reproducible for the same seed and
  configuration.
- Place at most one decoration per cell. The first matching successful rule in
  configuration order wins.
- An empty allowed-terrain list means the decoration may appear on any terrain.
- Return fresh arrays and dictionaries. Do not expose shared mutable generation
  state.

## Plugin Lifecycle

- Keep exactly one `plugin.cfg` entry point.
- Register custom resource types in `_enter_tree()` and remove them in reverse
  order in `_exit_tree()`.
- Runtime classes must remain usable through `class_name` without editor
  services.

## Verification

- Check identical seeds for deep equality and different seeds for useful
  variation.
- Check rectangular dimensions, row-major order, shared corners, quantized
  heights, terrain selection, decoration filtering, and density boundaries.
- Enable, disable, and re-enable the plugin in a minimal Godot 4.6 project.
- Confirm the addon parses without any other addon or game code.
