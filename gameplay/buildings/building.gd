class_name Building
extends Node3D
## Shared health and target lifecycle for final placed building instances.

signal destroyed(building: Node3D)

const GROUP_BUILDINGS := &"buildings"
const HEALTH_COMPONENT_SCRIPT := preload("res://gameplay/entities/health_component.gd")
const WORLD_PROGRESS_BAR_SCRIPT := preload("res://gameplay/ui/world_progress_bar_3d.gd")

@export_range(1.0, 1000000.0) var max_life: float = 150.0
@export_range(0.0, 100.0) var target_radius: float = 1.0

@onready var health_component: HEALTH_COMPONENT_SCRIPT = %HealthComponent
@onready var health_bar: WORLD_PROGRESS_BAR_SCRIPT = %HealthBar

var _is_active := false
var _is_destroyed := false


func _ready() -> void:
	health_bar.visible = false
	health_component.health_changed.connect(_on_health_changed)
	health_component.died.connect(_on_died)


func activate() -> void:
	if _is_active:
		return
	_is_active = true
	add_to_group(GROUP_BUILDINGS)
	health_component.set_max_life(max_life, true)
	health_bar.visible = true
	_on_activated()


func is_active() -> bool:
	return _is_active and not _is_destroyed


func take_damage(amount: float) -> void:
	if is_active():
		health_component.damage(amount)


func is_dead() -> bool:
	return _is_destroyed or health_component.is_dead()


func get_target_radius() -> float:
	return target_radius


func _on_activated() -> void:
	pass


func _on_health_changed(current_life: float, current_max_life: float) -> void:
	health_bar.set_ratio(current_life / current_max_life)


func _on_died() -> void:
	if _is_destroyed:
		return
	_is_destroyed = true
	_is_active = false
	remove_from_group(GROUP_BUILDINGS)
	health_bar.set_ratio(0.0)
	destroyed.emit(self)
	queue_free()
