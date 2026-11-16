class_name MapGenerator
extends Node3D

## Independent development tool for building maps.
##
## It is launched from the editor toolbar and runs in its own scene. The
## generated files are normal scenes, so the game can load them without the
## plugin being enabled.

enum Tool {
	TERRAIN,
	GROUND,
	OBJECTS,
}

const GROUND_LABELS: Array[String] = ["Wiese", "Sand", "Wasser"]
const MIN_SIZE: int = 1
const MAX_SIZE: int = 256

@export_group("Map")
## Initial field size in cells. One cell is [member start_cell_size] units.
@export var start_width: int = 32
@export var start_depth: int = 32
## The game's building grid also uses 2.0 units per cell.
@export var start_cell_size: float = 2.0
## Folder for the generated .tscn and .json files.
@export var save_directory: String = "res://GeneratedMaps"
@export var default_map_name: String = "Map002"

@export_group("Palette")
## Objects that can be placed. Configure this list in the scene.
@export var placeables: Array[MapPlaceable] = []

var _map_root: Node3D
var _terrain: MapTerrain
var _objects_root: Node3D
var _camera: MapCamera
var _brush_preview: MeshInstance3D

var _tool: int = Tool.TERRAIN
var _ground_type: int = MapTerrain.GroundType.MEADOW
var _selected_placeable: int = -1
var _rotation_steps: int = 0
var _name_counter: int = 0
var _last_terrain_height: float = 0.0

var _sculpting: bool = false
var _painting: bool = false

var _width_spin: SpinBox
var _depth_spin: SpinBox
var _radius_spin: SpinBox
var _intensity_spin: SpinBox
var _tool_option: OptionButton
var _ground_row: HBoxContainer
var _brush_row: HBoxContainer
var _object_box: VBoxContainer
var _ground_option: OptionButton
var _placeable_option: OptionButton
var _rotate_button: Button
var _name_edit: LineEdit
var _status_label: Label


func _ready() -> void:
	_create_world()
	_build_ui()
	_populate_placeables()
	_update_tool_visibility()
	_update_rotate_button()
	_set_status("Bereit. LMB anheben/setzen, RMB absenken/löschen.")


func _process(_delta: float) -> void:
	if _sculpting and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) \
			and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_sculpting = false
	if _painting and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_painting = false

	_update_brush_preview()


func _create_world() -> void:
	_map_root = Node3D.new()
	_map_root.name = "MapRoot"
	add_child(_map_root)

	_terrain = MapTerrain.new()
	_terrain.name = "Terrain"
	_terrain.cell_size = start_cell_size
	_terrain.width = start_width
	_terrain.depth = start_depth
	_map_root.add_child(_terrain)

	_objects_root = Node3D.new()
	_objects_root.name = "Objects"
	_map_root.add_child(_objects_root)

	_create_brush_preview()

	_camera = get_node_or_null("Camera") as MapCamera
	if _camera != null:
		_frame_camera()


