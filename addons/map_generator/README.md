# Map Generator

A standalone Godot 4.6 addon for deterministic terrain and decoration data
generation. It depends only on Godot and files in this directory.

## Runtime API

Create a `MapGeneratorConfig`, then call `SeededMapGenerator.generate()` with
an explicit integer seed:

```gdscript
var rule := MapDecorationRule.new()
rule.decoration_id = &"tree"
rule.allowed_terrain_ids = PackedInt32Array([1])
rule.density = 0.15
rule.collision_mode = MapDecorationRule.CollisionMode.BLOCKING

var config := MapGeneratorConfig.new()
config.width = 32
config.height = 24
config.default_terrain_id = 10
config.secondary_terrain_id = 20
config.decoration_rules = [rule]

var generator := SeededMapGenerator.new()
var result := generator.generate(config, 12345)
```

`generate()` returns `null` and reports an error when the configuration is
invalid. For the same configuration and seed, it returns equivalent data.

## Data Contract

`MapGenerationResult.map_data` is a rectangular row-major array addressed as
`map_data[y][x]`. Every cell is a fresh dictionary:

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

Each corner height is the mean of all adjacent in-bounds cell heights. Shared
corners therefore have exactly the same stored value in neighboring cells.

`MapGenerationResult.decorations` contains zero or more records:

```text
{
    "id": StringName,
    "grid_position": Vector2i,
    "rotation_steps": int,
    "collision_mode": MapDecorationRule.CollisionMode
}
```

Terrain and decoration IDs are opaque. The addon does not derive resource
paths, scenes, colors, or gameplay behavior from them. At most one decoration
is emitted per cell; the first successful rule in configuration order wins.
Collision mode is placement metadata. The consuming game selects a matching
scene with or without collision geometry.

## Configuration

- `width`, `height`: positive output dimensions.
- `default_terrain_id`, `secondary_terrain_id`: opaque integer terrain IDs.
- `terrain_threshold`: noise cutoff in the inclusive range `-1.0..1.0`.
- `min_height`, `max_height`: inclusive generated height bounds.
- `height_step`: positive quantization interval measured from `min_height`.
- `noise_frequency`: positive frequency used by local noise instances.
- `decoration_rules`: addon-owned placement rules.

Each `MapDecorationRule` requires a non-empty stable `decoration_id`. An empty
`allowed_terrain_ids` list allows every terrain; otherwise the filter is exact.
`density` is in `0.0..1.0`, and `collision_mode` is either `NONE` or
`BLOCKING`.
