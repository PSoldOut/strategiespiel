extends Node3D
class_name RTSMapTile


@export var base_color: Color
var cell_value = null
var grid_x: int = 0
var grid_y: int = 0

@onready var selector: MeshInstance3D = $Selector
@onready var click_body: StaticBody3D = $ClickBody

func _ready() -> void:
	add_to_group("map_tiles")
	_setup_selector()
	_create_material_variation()

	# Damit der Raycast vom StaticBody zurück zum Tile kommt
	click_body.set_meta("tile_ref", self)

func _create_material_variation() -> void:
	var mesh_instance := $Visual as MeshInstance3D
	if mesh_instance == null:
		return

	var mat := StandardMaterial3D.new()


	# leichte Variation pro Tile
	var variation := randf_range(-0.05, 0.05)

	mat.albedo_color = Color(
		base_color.r + variation,
		base_color.g + variation,
		base_color.b + variation
	)

	mat.roughness = 1.0
	mat.metallic = 0.0

	mesh_instance.material_override = mat

func set_tile_data(value, x: int, y: int) -> void:
	cell_value = value
	grid_x = x
	grid_y = y

func set_selected(selected: bool) -> void:
	if selector != null:
		selector.visible = selected

func set_hovered(hovered: bool) -> void:
	if selector != null:
		selector.visible = hovered


func _setup_selector() -> void:
	if selector == null:
		return

	var plane := PlaneMesh.new()
	plane.size = Vector2(2, 2)
	selector.mesh = plane

	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.2, 0.9, 1.0, 0.22)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.9, 1.0)
	mat.emission_energy_multiplier = 2.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	selector.material_override = mat
	selector.visible = false

	# flach auf die Tile-Oberseite legen
	selector.position = Vector3(0, 1.01, 0)
	selector.rotation_degrees = Vector3(0, 0, 0)
	selector.scale = Vector3(1, 1, 1)
