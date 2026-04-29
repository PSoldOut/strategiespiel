extends Node3D
class_name RTSMapTile

signal tile_clicked(tile: RTSMapTile)

var tile_value: int = 0
var height_value: float = 0.0
var ramp_value: int = 0
var grid_x: int = 0
var grid_y: int = 0

@onready var selector: MeshInstance3D = $Selector
@onready var click_body: StaticBody3D = $ClickBody


func _ready() -> void:
	add_to_group("map_tiles")
	_setup_selector()

	if click_body == null:
		push_error("ClickBody missing in MapTile")
		return

	click_body.input_event.connect(_on_click_body_input_event)
	click_body.set_meta("tile_ref", self)


func set_tile_data(tvalue: int, hvalue: float, rvalue: int, x: int, y: int) -> void:
	tile_value = tvalue
	height_value = hvalue
	ramp_value = rvalue
	grid_x = x
	grid_y = y


func _on_click_body_input_event(
	_camera: Node,
	event: InputEvent,
	_position: Vector3,
	_normal: Vector3,
	_shape_idx: int
) -> void:
	if get_viewport().gui_get_hovered_control() != null:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			tile_clicked.emit(self)


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
	plane.size = Vector2(2.0, 2.0)
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
	selector.position = Vector3(0, 0.06, 0)
