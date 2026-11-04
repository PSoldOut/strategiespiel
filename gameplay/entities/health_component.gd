class_name HealthComponent
extends Node

signal health_changed(current_life: float, max_life: float)
signal died

@export_range(0.001, 1000000.0) var max_life: float = 100.0
@export_range(0.0, 1000000.0) var current_life: float = 100.0

var _is_dead := false


func _ready() -> void:
	current_life = clampf(current_life, 0.0, max_life)
	_is_dead = is_zero_approx(current_life)


func damage(amount: float) -> void:
	if amount <= 0.0 or _is_dead:
		return

	current_life = maxf(current_life - amount, 0.0)
	health_changed.emit(current_life, max_life)
	if is_zero_approx(current_life):
		_is_dead = true
		died.emit()


func heal(amount: float) -> void:
	if amount <= 0.0 or _is_dead or is_equal_approx(current_life, max_life):
		return

	current_life = minf(current_life + amount, max_life)
	health_changed.emit(current_life, max_life)


func set_max_life(value: float, refill: bool = true) -> void:
	max_life = maxf(value, 0.001)
	current_life = max_life if refill else minf(current_life, max_life)
	_is_dead = is_zero_approx(current_life)
	health_changed.emit(current_life, max_life)


func is_dead() -> bool:
	return _is_dead
