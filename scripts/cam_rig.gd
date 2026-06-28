extends Node3D

@export var move_speed: float = 25.0
@export var fast_multiplier: float = 2.0
@export var zoom_speed: float = 4.0
@export var min_zoom: float = 12.0
@export var max_zoom: float = 55.0
@export var rotate_speed: float = 1.6

@export_group("Intro")
@export var intro_enabled: bool = true
@export var intro_duration: float = 3.5
@export var intro_zoom_multiplier: float = 1.7
@export var intro_yaw_offset_degrees: float = 22.0

@onready var pivot: Node3D = $CamPivot
@onready var cam: Camera3D = $CamPivot/Camera3D

var _zoom: float = 28.0
var _intro_playing: bool = false

func _ready() -> void:
	cam.current = true
	var field_focus : Dictionary = _get_field_focus_data()
	global_position = field_focus["center"]
	_zoom = clamp(float(field_focus["zoom"]), min_zoom, max_zoom)
	_zoom = clamp(_zoom, min_zoom, max_zoom)
	_apply_zoom()
	if intro_enabled:
		_start_intro(field_focus)

func focus_on_world(animate: bool = false, duration: float = 0.5) -> void:
	var field_focus : Dictionary = _get_field_focus_data()
	var center: Vector3 = field_focus["center"]
	var target_zoom: float = float(field_focus["zoom"])
	if animate:
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(self, "global_position", center, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "rotation_degrees:y", 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_method(_set_zoom, _zoom, target_zoom, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		return
	global_position = center
	rotation_degrees.y = 0.0
	_set_zoom(target_zoom)

func _unhandled_input(event: InputEvent) -> void:
	if _intro_playing:
		return
	if event.is_action_pressed("cam_zoom_in"):
		_zoom = clamp(_zoom - zoom_speed, min_zoom, max_zoom)
		_apply_zoom()
	elif event.is_action_pressed("cam_zoom_out"):
		_zoom = clamp(_zoom + zoom_speed, min_zoom, max_zoom)
		_apply_zoom()

func _process(delta: float) -> void:
	if _intro_playing:
		return

	var speed := move_speed
	if Input.is_action_pressed("cam_fast"):
		speed *= fast_multiplier
		
	var move := Vector3.ZERO
	
	if Input.is_action_pressed("cam_forward"):
		move.z -= 1.0
		
	if Input.is_action_pressed("cam_back"):
		move.z += 1.0
		
	if Input.is_action_pressed("cam_left"):
		move.x -= 1.0
		
	if Input.is_action_pressed("cam_right"):
		move.x += 1.0
		
	if move != Vector3.ZERO:
		move = move.normalized()
		var basis_flat := global_transform.basis
		basis_flat.y = Vector3.UP
		global_position += (basis_flat * move) * speed * delta
		
	if Input.is_action_pressed("cam_rotate_left"):
		rotate_y(rotate_speed * delta)
	if Input.is_action_pressed("cam_rotate_right"):
		rotate_y(-rotate_speed * delta)

func _apply_zoom() -> void:
	pivot.position = Vector3(0.0, _zoom, _zoom * 0.7)
	pivot.rotation_degrees.x = -55.0

func _set_zoom(value: float) -> void:
	_zoom = clamp(value, min_zoom, max_zoom)
	_apply_zoom()

func _get_field_focus_data() -> Dictionary:
	var world : Node3D = get_parent().get_node_or_null("World")
	if world == null:
		return {
			"center": Vector3.ZERO,
			"half_extent": 32.0,
			"zoom": _zoom
		}
	var tiles_value: Variant = world.get("field_tiles")
	var tile_size_value: Variant = world.get("tile_world_size")

	var tiles: Vector2i = Vector2i(64, 64)
	if tiles_value is Vector2i:
		tiles = tiles_value
	
	var tile_size: float = 2.0
	if tile_size_value is float:
		tile_size = tile_size_value
	elif tile_size_value is int:
		tile_size = float(tile_size_value)
		
	var field_size: Vector2 = Vector2(float(tiles.x), float(tiles.y)) * tile_size
	var half_extent: float = maxf(field_size.x, field_size.y) * 0.5
	var desired_zoom: float= clamp(max(18.0, half_extent * 1.05), min_zoom, max_zoom)
	
	return {
		"center": world.global_position,
		"half_extent": max(half_extent, 8.0),
		"zoom": desired_zoom
	}

func _start_intro(field_focus: Dictionary) -> void:
	_intro_playing = true
	
	var center: Vector3 = field_focus["center"]
	var half_extent: float = float(field_focus["half_extent"])
	var end_zoom: float = float(field_focus["zoom"])
	var start_zoom : float = clamp(end_zoom * intro_zoom_multiplier, min_zoom, max_zoom)
	
	global_position = center + Vector3(-half_extent * 0.45, 0.0, -half_extent * 0.45)
	rotation_degrees.y = intro_yaw_offset_degrees
	_set_zoom(start_zoom)
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "global_position", center, intro_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation_degrees:y", 0.0, intro_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_zoom, start_zoom, end_zoom, intro_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.finished.connect(_on_intro_finished)

func _on_intro_finished() -> void:
	_intro_playing = false
