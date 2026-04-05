extends UnitBody


func play_move(delta: float) -> void:
	_time += delta * breath_speed * 4.0
	
	var breath := sin(_time) * breath_strength * 2
	scale = Vector3(
		_base_scale.x - breath * 0.2,
		_base_scale.y + breath,
		_base_scale.z - breath * 0.2
	)
