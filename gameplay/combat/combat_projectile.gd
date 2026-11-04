class_name CombatProjectile
extends Node3D
## Moves toward one target and applies damage on impact.

const METHOD_IS_DEAD := &"is_dead"
const METHOD_TAKE_DAMAGE := &"take_damage"

@export var speed: float = 16.0
@export var impact_distance: float = 0.35
@export var maximum_lifetime: float = 6.0
@export var projectile_color := Color(1.0, 0.8, 0.15)

var target: Node3D
var damage: float
var _remaining_lifetime: float

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D


func _ready() -> void:
	_remaining_lifetime = maximum_lifetime
	var material := StandardMaterial3D.new()
	material.albedo_color = projectile_color
	material.emission_enabled = true
	material.emission = projectile_color
	material.emission_energy_multiplier = 2.0
	mesh_instance.material_override = material


func _process(delta: float) -> void:
	_remaining_lifetime -= delta
	if _remaining_lifetime <= 0.0 or not is_instance_valid(target):
		queue_free()
		return
	if target.has_method(METHOD_IS_DEAD) and target.call(METHOD_IS_DEAD):
		queue_free()
		return

	var target_position := target.global_position + Vector3.UP * 0.5
	var offset := target_position - global_position
	var travel_distance := speed * delta
	if offset.length() <= maxf(impact_distance, travel_distance):
		_impact()
		return
	global_position += offset.normalized() * travel_distance


func configure(
	new_target: Node3D,
	new_damage: float,
	new_speed: float = 16.0,
	new_color: Color = Color(1.0, 0.8, 0.15),
) -> void:
	target = new_target
	damage = maxf(new_damage, 0.0)
	speed = maxf(new_speed, 0.01)
	projectile_color = new_color


func _impact() -> void:
	if is_instance_valid(target) and target.has_method(METHOD_TAKE_DAMAGE):
		target.call(METHOD_TAKE_DAMAGE, damage)
	queue_free()
