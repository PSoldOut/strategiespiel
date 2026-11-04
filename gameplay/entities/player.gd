class_name Player
extends CharacterBody3D

signal died

const GROUP_PLAYER := &"player"
const GROUP_ENEMIES := &"enemies"
const ACTION_MOVE_UP := &"move_up"
const ACTION_MOVE_DOWN := &"move_down"
const ACTION_MOVE_LEFT := &"move_left"
const ACTION_MOVE_RIGHT := &"move_right"
const ENEMY_SCRIPT := preload("res://gameplay/entities/enemy.gd")
const HEALTH_COMPONENT_SCRIPT := preload("res://gameplay/entities/health_component.gd")

@export_range(0.0, 100.0) var speed: float = 6.0
@export_range(0.0, 100.0) var attack_range: float = 5.0
@export_range(0.0, 100000.0) var attack_damage: float = 10.0
@export_range(0.01, 100.0) var attack_cooldown: float = 0.6
@export_range(0.0, 100.0) var gravity: float = 20.0

@onready var health_component: HEALTH_COMPONENT_SCRIPT = %HealthComponent

var _attack_cooldown_remaining := 0.0
var _has_died := false


func _ready() -> void:
	add_to_group(GROUP_PLAYER)
	floor_snap_length = 0.5
	health_component.died.connect(_on_health_component_died)


func _physics_process(delta: float) -> void:
	if _has_died:
		velocity = Vector3.ZERO
		return

	var input := Input.get_vector(
		ACTION_MOVE_LEFT,
		ACTION_MOVE_RIGHT,
		ACTION_MOVE_UP,
		ACTION_MOVE_DOWN
	)
	var vertical_velocity := velocity.y
	if is_on_floor() and vertical_velocity < 0.0:
		vertical_velocity = 0.0
	else:
		vertical_velocity -= gravity * delta
	velocity = Vector3(input.x * speed, vertical_velocity, input.y * speed)
	move_and_slide()

	_attack_cooldown_remaining = maxf(_attack_cooldown_remaining - delta, 0.0)
	if not is_zero_approx(_attack_cooldown_remaining):
		return

	var target := _find_nearest_enemy()
	if target != null and _xz_distance_to(target) <= attack_range:
		target.take_damage(attack_damage)
		_attack_cooldown_remaining = attack_cooldown


func take_damage(amount: float) -> void:
	health_component.damage(amount)


func is_dead() -> bool:
	return health_component.is_dead()


func _find_nearest_enemy() -> ENEMY_SCRIPT:
	var nearest: ENEMY_SCRIPT = null
	var nearest_distance := INF
	for node in get_tree().get_nodes_in_group(GROUP_ENEMIES):
		var enemy := node as ENEMY_SCRIPT
		if enemy == null or enemy.health_component.is_dead():
			continue
		var distance := _xz_distance_to(enemy)
		if distance < nearest_distance:
			nearest = enemy
			nearest_distance = distance
	return nearest


func _xz_distance_to(target: Node3D) -> float:
	var offset := target.global_position - global_position
	offset.y = 0.0
	return offset.length()


func _on_health_component_died() -> void:
	_has_died = true
	died.emit()
