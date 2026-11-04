class_name FriendlySoldier
extends CharacterBody3D

signal died

const GROUP_FRIENDLY_UNITS := &"friendly_units"
const GROUP_ENEMIES := &"enemies"
const ENEMY_SCRIPT := preload("res://gameplay/entities/enemy.gd")
const HEALTH_COMPONENT_SCRIPT := preload("res://gameplay/entities/health_component.gd")

@export_range(0.0, 100.0) var speed: float = 4.0
@export_range(0.0, 100.0) var attack_range: float = 2.0
@export_range(0.0, 100000.0) var attack_damage: float = 6.0
@export_range(0.01, 100.0) var attack_cooldown: float = 0.8
@export_range(0.0, 100.0) var gravity: float = 20.0

@onready var health_component: HEALTH_COMPONENT_SCRIPT = %HealthComponent

var _attack_cooldown_remaining := 0.0
var _has_died := false


func _ready() -> void:
	add_to_group(GROUP_FRIENDLY_UNITS)
	floor_snap_length = 0.5
	health_component.died.connect(_on_health_component_died)


func _physics_process(delta: float) -> void:
	if _has_died:
		velocity = Vector3.ZERO
		return
	var vertical_velocity := velocity.y
	if is_on_floor() and vertical_velocity < 0.0:
		vertical_velocity = 0.0
	else:
		vertical_velocity -= gravity * delta

	var target := _find_nearest_enemy()
	if target == null:
		velocity = Vector3(0.0, vertical_velocity, 0.0)
		move_and_slide()
		return

	var offset := target.global_position - global_position
	offset.y = 0.0
	var distance := offset.length()
	_attack_cooldown_remaining = maxf(_attack_cooldown_remaining - delta, 0.0)
	if distance <= attack_range:
		velocity = Vector3(0.0, vertical_velocity, 0.0)
		if is_zero_approx(_attack_cooldown_remaining):
			target.take_damage(attack_damage)
			_attack_cooldown_remaining = attack_cooldown
		move_and_slide()
		return

	var movement := offset.normalized() * speed
	velocity = Vector3(movement.x, vertical_velocity, movement.z)
	move_and_slide()


func take_damage(amount: float) -> void:
	health_component.damage(amount)


func _find_nearest_enemy() -> ENEMY_SCRIPT:
	var nearest: ENEMY_SCRIPT = null
	var nearest_distance := INF
	for node in get_tree().get_nodes_in_group(GROUP_ENEMIES):
		var enemy := node as ENEMY_SCRIPT
		if enemy == null or enemy.health_component.is_dead():
			continue
		var offset := enemy.global_position - global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance < nearest_distance:
			nearest = enemy
			nearest_distance = distance
	return nearest


func _on_health_component_died() -> void:
	_has_died = true
	died.emit()
