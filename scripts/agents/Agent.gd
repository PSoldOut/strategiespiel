extends CharacterBody3D

@onready var navigation_agent_3d: NavigationAgent3D = $NavigationAgent3D
@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var detection_area: Area3D = $Area3D
@onready var selection_unit: Node = $DragSelectionUnit

enum State {
	IDLE,
	MOVE,
	MOVE_STRAIGHT,
	CHASE,
	ATTACK
}

const PLAYER_SYNC_RATE: float = 0.05

var state: int = State.IDLE
var selected: bool = false
var team: String = "blue"

var target: Node3D = null

var hp: int = 100
var damage: int = 10

var attack_range: float = 2.0
var attack_cooldown: float = 1.0
var attack_timer: float = 0.0

var speed: float = 5.0

var is_player_controlled: bool = false
var owner_peer_id: int = 1
var player_slot: int = 0

var _player_color: Color = Color(0.2, 0.5, 1.0, 1.0)
var _player_name: String = "Player"
var _network_sync_timer: float = 0.0
var _remote_position: Vector3 = Vector3.ZERO
var _remote_velocity: Vector3 = Vector3.ZERO
var _remote_yaw: float = 0.0
var _name_label: Label3D


func configure_player(peer_id: int, slot: int, color: Color) -> void:
	is_player_controlled = true
	owner_peer_id = peer_id
	player_slot = slot
	_player_color = color
	_player_name = "P%d" % (slot + 1)
	team = "player_%d" % peer_id
	speed = 9.0
	target = null
	state = State.IDLE
	if is_inside_tree():
		set_multiplayer_authority(owner_peer_id)
		if selection_unit and selection_unit.has_method("set_team"):
			selection_unit.set_team(team)
		_update_team_color()
		_setup_name_label()


func _ready() -> void:
	if is_player_controlled:
		set_multiplayer_authority(owner_peer_id)
		if selection_unit and selection_unit.has_method("set_team"):
			selection_unit.set_team(team)
		_update_team_color()
		_setup_name_label()
		_remote_position = global_position
		_remote_yaw = rotation.y
	else:
		randomize()
		team = "blue" if randi() % 2 == 0 else "red"
		if selection_unit and selection_unit.has_method("set_team"):
			selection_unit.set_team(team)
		_update_team_color()


func _physics_process(delta: float) -> void:
	if _is_game_paused():
		velocity = Vector3.ZERO
		return

	if is_player_controlled:
		_physics_process_player(delta)
		return

	if attack_timer > 0.0:
		attack_timer -= delta

	match state:
		State.IDLE:
			velocity = Vector3.ZERO
		State.MOVE, State.MOVE_STRAIGHT:
			handle_move()
		State.CHASE:
			handle_chase()
		State.ATTACK:
			handle_attack()

	move_and_slide()


func _physics_process_player(delta: float) -> void:
	if is_multiplayer_authority():
		if attack_timer > 0.0:
			attack_timer -= delta

		match state:
			State.IDLE:
				velocity = Vector3.ZERO
			State.MOVE, State.MOVE_STRAIGHT:
				handle_move()
			State.CHASE:
				handle_chase()
			State.ATTACK:
				handle_attack()

		move_and_slide()
		if velocity.length_squared() > 0.001:
			look_at(global_position + Vector3(velocity.x, 0.0, velocity.z), Vector3.UP)
		_network_sync_timer += delta
		if multiplayer.has_multiplayer_peer() and _network_sync_timer >= PLAYER_SYNC_RATE:
			_network_sync_timer = 0.0
			_register_packet_sent()
			rpc("_rpc_sync_player_state", global_position, velocity, rotation.y)
	else:
		global_position = global_position.lerp(_remote_position, clamp(delta * 12.0, 0.0, 1.0))
		rotation.y = lerp_angle(rotation.y, _remote_yaw, clamp(delta * 12.0, 0.0, 1.0))
		velocity = _remote_velocity


func issue_move_order(destination: Vector3) -> void:
	if not is_player_controlled:
		return
	target = null
	navigation_agent_3d.set_target_position(destination)
	state = State.MOVE_STRAIGHT


