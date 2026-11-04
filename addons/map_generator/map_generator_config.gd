@tool
class_name MapGeneratorConfig
extends Resource

@export_range(1, 4096, 1, "or_greater") var width: int = 64
@export_range(1, 4096, 1, "or_greater") var height: int = 64
@export var default_terrain_id: int = 0
@export var secondary_terrain_id: int = 1
@export_range(-1.0, 1.0) var terrain_threshold: float = 0.0
@export var min_height: float = 0.0
@export var max_height: float = 8.0
@export_range(0.001, 1000.0, 0.001, "or_greater") var height_step: float = 1.0
@export_range(0.0001, 1.0, 0.0001, "or_greater") var noise_frequency: float = 0.05
@export var decoration_rules: Array[MapDecorationRule] = []
