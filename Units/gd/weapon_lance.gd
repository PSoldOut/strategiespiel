extends UnitWeapon
class_name WeaponLance

@export var thrust_length: float = 0.25   # distance forward
var _base_position: Vector3

func _ready() -> void:
	_base_position = position

func update_animation(delta: float) -> void:
	if _attacking:
		_attack_timer += delta
		
		var half_duration := attack_duration * 0.5
		var pos := _base_position
		
		if _attack_timer <= half_duration:
			# thrust forward
			var t := _attack_timer / half_duration
			pos = _base_position + (-transform.basis.z * thrust_length * t)
		
		elif _attack_timer <= attack_duration:
			# retract
			var t := (_attack_timer - half_duration) / half_duration
			pos = _base_position + (-transform.basis.z * thrust_length * (1.0 - t))
		
		else:
			pos = _base_position
			_attacking = false
		
		position = pos
	
	else:
		# smooth return (in case interrupted)
		position = position.lerp(_base_position, return_speed * delta)

func play_attack() -> void:
	_attacking = true
	_attack_timer = 0.0
