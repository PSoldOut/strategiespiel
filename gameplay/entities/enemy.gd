class_name Enemy
extends CharacterBody3D

signal enemy_died(enemy: Enemy)

const GROUP_PLAYER := &"player"
const GROUP_BUILDINGS := &"buildings"
const GROUP_ENEMIES := &"enemies"
const METHOD_IS_DEAD := &"is_dead"
const METHOD_TAKE_DAMAGE := &"take_damage"
const METHOD_GET_TARGET_RADIUS := &"get_target_radius"
const COMBAT_PROJECTILE_SCRIPT := preload("res://gameplay/combat/combat_projectile.gd")
const HEALTH_COMPONENT_SCRIPT := preload("res://gameplay/entities/health_component.gd")

@export_range(0.001, 100000.0) var base_max_life: float = 40.0
@export_range(0.0, 100.0) var base_speed: float = 3.0
@export_range(0.0, 100000.0) var base_attack_damage: float = 8.0
@export_range(0.0, 100.0) var attack_range: float = 1.5
@export_range(0.01, 100.0) var attack_cooldown: float = 1.0
@export_range(0.0, 10.0) var life_growth_per_wave: float = 0.15
@export_range(0.0, 10.0) var speed_growth_per_wave: float = 0.03
@export_range(0.0, 10.0) var damage_growth_per_wave: float = 0.1
@export_range(0.0, 100.0) var gravity: float = 20.0
@export var projectile_scene: PackedScene
@export_range(0.01, 100.0) var projectile_speed: float = 12.0
@export var projectile_color := Color(0.8, 0.2, 1.0)

@onready var health_component: HEALTH_COMPONENT_SCRIPT = %HealthComponent

var speed: float
var attack_damage: float
var configured_wave := 1
var _attack_cooldown_remaining := 0.0
var _target: Node3D
var _is_dying := false


func _ready() -> void:
	add_to_group(GROUP_ENEMIES)
	floor_snap_length = 0.5
	health_component.died.connect(_on_health_component_died)
	configure_for_wave(configured_wave)


func _physics_process(delta: float) -> void:
	if _is_dying:
		return
	var vertical_velocity := velocity.y
	if is_on_floor() and vertical_velocity < 0.0:
		vertical_velocity = 0.0
	else:
		vertical_velocity -= gravity * delta
	_target = _find_nearest_target()
	if _target == null:
		velocity = Vector3(0.0, vertical_velocity, 0.0)
		move_and_slide()
		return

	var offset := _target.global_position - global_position
	offset.y = 0.0
	var distance := offset.length()
	_attack_cooldown_remaining = maxf(_attack_cooldown_remaining - delta, 0.0)
	var target_radius := 0.0
	if _target.has_method(METHOD_GET_TARGET_RADIUS):
		target_radius = float(_target.call(METHOD_GET_TARGET_RADIUS))
	if distance <= attack_range + target_radius:
		velocity = Vector3(0.0, vertical_velocity, 0.0)
		if is_zero_approx(_attack_cooldown_remaining):
			_attack_target()
			_attack_cooldown_remaining = attack_cooldown
		move_and_slide()
		return

	var movement := offset.normalized() * speed
	velocity = Vector3(movement.x, vertical_velocity, movement.z)
	move_and_slide()


func take_damage(amount: float) -> void:
	health_component.damage(amount)


func is_dead() -> bool:
	return health_component.is_dead()


func _attack_target() -> void:
	if projectile_scene == null:
		_target.call(METHOD_TAKE_DAMAGE, attack_damage)
		return

	var projectile: COMBAT_PROJECTILE_SCRIPT = projectile_scene.instantiate()
	projectile.configure(_target, attack_damage, projectile_speed, projectile_color)
	get_parent().add_child(projectile)
	projectile.global_position = global_position + Vector3.UP * 0.6


func configure_for_wave(
	wave: int,
	tier_life_multiplier: float = 1.0,
	tier_speed_multiplier: float = 1.0,
	tier_damage_multiplier: float = 1.0
) -> void:
	configured_wave = maxi(wave, 1)
	var completed_waves := float(configured_wave - 1)
	var life_multiplier := 1.0 + life_growth_per_wave * completed_waves
	var speed_multiplier := 1.0 + speed_growth_per_wave * completed_waves
	var damage_multiplier := 1.0 + damage_growth_per_wave * completed_waves
	health_component.set_max_life(
		base_max_life * life_multiplier * maxf(tier_life_multiplier, 0.0)
	)
	speed = base_speed * speed_multiplier * maxf(tier_speed_multiplier, 0.0)
	attack_damage = (
		base_attack_damage * damage_multiplier * maxf(tier_damage_multiplier, 0.0)
	)


func _find_nearest_target() -> Node3D:
	var nearest: Node3D
	var nearest_distance := INF
	var candidates := get_tree().get_nodes_in_group(GROUP_PLAYER)
	candidates.append_array(get_tree().get_nodes_in_group(GROUP_BUILDINGS))
	for candidate_node in candidates:
		var candidate := candidate_node as Node3D
		if (
			candidate == null
			or not candidate.has_method(METHOD_IS_DEAD)
			or not candidate.has_method(METHOD_TAKE_DAMAGE)
			or bool(candidate.call(METHOD_IS_DEAD))
		):
			continue
		var offset := candidate.global_position - global_position
		offset.y = 0.0
		var distance := offset.length()
		if candidate.has_method(METHOD_GET_TARGET_RADIUS):
			distance -= float(candidate.call(METHOD_GET_TARGET_RADIUS))
		if distance < nearest_distance:
			nearest = candidate
			nearest_distance = distance
	return nearest


func _on_health_component_died() -> void:
	if _is_dying:
		return
	_is_dying = true
	enemy_died.emit(self)
	queue_free()
