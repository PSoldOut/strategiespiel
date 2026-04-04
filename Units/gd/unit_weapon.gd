extends Node3D
class_name UnitWeapon

@export var attack_duration: float = 0.25
@export var attack_angle_deg: float = 45.0
@export var return_speed: float = 12.0

var _base_rotation: Vector3
var _attacking: bool = false
var _attack_timer: float = 0.0

func _ready() -> void:
	_base_rotation = rotation

func update_animation(delta: float) -> void:
	if _attacking:
		_attack_timer += delta
		
		var half_duration := attack_duration * 0.5
		var target_angle := deg_to_rad(attack_angle_deg)
		var rot := _base_rotation
		
		if _attack_timer <= half_duration:
			var t := _attack_timer / half_duration
			rot.x = lerp(_base_rotation.x, _base_rotation.x - target_angle, t)
		elif _attack_timer <= attack_duration:
			var t := (_attack_timer - half_duration) / half_duration
			rot.x = lerp(_base_rotation.x - target_angle, _base_rotation.x, t)
		else:
			rot = _base_rotation
			_attacking = false
		
		rotation = rot
	else:
		rotation = rotation.lerp(_base_rotation, return_speed * delta)

func play_attack() -> void:
	_attacking = true
	_attack_timer = 0.0