func _create_brush_preview() -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.93
	torus.outer_radius = 1.0
	torus.rings = 48
	torus.ring_segments = 8

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 0.85, 0.2, 0.9)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = true

	_brush_preview = MeshInstance3D.new()
	_brush_preview.name = "BrushPreview"
	_brush_preview.mesh = torus
	_brush_preview.material_override = material
	_brush_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_brush_preview.visible = false
	add_child(_brush_preview)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "UI"
	add_child(layer)

	var panel := PanelContainer.new()
	panel.position = Vector2(16.0, 16.0)
	panel.custom_minimum_size = Vector2(340.0, 0.0)
	layer.add_child(panel)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.09, 0.1, 0.13, 0.96)
	panel_style.border_color = Color(0.3, 0.33, 0.38, 1.0)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", panel_style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	panel.add_child(box)

	var title := Label.new()
	title.text = "Map Generator"
	title.add_theme_font_size_override("font_size", 20)
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Eigenständiger Karten-Editor"
	subtitle.add_theme_color_override("font_color", Color(0.65, 0.7, 0.78))
	box.add_child(subtitle)
	box.add_child(HSeparator.new())

	var size_label := Label.new()
	size_label.text = "Feldgröße (Zellen)"
	box.add_child(size_label)

	var size_row := HBoxContainer.new()
	box.add_child(size_row)
	_width_spin = _make_spin(size_row, MIN_SIZE, MAX_SIZE, start_width)
	var times_label := Label.new()
	times_label.text = "×"
	size_row.add_child(times_label)
	_depth_spin = _make_spin(size_row, MIN_SIZE, MAX_SIZE, start_depth)

	var size_button := Button.new()
	size_button.text = "Größe anwenden (leert Karte)"
	size_button.pressed.connect(_on_apply_size)
	box.add_child(size_button)
	box.add_child(HSeparator.new())

	_tool_option = OptionButton.new()
	_tool_option.add_item("Gelände formen")
	_tool_option.add_item("Boden malen")
	_tool_option.add_item("Objekte platzieren")
	_tool_option.item_selected.connect(_on_tool_changed)
	box.add_child(_tool_option)

	_brush_row = HBoxContainer.new()
	box.add_child(_brush_row)
	var brush_label := Label.new()
	brush_label.text = "Pinsel"
	_brush_row.add_child(brush_label)
	_radius_spin = _make_spin(_brush_row, 1, 64, 2)
	_radius_spin.tooltip_text = "Radius in Zellen"
	var intensity_label := Label.new()
	intensity_label.text = "Stärke"
	_brush_row.add_child(intensity_label)
	_intensity_spin = _make_spin(_brush_row, 0.05, 8.0, 0.5)
	_intensity_spin.step = 0.05
	_intensity_spin.tooltip_text = "Höhenänderung pro Mausbewegung"

	_ground_row = HBoxContainer.new()
	box.add_child(_ground_row)
	var ground_label := Label.new()
	ground_label.text = "Boden"
	_ground_row.add_child(ground_label)
	_ground_option = OptionButton.new()
	for ground_name in GROUND_LABELS:
		_ground_option.add_item(ground_name)
	_ground_option.select(_ground_type)
	_ground_option.item_selected.connect(_on_ground_selected)
	_ground_row.add_child(_ground_option)

	_object_box = VBoxContainer.new()
	_object_box.add_theme_constant_override("separation", 7)
	box.add_child(_object_box)

	var object_label := Label.new()
	object_label.text = "Objekt"
	_object_box.add_child(object_label)

	_placeable_option = OptionButton.new()
	_placeable_option.item_selected.connect(_on_placeable_selected)
	_object_box.add_child(_placeable_option)

	_rotate_button = Button.new()
	_rotate_button.pressed.connect(_rotate_object)
	_object_box.add_child(_rotate_button)

	box.add_child(HSeparator.new())

	var save_label := Label.new()
	save_label.text = "Karte speichern"
	box.add_child(save_label)

	var save_row := HBoxContainer.new()
	box.add_child(save_row)
	_name_edit = LineEdit.new()
	_name_edit.text = default_map_name
	_name_edit.placeholder_text = "Kartenname"
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_row.add_child(_name_edit)

	var save_button := Button.new()
	save_button.text = "Speichern"
	save_button.pressed.connect(_on_save_pressed)
	save_row.add_child(save_button)

	var load_button := Button.new()
	load_button.text = "Laden"
	load_button.pressed.connect(_on_load_pressed)
	save_row.add_child(load_button)

	var reset_button := Button.new()
	reset_button.text = "Neu (alles leeren)"
	reset_button.pressed.connect(_on_reset_pressed)
	box.add_child(reset_button)

	_status_label = Label.new()
	_status_label.custom_minimum_size = Vector2(0.0, 42.0)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status_label)

	var help := Label.new()
	help.text = "LMB: anheben / malen / setzen\nRMB: absenken / löschen\nR: Objekt drehen\nMMB: Kamera drehen · Rad: Zoom\nWASD: bewegen · Q/E: drehen"
	help.add_theme_font_size_override("font_size", 11)
	help.add_theme_color_override("font_color", Color(0.62, 0.67, 0.75))
	box.add_child(help)


func _make_spin(parent: Node, minimum: float, maximum: float, value: float) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = 1.0
	spin.value = value
	spin.custom_minimum_size = Vector2(74.0, 0.0)
	parent.add_child(spin)
	return spin


func _populate_placeables() -> void:
	_placeable_option.clear()
	for index in range(placeables.size()):
		var placeable: MapPlaceable = placeables[index]
		if placeable == null or placeable.scene == null:
			continue

		var item_index: int = _placeable_option.item_count
		_placeable_option.add_item("%s · %s" % [placeable.category, placeable.label])
		_placeable_option.set_item_metadata(item_index, index)

	if _placeable_option.item_count > 0:
		_placeable_option.select(0)
		_on_placeable_selected(0)
	else:
		_selected_placeable = -1


