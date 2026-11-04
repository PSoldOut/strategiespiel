@tool
class_name MapDecorationRule
extends Resource

enum CollisionMode {
	NONE = 0,
	BLOCKING = 1,
}

@export var decoration_id: StringName
@export var allowed_terrain_ids: PackedInt32Array = PackedInt32Array()
@export_range(0.0, 1.0) var density: float = 0.0
@export var collision_mode: CollisionMode = CollisionMode.NONE
