extends Control
class_name RTSUserInterface

## Generic RTS user interface shell.
##
## The interface does not know any game content. It only displays entries that
## are passed in via [method set_build_options], [method set_abilities] and
## [method set_units], and reports user input as generic ids.

signal build_option_pressed(id: StringName)
signal ability_pressed(id: StringName)
signal mouse_entered_panel
signal mouse_exited_panel

@export_group("Camera")
## Camera whose visible ground area is drawn on the minimap.
## When empty the active camera of this viewport is used.
@export var view_camera: Camera3D

@export_group("Minimap")
@export var minimap_enabled := true
## World position (x, z) the minimap is centered on.
@export var minimap_center := Vector2(256.0, 256.0)
## Height of the orthographic minimap camera above the ground.
@export var minimap_height := 350.0
## Half of the visible world area of the minimap.
@export var minimap_ortho_size := 512.0
## Render layers the minimap camera sees. Objects have to be on one of them.
@export var minimap_cull_mask := 1 << 19
## World height of the ground plane used by the camera footprint marker.
@export var ground_y := 0.0

var _resolved_camera: Camera3D

@onready var _panel: Panel = $Panel
@onready var _build_container: MarginContainer = $Panel/BuildContainer
@onready var _build_list: VBoxContainer = $Panel/BuildContainer/VBoxContainer
@onready var _abilities_container: MarginContainer = $Panel/AbilitiesContainer
@onready var _abilities_list: VBoxContainer = $Panel/AbilitiesContainer/VBoxContainer
@onready var _minimap_container: MarginContainer = $Panel/MinimapContainer
@onready var _minimap: TextureRect = $Panel/MinimapContainer/VBoxContainer/Minimap
@onready var _units_container: MarginContainer = $Panel/UnitsContainer
@onready var _units_list: VBoxContainer = $Panel/UnitsContainer/VBoxContainer/List
@onready var _camera_marker: MinimapCameraMarker = $Panel/MinimapContainer/VBoxContainer/Minimap/CameraMarker
@onready var _minimap_viewport: SubViewport = $MinimapViewport
@onready var _minimap_camera: Camera3D = $MinimapViewport/MinimapCamera


func _ready() -> void:
	_build_container.visible = false
	_abilities_container.visible = false
	_units_container.visible = false

	_configure_minimap()
	_resolve_view_camera()

	_minimap.texture = _minimap_viewport.get_texture()
	_minimap.resized.connect(_sync_minimap_size)
	_sync_minimap_size()


func _process(_delta: float) -> void:
	if not is_instance_valid(view_camera) and not is_instance_valid(_resolved_camera):
		_resolve_view_camera()


## Replaces the build options shown to the player.
## Accepts an untyped array of [UIEntry] resources.
func set_build_options(options: Array) -> void:
	_fill(_build_list, options, _on_build_button_pressed)
	_build_container.visible = not options.is_empty()


func clear_build_options() -> void:
	_clear_list(_build_list)
	_build_container.visible = false


## Replaces the ability entries shown to the player.
## Accepts an untyped array of [UIEntry] resources.
func set_abilities(abilities: Array) -> void:
	_fill(_abilities_list, abilities, _on_ability_button_pressed)
	_abilities_container.visible = not abilities.is_empty()


func clear_abilities() -> void:
	_clear_list(_abilities_list)
	_abilities_container.visible = false


## Replaces the selection info lines, e.g. ["5x Pionir"].
func set_units(lines: Array) -> void:
	_clear_list(_units_list)
	for line in lines:
		var label := Label.new()
		label.text = str(line)
		_units_list.add_child(label)
	_units_container.visible = not lines.is_empty()


func clear_units() -> void:
	_clear_list(_units_list)
	_units_container.visible = false


func _fill(list: VBoxContainer, entries: Array, handler: Callable) -> void:
	_clear_list(list)

	for entry in entries:
		if not (entry is UIEntry):
			continue
		var button := Button.new()
		button.text = entry.label if not entry.label.is_empty() else String(entry.id)
		button.disabled = entry.disabled
		button.tooltip_text = entry.tooltip
		if entry.icon != null:
			button.icon = entry.icon
		button.pressed.connect(handler.bind(entry.id))
		list.add_child(button)


func _clear_list(list: VBoxContainer) -> void:
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()


func _on_build_button_pressed(id: StringName) -> void:
	build_option_pressed.emit(id)


func _on_ability_button_pressed(id: StringName) -> void:
	ability_pressed.emit(id)


func _configure_minimap() -> void:
	_minimap_container.visible = minimap_enabled
	if not minimap_enabled:
		return

	_minimap_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_minimap_camera.size = minimap_ortho_size
	_minimap_camera.cull_mask = minimap_cull_mask
	_minimap_camera.position = Vector3(minimap_center.x, minimap_height, minimap_center.y)
	_minimap_camera.current = true

	_camera_marker.minimap_camera = _minimap_camera
	_camera_marker.minimap_viewport = _minimap_viewport
	_camera_marker.ground_y = ground_y


func _resolve_view_camera() -> void:
	var active := view_camera
	if not is_instance_valid(active):
		active = get_viewport().get_camera_3d()
	if is_instance_valid(active):
		_resolved_camera = active
		_camera_marker.view_camera = active


func _sync_minimap_size() -> void:
	if _minimap.size.x < 1.0 or _minimap.size.y < 1.0:
		return
	var target := Vector2i(int(_minimap.size.x), int(_minimap.size.y))
	if _minimap_viewport.size != target:
		_minimap_viewport.size = target


func _on_panel_mouse_entered() -> void:
	mouse_entered_panel.emit()


func _on_panel_mouse_exited() -> void:
	if not Rect2(_panel.position, _panel.size).has_point(get_local_mouse_position()):
		mouse_exited_panel.emit()