func issue_attack_order(target_unit: Node3D) -> void:
	if not is_player_controlled:
		return
	target = target_unit
	state = State.CHASE


@rpc("any_peer", "unreliable")
func _rpc_sync_player_state(position_value: Vector3, velocity_value: Vector3, yaw_value: float) -> void:
	if not is_player_controlled:
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender != owner_peer_id:
		return
	_register_packet_received()
	_remote_position = position_value
	_remote_velocity = velocity_value
	_remote_yaw = yaw_value


func scan_for_enemys() -> void:
	if is_player_controlled:
		return
	if target != null or state == State.MOVE_STRAIGHT or state == State.ATTACK:
		return
	for body in detection_area.get_overlapping_bodies():
		if body == self:
			continue
		if not body.has_method("take_damage"):
			continue
		if body.team == team:
			continue
		target = body
		state = State.CHASE
		break


func handle_move() -> void:
	if navigation_agent_3d.is_navigation_finished():
		state = State.IDLE
		target = null
		return
	move_to_target()


func handle_chase() -> void:
	if not is_instance_valid(target):
		target = null
		state = State.IDLE
		return
	navigation_agent_3d.set_target_position(target.global_position)
	var distance := global_position.distance_to(target.global_position)
	if distance <= attack_range:
		state = State.ATTACK
		return
	move_to_target()


func handle_attack() -> void:
	if not is_instance_valid(target):
		target = null
		state = State.IDLE
		return
	var distance := global_position.distance_to(target.global_position)
	if distance > attack_range:
		state = State.CHASE
		return
	look_at(target.global_position)
	velocity = Vector3.ZERO
	if attack_timer > 0.0:
		return
	target.take_damage(damage)
	$AnimationPlayer.play("attack")
	attack_timer = attack_cooldown


func move_to_target() -> void:
	var destination := navigation_agent_3d.get_next_path_position()
	var direction := (destination - global_position).normalized()
	velocity = direction * speed


func take_damage(amount: int) -> void:
	hp -= amount
	if hp <= 0:
		die()


func die() -> void:
	if selection_unit and selection_unit.has_method("unregister"):
		selection_unit.unregister()
	queue_free()


func _update_team_color() -> void:
	var material: Material = mesh.get_active_material(0)
	if material == null:
		return
	var duplicated_material := material.duplicate()
	if duplicated_material is StandardMaterial3D:
		if is_player_controlled:
			duplicated_material.albedo_color = _player_color
		elif team == "blue":
			duplicated_material.albedo_color = Color(0.0, 0.323, 0.899, 1.0)
		else:
			duplicated_material.albedo_color = Color(0.899, 0.1, 0.1, 1.0)
	mesh.set_surface_override_material(0, duplicated_material)


func _setup_name_label() -> void:
	if _name_label == null:
		_name_label = Label3D.new()
		_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_name_label.no_depth_test = true
		_name_label.font_size = 22
		_name_label.position = Vector3(0.0, 2.3, 0.0)
		add_child(_name_label)
	_name_label.text = _player_name
	_name_label.modulate = _player_color


func select() -> void:
	selected = true
	mesh.scale = Vector3(1.2, 1.2, 1.2)


func deselect() -> void:
	selected = false
	mesh.scale = Vector3.ONE


func _on_drag_selection_unit_selected() -> void:
	select()


func _on_drag_selection_unit_deselected() -> void:
	deselect()


func _on_timer_timeout() -> void:
	if is_player_controlled:
		$Timer.start()
		return
	scan_for_enemys()
	$Timer.start()


func _register_packet_sent() -> void:
	var world := get_tree().get_first_node_in_group("world_root")
	if world and world.has_method("register_network_packet_sent"):
		world.register_network_packet_sent(1)


func _register_packet_received() -> void:
	var world := get_tree().get_first_node_in_group("world_root")
	if world and world.has_method("register_network_packet_received"):
		world.register_network_packet_received(1)


func _is_game_paused() -> bool:
	var world := get_tree().get_first_node_in_group("world_root")
	if world and world.has_method("is_game_paused"):
		return world.is_game_paused()
	return false
