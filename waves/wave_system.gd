extends Node
class_name WaveSystem

## Owns wave timing and enemy spawning.
##
## Target selection is delegated to a WaveTargetingAI resource: this system
## only gathers the current player units/buildings, asks the AI, and applies the
## result as attack orders. The AI itself has no references to this system.

signal wave_started(wave_number: int, enemy_count: int)
signal wave_cleared(wave_number: int)
## Emitted while waiting, including the remaining seconds for the debug UI.
signal break_started(seconds: float, next_wave: int)

@export var enemy_team: String = "red"
@export var enemy_scene: PackedScene
@export var targeting_ai: WaveTargetingAI

## Seconds before the first wave and between later waves.
@export var first_wave_delay: float = 30.0
@export var wave_interval: float = 10.0

## Enemy count = base_enemy_count + (wave - 1) * additional_per_wave.
@export var base_enemy_count: int = 3
@export var additional_per_wave: int = 2

## Enemies appear on a ring around the map centre with this radius.
@export var spawn_radius: float = 40.0
## Height above the ground hit at the spawn point.
@export var spawn_height: float = 1.0

## How often enemy attack orders are refreshed during a wave.
@export var order_refresh_interval: float = 5.0
## Prints "attacker -> target" lines whenever orders are assigned.
@export var debug_print_orders: bool = true

var _units_root: Node3D
var _buildings_root: Node3D
var _drag_selection: DragSelection
var _player_team: String = "blue"
var _map_rect := Rect2()
var _ground_height_callback: Callable

var _wave_number := 0
var _break_remaining := 0.0
var _active_enemies: Array[Node] = []
var _wave_active := false
var _order_timer := 0.0


## Called by Game once the map and its objects are ready.
func configure(
	units_root: Node3D,
	buildings_root: Node3D,
	drag_selection: DragSelection,
	player_team: String,
	map_rect: Rect2,
	ground_height_callback: Callable
) -> void:
	_units_root = units_root
	_buildings_root = buildings_root
	_drag_selection = drag_selection
	_player_team = player_team
	_map_rect = map_rect
	_ground_height_callback = ground_height_callback


func start() -> void:
	if enemy_scene == null:
		push_warning("WaveSystem: no enemy_scene assigned, waves are disabled.")
		return
	_break_remaining = first_wave_delay
	break_started.emit(_break_remaining, _wave_number + 1)


func _process(delta: float) -> void:
	if _wave_active:
		_check_wave(delta)
		return
	if _break_remaining <= 0.0:
		return
	_break_remaining = maxf(_break_remaining - delta, 0.0)
	break_started.emit(_break_remaining, _wave_number + 1)
	if _break_remaining <= 0.0:
		_start_next_wave()


func _start_next_wave() -> void:
	_wave_number += 1
	var count := base_enemy_count + (_wave_number - 1) * additional_per_wave
	_active_enemies.clear()
	for index in range(count):
		var enemy := _spawn_enemy(index, count)
		if enemy != null:
			_active_enemies.append(enemy)

	_wave_active = true
	_order_timer = 0.0
	wave_started.emit(_wave_number, _active_enemies.size())
	_assign_orders()


func _spawn_enemy(index: int, count: int) -> Node3D:
	if enemy_scene == null or _units_root == null:
		return null

	var enemy := enemy_scene.instantiate() as Node3D
	if enemy == null:
		return null

	# Set the team before entering the tree: Agent._ready() randomises an empty
	# team, so doing this afterwards would be too late.
	enemy.set("team", enemy_team)
	var selection_unit := enemy.get_node_or_null("DragSelectionUnit")
	if selection_unit != null and selection_unit.has_method("set_team"):
		selection_unit.call("set_team", enemy_team)

	_units_root.add_child(enemy)
	enemy.global_position = _spawn_position(index, count)
	if enemy.has_method("update_team_color"):
		enemy.call("update_team_color")
	if _drag_selection != null and not _drag_selection.units.has(enemy):
		_drag_selection.register_unit(enemy)
	return enemy


func _spawn_position(index: int, count: int) -> Vector3:
	var centre := _map_rect.get_center()
	var angle := TAU * float(index) / float(maxi(count, 1))
	var x := clampf(
		centre.x + cos(angle) * spawn_radius,
		_map_rect.position.x + 2.0,
		_map_rect.end.x - 2.0
	)
	var z := clampf(
		centre.y + sin(angle) * spawn_radius,
		_map_rect.position.y + 2.0,
		_map_rect.end.y - 2.0
	)

	var y := spawn_height
	if _ground_height_callback.is_valid():
		var height_value: Variant = _ground_height_callback.call(x, z)
		if height_value is float:
			y += height_value as float
		elif height_value is int:
			y += float(height_value as int)
	return Vector3(x, y, z)


func _check_wave(delta: float) -> void:
	var alive: Array[Node] = []
	for enemy in _active_enemies:
		if is_instance_valid(enemy):
			alive.append(enemy)
	_active_enemies = alive

	if not _active_enemies.is_empty():
		_order_timer += delta
		if _order_timer >= order_refresh_interval:
			_order_timer = 0.0
			_assign_orders()
		return

	_order_timer = 0.0
	_wave_active = false
	wave_cleared.emit(_wave_number)
	_break_remaining = wave_interval
	break_started.emit(_break_remaining, _wave_number + 1)


## Gathers the AI input, asks the AI, then turns the answer into engine orders.
func _assign_orders() -> void:
	if targeting_ai == null:
		return

	var attackers: Array = []
	for enemy in _active_enemies:
		if is_instance_valid(enemy):
			attackers.append(enemy)

	var player_units: Array = []
	if _units_root != null:
		for unit in _units_root.get_children():
			if str(unit.get("team")) == _player_team:
				player_units.append(unit)

	var player_buildings: Array = []
	if _buildings_root != null:
		for building in _buildings_root.get_children():
			if building.has_method("get_team") and str(building.call("get_team")) == _player_team:
				player_buildings.append(building)

	var assignments: Dictionary = targeting_ai.assign_targets(
		attackers, player_units, player_buildings
	)

	for attacker in assignments.keys():
		var enemy = attacker
		var target = assignments[attacker]
		if not (enemy is Node3D) or not is_instance_valid(enemy):
			continue
		if not (target is Node3D) or not is_instance_valid(target):
			continue
		# Same order pattern the player uses when right-clicking an enemy.
		enemy.set("target", target)
		enemy.set("state", enemy.State.CHASE)

	if debug_print_orders:
		for line in targeting_ai.describe_assignments(assignments):
			print("[WaveSystem] ", line)
