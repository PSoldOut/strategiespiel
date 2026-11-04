class_name WorldProgressBar3D
extends Node3D
## Billboarded world-space progress bar used by buildings.

@export var width: float = 2.0
@export var height: float = 0.18
@export var background_color := Color(0.08, 0.08, 0.08, 0.9)
@export var fill_color := Color(0.2, 0.85, 0.25, 1.0)

var _ratio := 1.0

@onready var background: MeshInstance3D = $Background
@onready var fill: MeshInstance3D = $Fill


func _ready() -> void:
	background.mesh = _create_quad_mesh(background_color)
	fill.mesh = _create_quad_mesh(fill_color)
	_update_fill()


func set_ratio(value: float) -> void:
	_ratio = clampf(value, 0.0, 1.0)
	if is_node_ready():
		_update_fill()


func get_ratio() -> float:
	return _ratio


func _create_quad_mesh(color: Color) -> QuadMesh:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.no_depth_test = true
	material.albedo_color = color

	var quad := QuadMesh.new()
	quad.size = Vector2(width, height)
	quad.material = material
	return quad


func _update_fill() -> void:
	fill.scale.x = _ratio
	fill.position.x = -width * (1.0 - _ratio) * 0.5
