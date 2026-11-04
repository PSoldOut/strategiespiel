class_name BarracksBuilding
extends "res://gameplay/buildings/building.gd"
## Periodically spawns allied soldiers at UnitSpawnPoint.

const SOLDIER_SCENE_PATH := "res://gameplay/entities/friendly_soldier.tscn"
const SPAWN_PROGRESS_BAR_SCRIPT := preload("res://gameplay/ui/world_progress_bar_3d.gd")

@export var spawn_interval: float = 8.0
@export var maximum_soldiers: int = 6
@export var soldier_parent: Node3D

@onready var unit_spawn_point: Marker3D = $UnitSpawnPoint
@onready var spawn_progress_bar: SPAWN_PROGRESS_BAR_SCRIPT = %SpawnProgressBar

var _spawn_remaining := 0.0
var _soldiers: Array[FriendlySoldier] = []


func _process(delta: float) -> void:
	if not is_active():
		return
	_remove_invalid_soldiers()
	if _soldiers.size() >= maximum_soldiers:
		spawn_progress_bar.set_ratio(1.0)
		return

	_spawn_remaining -= delta
	spawn_progress_bar.set_ratio(get_spawn_progress())
	if _spawn_remaining > 0.0:
		return
	_spawn_remaining = spawn_interval
	_spawn_soldier()
	spawn_progress_bar.set_ratio(0.0)


func get_spawn_progress() -> float:
	if spawn_interval <= 0.0:
		return 1.0
	return clampf(1.0 - _spawn_remaining / spawn_interval, 0.0, 1.0)


func _on_activated() -> void:
	_spawn_remaining = spawn_interval
	spawn_progress_bar.visible = true
	spawn_progress_bar.set_ratio(0.0)


func _spawn_soldier() -> void:
	var soldier_scene := load(SOLDIER_SCENE_PATH) as PackedScene
	var soldier := soldier_scene.instantiate() as FriendlySoldier
	var target_parent := soldier_parent if is_instance_valid(soldier_parent) else get_parent()
	target_parent.add_child(soldier)
	soldier.global_transform = unit_spawn_point.global_transform
	soldier.global_position.y += 0.75
	_soldiers.append(soldier)


func _remove_invalid_soldiers() -> void:
	_soldiers = _soldiers.filter(func(soldier: FriendlySoldier) -> bool:
		return is_instance_valid(soldier) and not soldier.health_component.is_dead()
	)
