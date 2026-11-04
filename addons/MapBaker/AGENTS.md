# MapBaker Addon Guidelines

## Purpose

MapBaker converts normalized row-major terrain data into meshes, optional tile
lines, trimesh collision, and saved `PackedScene` resources. The root
`AGENTS.md` also applies.

Map generation, random seeds, rotation, symmetry, decoration placement, and
gameplay fairness do not belong to this addon.

## Standalone Boundary

- Do not depend directly on `EnumMappings`, `MapSpawner`, or other game code.
- Receive terrain category IDs, colors, materials, and bake policy through an
  addon-owned configuration resource or method arguments.
- Keep geometry and persistence code usable with only Godot and this directory.
- Do not encode game-specific terrain names in the mesh builder.
- Receive tile size, terrain colors, edge policy, lines, and collision through
  `MapBakerConfig`.

## Terrain Contract

Input is row-major: `map_data[y][x]`. A normalized cell contains:

```text
{
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

- Map X maps to world X, map Y maps to world Z, and terrain height maps to
  world Y.
- Do not mutate input map data.
- Define behavior for empty maps, malformed cells, ragged rows, and map edges.
- A chunk bake receives the complete map plus `Rect2i` bounds so geometry can
  inspect neighbors outside the chunk without baking them.

## Geometry Invariants

- Do not change triangle winding without checking visible normals, backface
  behavior, raycasts, and trimesh collision.
- Keep visual geometry and collision geometry aligned.
- Test flat tiles, each ramp direction, mixed corner heights, negative heights,
  and exposed map edges.
- Set scene ownership recursively before `PackedScene.pack()`.
- Return or report save errors; never claim a bake succeeded when packing or
  resource saving failed.

## Plugin Lifecycle

- `plugin.cfg` must point to the only active editor plugin entry script.
- Keep `MapBaker` custom type registration and removal symmetric.
- Remove obsolete plugin entry scripts rather than keeping ambiguous parallel
  implementations.

## Package Boundary

- Keep one canonical `MapMeshBaker` implementation.
- `MapCollisionBaker` remains an internal baking utility, not a separate
  plugin.
- Runtime map generation belongs to the standalone `map_generator` addon.
- Game code owns adapters from game enums and rendering policy into
  `MapBakerConfig`.
- PackedScene export is an optional editor/debug path. Normal generated runs
  should bake in memory and remain reproducible from generation metadata.

## Verification

- Bake 1x1, rectangular, empty, malformed, ramped, and negative-height maps.
- Verify chunk boundaries against full-map baking and ensure no internal side
  walls are introduced.
- Verify mesh normals, line placement, collision, ownership, and save/load
  round trips.
- Run `godot --headless --path . --script addons/MapBaker/tests/map_baker_test.gd`
  from a compatible project containing the addon.
- Enable, disable, and re-enable the plugin in a minimal Godot 4.6 project.
- Confirm no game classes are required for parsing or baking.