func _update_tool_visibility() -> void:
	var is_terrain: bool = _tool == Tool.TERRAIN
	var is_ground: bool = _tool == Tool.GROUND
	var is_objects: bool = _tool == Tool.OBJECTS

	_brush_row.visible = is_terrain or is_ground
	_ground_row.visible = is_ground
	_object_box.visible = is_objects


func _update_rotate_button() -> void:
	if _rotate_button == null:
		return
	_rotate_button.text = "Drehen (R): %d°" % (_rotation_steps * 90)


func _frame_camera() -> void:
	if _camera == null:
		return
	var map_size := _map_size_vector()
	_camera.frame_map(map_size)
	_camera.set_bounds(map_size)


func _map_size_vector() -> Vector3:
	return Vector3(
		float(_terrain.width) * _terrain.cell_size,
		0.0,
		float(_terrain.depth) * _terrain.cell_size
	)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_R:
			_rotate_object()
			get_viewport().set_input_as_handled()
		return

	if not (event is InputEventMouseButton):
		if event is InputEventMouseMotion and (_sculpting or _painting):
			if not _pointer_over_ui():
				_apply_edit_at_mouse(false)
		return

	var mouse_button := event as InputEventMouseButton
	if mouse_button.button_index == MOUSE_BUTTON_LEFT:
		if mouse_button.pressed:
			if _pointer_over_ui():
				return
			_start_primary()
		else:
			_sculpting = false
			_painting = false
	elif mouse_button.button_index == MOUSE_BUTTON_RIGHT:
		if mouse_button.pressed:
			if _pointer_over_ui():
				return
			_start_secondary()
		else:
			_sculpting = false


func _start_primary() -> void:
	match _tool:
		Tool.TERRAIN:
			_sculpting = true
			_apply_edit_at_mouse(false)
		Tool.GROUND:
			_painting = true
			_apply_edit_at_mouse(false)
		Tool.OBJECTS:
			_place_at_mouse()


func _start_secondary() -> void:
	match _tool:
		Tool.TERRAIN:
			_sculpting = true
			_apply_edit_at_mouse(true)
		Tool.OBJECTS:
			_delete_at_mouse()


func _apply_edit_at_mouse(lower: bool) -> void:
	var hit := _raycast_terrain()
	if hit.is_empty():
		return

	var point := _hit_position(hit)
	_last_terrain_height = point.y
	var radius: float = float(_radius_spin.value)
	var intensity: float = float(_intensity_spin.value)

	if _tool == Tool.TERRAIN:
		_terrain.sculpt(point, radius, -intensity if lower else intensity)
	elif _tool == Tool.GROUND:
		_terrain.paint(point, radius, _ground_type)


func _place_at_mouse() -> void:
	var hit := _raycast_terrain()
	if hit.is_empty():
		return

	var point := _hit_position(hit)
	var cell := _terrain.world_to_cell(point)
	if not _terrain.is_cell_inside(cell):
		_set_status("Außerhalb der Karte.", true)
		return

	var placeable := _current_placeable()
	if placeable == null:
		_set_status("Kein Objekt ausgewählt.", true)
		return

	var instance := place_object(_selected_placeable, cell, _rotation_steps)
	if instance != null:
		_set_status("%s platziert." % placeable.label)


func _delete_at_mouse() -> void:
	var hit := _raycast(1)
	if hit.is_empty():
		return

	var collider_value: Variant = hit.get("collider", null)
	var collider := collider_value as Node
	if collider == null or not _objects_root.is_ancestor_of(collider):
		return

	var placed := _find_placed_root(collider)
	if placed == null:
		return

	var label: String = str(placed.get_meta("map_label", "Objekt"))
	var parent := placed.get_parent()
	if parent != null:
		parent.remove_child(placed)
	placed.queue_free()
	_set_status("%s gelöscht." % label)


func _raycast(mask: int) -> Dictionary:
	if _camera == null:
		return {}
	var mouse_position := get_viewport().get_mouse_position()
	var origin := _camera.project_ray_origin(mouse_position)
	var direction := _camera.project_ray_normal(mouse_position)
	var query := PhysicsRayQueryParameters3D.create(
		origin,
		origin + direction * 10000.0,
		mask
	)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return get_world_3d().direct_space_state.intersect_ray(query)


