extends Node3D
class_name Unit

@export var body_socket_path: NodePath
@export var weapon_socket_path: NodePath

@export var unit_path: NodePath
@export var target_path: NodePath
@export var move_path: NodePath

@export_group("Movement")
@export var move_speed: float = 3.0
@export var rotation_lerp_speed: float = 10.0

var target_arrow: MeshInstance3D
var move_arrow: MeshInstance3D

var body_instance: Node3D
var weapon_instance: Node3D
var target_instance: Node3D

var _is_moving: bool = false
var _move_direction: Vector3 = Vector3.FORWARD

func _ready() -> void:
	target_arrow = get_node_or_null(target_path) as MeshInstance3D
	move_arrow = get_node_or_null(move_path) as MeshInstance3D

func setup(body_scene: PackedScene, weapon_scene: PackedScene, target_node: Node3D = null) -> void:
	var body_socket := get_node_or_null(body_socket_path) as Node3D
	var weapon_socket := get_node_or_null(weapon_socket_path) as Node3D

	target_instance = target_node

	if body_socket == null:
		push_error("Unit: body socket not found")
		return

	if weapon_socket == null:
		push_error("Unit: weapon socket not found")
		return

	body_instance = body_scene.instantiate() as Node3D
	weapon_instance = weapon_scene.instantiate() as Node3D

	if body_instance == null:
		push_error("Unit: body scene invalid")
		return

	if weapon_instance == null:
		push_error("Unit: weapon scene invalid")
		return

	body_socket.add_child(body_instance)
	weapon_socket.add_child(weapon_instance)

	if body_instance.has_method("set_weapon"):
		body_instance.set_weapon(weapon_instance)

func set_target(target_node: Node3D) -> void:
	target_instance = target_node

func _process(delta: float) -> void:
	_handle_movement(delta)
	_update_direction_visuals(delta)
	_update_animation(delta)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("attack"):
		attack()

func _handle_movement(delta: float) -> void:
	var input := Vector3.ZERO

	if Input.is_action_pressed("left"):
		input.x -= 1.0
	if Input.is_action_pressed("right"):
		input.x += 1.0
	if Input.is_action_pressed("up"):
		input.z -= 1.0
	if Input.is_action_pressed("down"):
		input.z += 1.0

	_is_moving = input != Vector3.ZERO

	if _is_moving:
		input = input.normalized()
		_move_direction = input
		global_position += input * move_speed * delta

func _update_direction_visuals(delta: float) -> void:
	var has_target := target_instance != null and is_instance_valid(target_instance)

	var target_dir := Vector3.ZERO
	if has_target:
		target_dir = target_instance.global_position - global_position
		target_dir.y = 0.0
		if target_dir.length_squared() > 0.0001:
			target_dir = target_dir.normalized()
		else:
			target_dir = Vector3.ZERO

	# move arrow zeigt letzte/laufende Bewegungsrichtung
	if move_arrow != null:
		move_arrow.visible = _is_moving
		if _is_moving:
			var move_angle := atan2(_move_direction.x, _move_direction.z)
			move_arrow.rotation.y = lerp_angle(
				move_arrow.rotation.y,
				move_angle,
				rotation_lerp_speed * delta
			)

	# target arrow zeigt immer auf target
	if target_arrow != null:
		target_arrow.visible = has_target
		if has_target and target_dir != Vector3.ZERO:
			var target_angle := atan2(target_dir.x, target_dir.z) + PI
			target_arrow.rotation.y = lerp_angle(
				target_arrow.rotation.y,
				target_angle,
				rotation_lerp_speed * delta
			)
			body_instance.rotation.y = lerp_angle(
				body_instance.rotation.y,
				target_angle,
				rotation_lerp_speed * delta
			)
			weapon_instance.rotation.y = lerp_angle(
				weapon_instance.rotation.y,
				target_angle,
				rotation_lerp_speed * delta
			)

func _update_animation(delta: float) -> void:
	if body_instance != null and body_instance.has_method("set_moving"):
		body_instance.set_moving(_is_moving)

	if body_instance != null and body_instance.has_method("update_animation"):
		body_instance.update_animation(delta)

	if weapon_instance != null and weapon_instance.has_method("set_moving"):
		weapon_instance.set_moving(_is_moving)

	if weapon_instance != null and weapon_instance.has_method("update_animation"):
		weapon_instance.update_animation(delta)

func attack() -> void:
	if body_instance != null and body_instance.has_method("play_attack"):
		body_instance.play_attack()

	if weapon_instance != null and weapon_instance.has_method("play_attack"):
		weapon_instance.play_attack()
