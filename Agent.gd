extends CharacterBody3D
class_name Agent

@onready var navigation_agent_3d: NavigationAgent3D = $NavigationAgent3D
@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var detection_area: Area3D = $Area3D


enum State {
	IDLE,
	MOVE,
	MOVE_STRAIGHT,
	CHASE,
	CHASE_TO_INTERACT,
	ATTACK,
	INTERACT,
	GATHER,
	RETURN_RESOURCE
}

var state = State.IDLE
var selected : bool = false
var team : String = ""
var area_is_monitoring : bool = true
var target = null

var hp = 100
var damage = 10

var attack_range = 2.0
var detection_range = 10.0
var interaction_range = 2.0

var attack_cooldown = 1.0
var attack_timer = 0.0
var interaction_cooldown = 1.0
var interaction_timer = 0.0

var gather_capacity : int = 20
var gather_per_tick : int = 5
var gather_interval : float = 0.5
var gather_timer : float = 0.0
var carry_amount : int = 0
var carry_type : StringName = &""
var gather_target = null
var resource_reach_range : float = 1.8

var speed = 5.0

var type : String = "pionir"
var abilities = ["build"]

func _ready():

	if team.is_empty():
		randomize()
		# Zufälliges Team
		if randi() % 3 == 0:
			team = "red"
		else:
			team = "blue"
	$DragSelectionUnit.set_team(team)
	update_team_color()

	# Detection Signal verbinden
	scan_for_enemys()


func scan_for_enemys():
	if target != null or self.state == State.MOVE_STRAIGHT or self.state == State.ATTACK:
		return
	for body in detection_area.get_overlapping_bodies():
		if body == self:
			continue
		if !body.has_method("take_damage"):
			continue
		# Nur Gegner angreifen
		if body.team == team:
			continue
		target = body
		state = State.CHASE
		return

func _unhandled_input(event: InputEvent) -> void:

	if selected == false:
		return

	if event.is_action_pressed("ui_accept"):

		var random_position := Vector3.ZERO
		random_position.x = randf_range(-50.0, 50.0)
		random_position.z = randf_range(-50.0, 50.0)

		navigation_agent_3d.set_target_position(random_position)

		state = State.MOVE


func _physics_process(delta: float) -> void:
	if attack_timer > 0:
		attack_timer -= delta
	if interaction_timer > 0:
		interaction_timer -= delta
	if gather_timer > 0:
		gather_timer -= delta

	match state:

		State.IDLE:
			$Area3D/CollisionShape3D.disabled = false
			#await get_tree().physics_frame
			velocity = Vector3.ZERO

		State.MOVE:
			$Area3D/CollisionShape3D.disabled = false
			#await get_tree().physics_frame
			handle_move()

		State.MOVE_STRAIGHT:
			$Area3D/CollisionShape3D.disabled = true
			handle_move()

		State.CHASE:
			$Area3D/CollisionShape3D.disabled = true
			handle_chase()

		State.ATTACK:
			$Area3D/CollisionShape3D.disabled = true
			handle_attack()

		State.CHASE_TO_INTERACT:
			if handle_chase_to_interact():
				state = State.IDLE

		State.INTERACT:
			handle_interact()

		State.GATHER:
			$Area3D/CollisionShape3D.disabled = true
			handle_gather()

		State.RETURN_RESOURCE:
			$Area3D/CollisionShape3D.disabled = true
			handle_return_resource()
	move_and_slide()


func handle_move():
	if navigation_agent_3d.is_navigation_finished():
		state = State.IDLE
		target = null
		return

	move_to_target()


func handle_chase():
	if !is_instance_valid(target):
		target = null
		state = State.IDLE
		return
	# Buildings are larger than a single point: chase and measure from the
	# nearest spot on their footprint, not their centre. The collider keeps the
	# agent outside the centre-based range even when it is right at the wall.
	navigation_agent_3d.set_target_position(approach_point(target))
	if attack_distance(target) <= attack_range:
		state = State.ATTACK
		return
	move_to_target()

func handle_chase_to_interact():
	if !is_instance_valid(target):
		target = null
		state = State.IDLE
		return
	navigation_agent_3d.set_target_position(approach_point(target))
	if reached(target):
		state = State.INTERACT
		return
	move_to_target()


func handle_attack():
	if !is_instance_valid(target):
		target = null
		state = State.IDLE
		return
	if attack_distance(target) > attack_range:
		state = State.CHASE
		return
	look_at(target.global_position)
	velocity = Vector3.ZERO
	if attack_timer > 0:
		return
	target.take_damage(damage)
	$AnimationPlayer.play("attack")
	attack_timer = attack_cooldown

func handle_interact() -> bool:
	if !is_instance_valid(target):
		target = null
		state = State.IDLE
		return false
	if !reached(target):
		state = State.CHASE_TO_INTERACT
		return false
	look_at_flat(target)
	velocity = Vector3.ZERO
	if interaction_timer > 0:
		return false
	if target.interaction():
		state = State.IDLE
		target = null
		return true
	$AnimationPlayer.play("attack")
	interaction_timer = interaction_cooldown
	return false



func interaction() -> bool:
	return true