func _raycast_terrain() -> Dictionary:
	var hit := _raycast(2)
	if not hit.is_empty():
		return hit

	# Fallback plane, so editing still works while a height change has not
	# rebuilt the collision shape yet.
	if _camera == null:
		return {}
	var mouse_position := get_viewport().get_mouse_position()
	var origin := _camera.project_ray_origin(mouse_position)
	var direction := _camera.project_ray_normal(mouse_position)
	if absf(direction.y) < 0.0001:
		return {}

	var distance: float = (_last_terrain_height - origin.y) / direction.y
	if distance <= 0.0:
		return {}
	return {"position": origin + direction * distance}


func _hit_position(hit: Dictionary) -> Vector3:
	if hit.is_empty():
		return Vector3.ZERO
	var value: Variant = hit["position"]
	if value is Vector3:
		return value
	return Vector3.ZERO


func _update_brush_preview() -> void:
	if _brush_preview == null:
		return

	if _tool == Tool.OBJECTS or _pointer_over_ui():
		_brush_preview.visible = false
		return

	var hit := _raycast_terrain()
	if hit.is_empty():
		_brush_preview.visible = false
		return

	var point := _hit_position(hit)
	_last_terrain_height = point.y
	var radius: float = float(_radius_spin.value) * _terrain.cell_size
	_brush_preview.visible = true
	_brush_preview.scale = Vector3(radius, 1.0, radius)
	_brush_preview.global_position = point + Vector3.UP * 0.12


func _pointer_over_ui() -> bool:
	return get_viewport().gui_get_hovered_control() != null


func _current_placeable() -> MapPlaceable:
	if _selected_placeable < 0 or _selected_placeable >= placeables.size():
		return null
	var placeable: MapPlaceable = placeables[_selected_placeable]
	if placeable == null or placeable.scene == null:
		return null
	return placeable


## Places an object on a cell. Used by the mouse input and by tests.
func place_object(placeable_index: int, cell: Vector2i, rotation_steps: int) -> Node3D:
	if placeable_index < 0 or placeable_index >= placeables.size():
		return null

	var placeable: MapPlaceable = placeables[placeable_index]
	if placeable == null or placeable.scene == null:
		return null
	if not _terrain.is_cell_inside(cell):
		return null

	var instance := placeable.scene.instantiate() as Node3D
	if instance == null:
		return null

	var folder := _folder_for(placeable.category)
	instance.name = _next_object_name(placeable.label)
	instance.rotation.y = deg_to_rad(float(_normalized_steps(rotation_steps)) * 90.0)
	instance.set_meta("map_label", placeable.label)
	instance.set_meta("map_category", placeable.category)
	instance.set_meta("map_scene_path", placeable.scene.resource_path)
	instance.set_meta("map_rotation_steps", _normalized_steps(rotation_steps))
	folder.add_child(instance)

	var center := _terrain.get_cell_center_world(cell)
	var offset := _ground_offset_for(instance, placeable)
	instance.position = Vector3(center.x, center.y + offset, center.z)
	return instance


func _ground_offset_for(instance: Node3D, placeable: MapPlaceable) -> float:
	if not placeable.auto_ground_offset:
		return placeable.vertical_offset

	var combined := AABB()
	var has_box: bool = false
	var instance_inverse := instance.global_transform.affine_inverse()

	for node in instance.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		if not mesh_instance.is_visible_in_tree():
			continue

		var relative: Transform3D = instance_inverse * mesh_instance.global_transform
		var mesh_box: AABB = relative * mesh_instance.get_aabb()
		if has_box:
			combined = combined.merge(mesh_box)
		else:
			combined = mesh_box
			has_box = true

	if not has_box:
		return 0.0
	return -combined.position.y


func _folder_for(category: String) -> Node3D:
	var folder_name: String = category.strip_edges()
	if folder_name.is_empty():
		folder_name = "Objekte"
	folder_name = folder_name.validate_node_name()

	var existing := _objects_root.get_node_or_null(NodePath(folder_name))
	if existing is Node3D:
		return existing as Node3D

	var folder := Node3D.new()
	folder.name = folder_name
	_objects_root.add_child(folder)
	return folder


