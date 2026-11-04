class_name WaveController
extends Node
## Spawns increasingly large enemy waves and tracks their completion.

signal wave_started(wave: int, enemy_count: int)
signal wave_completed(wave: int)
signal enemy_count_changed(alive_enemies: int)
signal enemy_defeated

@export var enemy_spawner: EntitySpawner
@export var initial_enemy_count: int = 4
@export var enemies_added_per_wave: int = 2
@export var spawn_interval: float = 0.65
@export var intermission_duration: float = 3.0

var current_wave := 0
var running := false

var _remaining_to_spawn := 0
var _alive_enemies := 0
var _spawn_remaining := 0.0
var _intermission_remaining := 0.5


func _process(delta: float) -> void:
	if not running or enemy_spawner == null:
		return

	if _remaining_to_spawn > 0:
		_spawn_remaining -= delta
		if _spawn_remaining <= 0.0:
			_spawn_enemy()
			_spawn_remaining = spawn_interval
		return

	if _alive_enemies > 0:
		return

	_intermission_remaining -= delta
	if _intermission_remaining <= 0.0:
		_start_next_wave()


func start() -> void:
	running = true
	current_wave = 0
	_remaining_to_spawn = 0
	_alive_enemies = 0
	_intermission_remaining = 0.5


func stop() -> void:
	running = false


func get_alive_enemy_count() -> int:
	return _alive_enemies


func _start_next_wave() -> void:
	if current_wave > 0:
		wave_completed.emit(current_wave)
	current_wave += 1
	_remaining_to_spawn = initial_enemy_count + (current_wave - 1) * enemies_added_per_wave
	_spawn_remaining = 0.0
	_intermission_remaining = intermission_duration
	wave_started.emit(current_wave, _remaining_to_spawn)


func _spawn_enemy() -> void:
	var enemy_id := &"enemy_crawler"
	if _remaining_to_spawn % 4 == 0:
		enemy_id = &"enemy_spitter"
	var enemy := enemy_spawner.spawn_entity(enemy_id) as Enemy
	_remaining_to_spawn -= 1
	if enemy == null:
		return

	enemy.configure_for_wave(current_wave)
	enemy.enemy_died.connect(_on_enemy_died)
	_alive_enemies += 1
	enemy_count_changed.emit(_alive_enemies)


func _on_enemy_died(_enemy: Enemy) -> void:
	_alive_enemies = maxi(_alive_enemies - 1, 0)
	enemy_count_changed.emit(_alive_enemies)
	enemy_defeated.emit()