func gather_from(resource_node) -> void:
	if resource_node == null or !is_instance_valid(resource_node):
		return
	if !resource_node.has_method("harvest"):
		return
	gather_target = resource_node
	target = resource_node
	state = State.GATHER


func handle_gather() -> void:
	if carry_amount >= gather_capacity:
		if start_return():
			return
		velocity = Vector3.ZERO
		return
	if !is_instance_valid(gather_target):
		if carry_amount > 0 and start_return():
			return
		gather_target = null
		target = null
		carry_amount = 0
		carry_type = &""
		state = State.IDLE
		return
	if !reached(gather_target):
		navigation_agent_3d.set_target_position(approach_point(gather_target))
		move_to_target()
		return
	velocity = Vector3.ZERO
	look_at_flat(gather_target)
	if gather_timer > 0:
		return
	var requested : int = mini(gather_per_tick, gather_capacity - carry_amount)
	var resource_type : StringName = gather_target.resource_id
	var taken : int = gather_target.harvest(requested)
	if taken <= 0:
		return
	carry_amount += taken
	carry_type = resource_type
	gather_timer = gather_interval
	$AnimationPlayer.play("attack")
	if carry_amount >= gather_capacity:
		start_return()


func handle_return_resource() -> void:
	if !is_instance_valid(target):
		target = null
		gather_target = null
		carry_amount = 0
		carry_type = &""
		state = State.IDLE
		return
	if carry_amount <= 0:
		continue_gathering()
		return
	if !reached(target):
		navigation_agent_3d.set_target_position(approach_point(target))
		move_to_target()
		return
	velocity = Vector3.ZERO
	look_at_flat(target)
	var delivered : int = carry_amount
	carry_amount = 0
	if target.has_method("deposit"):
		target.deposit(carry_type, delivered, team)
	carry_type = &""
	continue_gathering()


func start_return() -> bool:
	var dropoff = find_dropoff()
	if dropoff == null:
		return false
	target = dropoff
	state = State.RETURN_RESOURCE
	return true


func continue_gathering() -> void:
	if is_instance_valid(gather_target):
		target = gather_target
		state = State.GATHER
		return
	gather_target = null
	target = null
	state = State.IDLE


func find_dropoff():
	var best = null
	var best_distance : float = INF
	for node in get_tree().get_nodes_in_group("resource_dropoff"):
		if !is_instance_valid(node):
			continue
		if node.has_method("is_constructed") and !node.is_constructed():
			continue
		if node.has_method("get_team") and node.get_team() != team:
			continue
		var distance : float = Vector2(node.global_position.x - global_position.x, node.global_position.z - global_position.z).length()
		if distance < best_distance:
			best_distance = distance
			best = node
	return best


func approach_point(node) -> Vector3:
	var rts = node.get_node_or_null("RTSBuilding")
	if rts != null:
		var half_width : float = float(rts.width) * 0.5
		var half_depth : float = float(rts.depth) * 0.5
		return Vector3(
			node.global_position.x + clampf(global_position.x - node.global_position.x, -half_width, half_width),
			global_position.y,
			node.global_position.z + clampf(global_position.z - node.global_position.z, -half_depth, half_depth)
		)
	return Vector3(node.global_position.x, global_position.y, node.global_position.z)


func reached(node) -> bool:
	var point : Vector3 = approach_point(node)
	var range_to_use : float = interaction_range
	if node.get_node_or_null("RTSBuilding") == null:
		range_to_use = resource_reach_range
	return Vector2(point.x - global_position.x, point.z - global_position.z).length() <= range_to_use


## Horizontal distance from this agent to the nearest reachable point of a
## target. For buildings this is the closest edge of their footprint, so a
## large building does not need a huge attack_range to be attackable.
func attack_distance(node) -> float:
	var point : Vector3 = approach_point(node)
	return Vector2(point.x - global_position.x, point.z - global_position.z).length()


func look_at_flat(node) -> void:
	var look_target := Vector3(node.global_position.x, global_position.y, node.global_position.z)
	if look_target.distance_squared_to(global_position) > 0.0001:
		look_at(look_target)


func move_to_target():
	var destination = navigation_agent_3d.get_next_path_position()
	var direction = (destination - global_position).normalized()
	velocity = direction * speed


func take_damage(amount):
	hp -= amount
	if hp <= 0:
		die()


func die():
	$DragSelectionUnit.unregister()
	queue_free()



func update_team_color():

	var mat = mesh.get_active_material(0)

	if mat:
		mat = mat.duplicate()

		if team == "blue":
			mat.albedo_color = Color(0.0, 0.323, 0.899, 1.0)

		else:
			mat.albedo_color = Color(0.899, 0.1, 0.1, 1.0)

		mesh.set_surface_override_material(0, mat)


func select():
	selected = true
	mesh.scale = Vector3(1.2, 1.2, 1.2)


func deselect():
	selected = false
	mesh.scale = Vector3.ONE


func _on_drag_selection_unit_selected() -> void:
	select()


func _on_drag_selection_unit_deselected() -> void:
	deselect()


func _on_timer_timeout() -> void:
	scan_for_enemys()
	$Timer.start()