func _next_object_name(label: String) -> String:
	var base: String = label.strip_edges().validate_node_name()
	if base.is_empty():
		base = "Objekt"
	_name_counter += 1
	return "%s_%d" % [base, _name_counter]


func _find_placed_root(node: Node) -> Node3D:
	var current: Node = node
	while current != null and current != _objects_root:
		var parent := current.get_parent()
		if parent == null:
			return null
		if parent.get_parent() == _objects_root:
			return current as Node3D
		current = parent
	return null


func _iter_placed_objects() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for category in _objects_root.get_children():
		if not (category is Node3D):
			continue
		for entry in category.get_children():
			if entry is Node3D:
				result.append(entry as Node3D)
	return result


func _clear_objects() -> void:
	for category in _objects_root.get_children():
		_objects_root.remove_child(category)
		category.queue_free()
	_name_counter = 0


func _normalized_steps(steps: int) -> int:
	return ((steps % 4) + 4) % 4


func _rotate_object() -> void:
	_rotation_steps = _normalized_steps(_rotation_steps + 1)
	_update_rotate_button()


func _on_apply_size() -> void:
	var new_width: int = int(_width_spin.value)
	var new_depth: int = int(_depth_spin.value)
	_terrain.set_map_size(new_width, new_depth)
	_clear_objects()
	_frame_camera()
	_set_status("Karte auf %d × %d Zellen zurückgesetzt." % [new_width, new_depth])


func _on_reset_pressed() -> void:
	_terrain.reset()
	_clear_objects()
	_frame_camera()
	_set_status("Karte geleert.")


func _on_tool_changed(index: int) -> void:
	_tool = index
	_update_tool_visibility()
	_update_brush_preview()


func _on_ground_selected(index: int) -> void:
	_ground_type = index


func _on_placeable_selected(index: int) -> void:
	var metadata: Variant = _placeable_option.get_item_metadata(index)
	if metadata == null:
		return
	_selected_placeable = int(metadata)


func _on_save_pressed() -> void:
	save_map(_name_edit.text)


func _on_load_pressed() -> void:
	load_map(_name_edit.text)


## Saves a normal .tscn for the game plus a .json for editing the map again.
func save_map(map_name: String) -> bool:
	_terrain.flush()
	var safe_name := _safe_map_name(map_name)
	var directory := save_directory.trim_suffix("/")

	var make_error := DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(directory)
	)
	if make_error != OK and make_error != ERR_ALREADY_EXISTS:
		_set_status("Ordner konnte nicht erstellt werden: %s" % error_string(make_error), true)
		return false

	var export_root := Node3D.new()
	export_root.name = safe_name
	export_root.set_meta("map_name", safe_name)
	export_root.set_meta("map_width", _terrain.width)
	export_root.set_meta("map_depth", _terrain.depth)
	export_root.set_meta("map_cell_size", _terrain.cell_size)

	var export_terrain := _terrain.build_export_terrain()
	export_root.add_child(export_terrain)
	_assign_owner_recursive(export_terrain, export_root)

	var export_objects := Node3D.new()
	export_objects.name = "Objects"
	export_root.add_child(export_objects)
	export_objects.owner = export_root

	for category in _objects_root.get_children():
		if not (category is Node3D):
			continue

		var category_node := Node3D.new()
		category_node.name = category.name
		export_objects.add_child(category_node)
		category_node.owner = export_root

		for entry in category.get_children():
			if not (entry is Node3D):
				continue
			var exported := _create_export_object(entry as Node3D)
			if exported == null:
				continue
			category_node.add_child(exported)
			exported.owner = export_root

	var scene_path: String = "%s/%s.tscn" % [directory, safe_name]
	var packed_scene := PackedScene.new()
	var pack_error := packed_scene.pack(export_root)
	if pack_error != OK:
		export_root.free()
		_set_status("Szene konnte nicht gepackt werden: %s" % error_string(pack_error), true)
		return false

	var save_error := ResourceSaver.save(packed_scene, scene_path)
	export_root.free()
	if save_error != OK:
		_set_status("Szene konnte nicht gespeichert werden: %s" % error_string(save_error), true)
		return false

	var data := _terrain.serialize_data()
	data["name"] = safe_name
	data["objects"] = _serialize_objects()

	var json_path: String = "%s/%s.json" % [directory, safe_name]
	var file := FileAccess.open(json_path, FileAccess.WRITE)
	if file == null:
		_set_status("JSON konnte nicht geschrieben werden: %s" % json_path, true)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

	_set_status("Gespeichert: %s (+ .json)" % scene_path)
	return true


