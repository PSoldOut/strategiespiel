extends Node3D
class_name Unit

@export var body_socket_path: NodePath
@export var weapon_socket_path: NodePath

@export_group("Movement")
@export var move_speed: float = 3.0

var body_instance: Node3D
var weapon_instance: Node3D

func setup(body_scene: PackedScene, weapon_scene: PackedScene) -> void:
	var body_socket := get_node_or_null(body_socket_path) as Node3D
	var weapon_socket := get_node_or_null(weapon_socket_path) as Node3D
	
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

func _process(delta: float) -> void:
	_handle_movement(delta)
	_update_idle(delta)

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
	
	if input != Vector3.ZERO:
		input = input.normalized()
		global_position += input * move_speed * delta
		
		if body_instance != null and body_instance.has_method("play_move"):
			body_instance.play_move(delta)
	else:
		if body_instance != null and body_instance.has_method("play_idle"):
			body_instance.play_idle(delta)

func _update_idle(delta: float) -> void:
	if body_instance != null and body_instance.has_method("update_animation"):
		body_instance.update_animation(delta)
	
	if weapon_instance != null and weapon_instance.has_method("update_animation"):
		weapon_instance.update_animation(delta)

func attack() -> void:
	if body_instance != null and body_instance.has_method("play_attack"):
		body_instance.play_attack()
	
	if weapon_instance != null and weapon_instance.has_method("play_attack"):
		weapon_instance.play_attack()
