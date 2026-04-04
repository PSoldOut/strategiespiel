extends Node3D
class_name UnitBody

@export var breath_speed: float = 2.0
@export var breath_strength: float = 0.03

var _base_scale: Vector3 = Vector3.ONE
var _time: float = 0.0
var _weapon: Node3D

func _ready() -> void:
	_base_scale = scale

func set_weapon(weapon: Node3D) -> void:
	_weapon = weapon

func update_animation(delta: float) -> void:
	play_idle(delta)

func play_idle(delta: float) -> void:
	_time += delta * breath_speed
	
	var breath := sin(_time) * breath_strength
	scale = Vector3(
		_base_scale.x - breath * 0.3,
		_base_scale.y + breath,
		_base_scale.z - breath * 0.3
	)

func play_move(delta: float) -> void:
	_time += delta * breath_speed * 2.0
	
	var breath := sin(_time) * breath_strength * 1.5
	scale = Vector3(
		_base_scale.x - breath * 0.2,
		_base_scale.y + breath,
		_base_scale.z - breath * 0.2
	)

func play_attack() -> void:
	pass