## Loads a previously saved JSON and rebuilds terrain and objects.
func load_map(map_name: String) -> bool:
	var safe_name := _safe_map_name(map_name)
	var json_path: String = "%s/%s.json" % [save_directory.trim_suffix("/"), safe_name]
	var file := FileAccess.open(json_path, FileAccess.READ)
	if file == null:
		_set_status("Nicht gefunden: %s" % json_path, true)
		return false

	var content := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(content)
	if not (parsed is Dictionary):
		_set_status("Ungültige JSON-Datei: %s" % json_path, true)
		return false

	var data: Dictionary = parsed
	_terrain.load_data(data)
	_clear_objects()

	var objects_value: Variant = data.get("objects", [])
	if objects_value is Array:
		var objects: Array = objects_value
		for item_value in objects:
			if not (item_value is Dictionary):
				continue
			_load_json_object(item_value)

	_width_spin.value = _terrain.width
	_depth_spin.value = _terrain.depth
	_name_edit.text = safe_name
	_frame_camera()
	_set_status("Geladen: %s" % json_path)
	return true


func _load_json_object(item: Dictionary) -> void:
	var scene_path: String = str(item.get("scene", ""))
	if scene_path.is_empty():
		return

	var packed := load(scene_path) as PackedScene
	if packed == null:
		return

	var instance := packed.instantiate() as Node3D
	if instance == null:
		return

	var category: String = str(item.get("category", "Objekte"))
	var label: String = str(item.get("label", "Objekt"))
	var rotation_steps: int = _normalized_steps(int(item.get("rotation_steps", 0)))

	var saved_position := Vector3.ZERO
	var position_value: Variant = item.get("position", [])
	if position_value is Array:
		var coordinates: Array = position_value
		if coordinates.size() >= 3:
			saved_position = Vector3(
				float(coordinates[0]),
				float(coordinates[1]),
				float(coordinates[2])
			)

	var folder := _folder_for(category)
	instance.name = _next_object_name(label)
	instance.position = saved_position
	instance.rotation.y = deg_to_rad(float(rotation_steps) * 90.0)
	instance.set_meta("map_label", label)
	instance.set_meta("map_category", category)
	instance.set_meta("map_scene_path", scene_path)
	instance.set_meta("map_rotation_steps", rotation_steps)
	folder.add_child(instance)


func _create_export_object(entry: Node3D) -> Node3D:
	var scene_path: String = str(entry.get_meta("map_scene_path", ""))
	if scene_path.is_empty():
		return null

	var packed := load(scene_path) as PackedScene
	if packed == null:
		return null

	var instance := packed.instantiate() as Node3D
	if instance == null:
		return null

	instance.name = entry.name
	instance.transform = entry.transform
	for key in entry.get_meta_list():
		var meta_key: String = str(key)
		if meta_key.begins_with("map_"):
			instance.set_meta(meta_key, entry.get_meta(key))
	return instance


func _serialize_objects() -> Array:
	var objects: Array = []
	for entry in _iter_placed_objects():
		var position_value := entry.position
		objects.append({
			"label": str(entry.get_meta("map_label", entry.name)),
			"category": str(entry.get_meta("map_category", "Objekte")),
			"scene": str(entry.get_meta("map_scene_path", "")),
			"position": [position_value.x, position_value.y, position_value.z],
			"rotation_steps": int(entry.get_meta("map_rotation_steps", 0)),
		})
	return objects


func _assign_owner_recursive(node: Node, owner_root: Node) -> void:
	node.owner = owner_root
	for child in node.get_children():
		_assign_owner_recursive(child, owner_root)


func _safe_map_name(map_name: String) -> String:
	var safe_name: String = map_name.strip_edges().get_file().validate_filename()
	if safe_name.is_empty():
		safe_name = default_map_name.validate_filename()
	if safe_name.is_empty():
		safe_name = "Map"
	return safe_name


func _set_status(text: String, is_error: bool = false) -> void:
	if _status_label == null:
		return
	_status_label.text = text
	_status_label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.45, 0.42) if is_error else Color(0.72, 0.88, 0.72)
	)


## Access for tests and for a possible game-side loader.
func get_terrain() -> MapTerrain:
	return _terrain


func get_objects_root() -> Node3D:
	return _objects_root
