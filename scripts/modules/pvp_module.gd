class_name PvPModule extends GameModule

var _test := {
	"host_started": false,
	"client_joined": false,
	"spawn_sync": false,
	"move_sync": false,
	"disconnect_stable": false,
	"rejoin_ok": false
}
signal test_checkpoint(name: String, passed: bool, details: String)

var network_manager: NetworkManager
var world_node: Node
var is_host_mode: bool = true
var target_address: String = "127.0.0.1"
var target_port: int = 24570

var _retry_attempts: int = 0
const MAX_RETRIES: int = 3

var spawn_service: Node
const SPAWN_SERVICE_SCENE := preload("res://scenes/service_spawner_unit_simple.tscn")
const UNIT_SCENE := preload("res://scenes/rts_unit_simple.tscn")

func boot(context: Dictionary) -> void:
	print("PVP start..", context)
	network_manager = context.get("network_manager", null)
	world_node = context.get("world_node", null)
	is_host_mode = context.get("is_host", true)
	target_address = context.get("address", "127.0.0.1")
	target_port = context.get("port", 24570)
	
	if network_manager == null:
		push_error("PVP: Missing network_manager in context!")
		return
	
	add_to_group("pvp_runtime")
	
	_ensure_spawn_service()
	
	_bind_network_events()
	
	if is_host_mode:
		var err := network_manager.host_game(target_port)
		if err != OK:
			push_error("PVP: Host start failed: " + str(err))
			return
		_spawn_initial_for_host()
		_mark_test("host_started", true, "port="+str(target_port))
	else:
		var err := network_manager.join_game(target_address, target_port)
		if err != OK:
			push_error("PVP: Join failed: " + str(err))
			return

func _ensure_spawn_service() -> void:
	if spawn_service != null:
		return
	if world_node == null:
		push_error("PVP: Missing world_node in context!")
		return
	
	spawn_service = SPAWN_SERVICE_SCENE.instantiate()
	spawn_service.name = "UnitSpawnService"
	world_node.add_child(spawn_service)
	
	spawn_service.set("unit_scene", UNIT_SCENE)
	spawn_service.set("unit_root_path", NodePath(".."))

func _spawn_initial_for_host() -> void:
	if spawn_service == null or not is_instance_valid(spawn_service):
		return
	var host_team := 0
	var units_per_row := 4
	var spacing := 2.5
	var base_x := -12.0
	var base_z := -8.0
	
	for i in range(10):
		var row := i / units_per_row
		var col := i % units_per_row
		var spawn_pos := Vector3(
			base_x + col * spacing,
			0.0,
			base_z + row * spacing
		)
		spawn_service.call("server_spawn", host_team, spawn_pos)

func _request_spawn_for_local_client() -> void:
	if spawn_service == null or not is_instance_valid(spawn_service):
		return
	var local_team := multiplayer.get_unique_id()
#	var request_pos := Vector3(8.0, 0.0, 0.0)
#	spawn_service.rpc_id(1, "request_spawn", local_team, request_pos)
	
	var units_per_row := 4
	var spacing := 2.5
	var base_X := 12.0
	var base_Z := -8.0
	
	for i in range(10):
		var row := i / units_per_row
		var col := i % units_per_row
		var spawn_pos := Vector3(
			base_X + col * spacing,
			0.0,
			base_Z + row * spacing
		)
		spawn_service.rpc_id(1, "request_spawn", local_team, spawn_pos)

func _spawn_position_for_peer(peer_id: int) -> Vector3:
	return Vector3(float(peer_id) * 2.5, 0.0, 6.0)	

func shutdown() -> void:
	print("PVP shutdown..")
	if network_manager != null:
		_unbind_network_events()
		network_manager.disconnect_game()
	if spawn_service != null and is_instance_valid(spawn_service):
		spawn_service.queue_free()
		spawn_service = null
	remove_from_group("pvp_runtime")

func _bind_network_events() -> void:
	network_manager.peer_joined.connect(_on_peer_joined)
	network_manager.peer_left.connect(_on_peer_left)
	network_manager.connected_to_server.connect(_on_connected)
	network_manager.connection_failed.connect(_on_connection_failed)
	network_manager.disconnected.connect(_on_disconnected)

func _unbind_network_events() -> void:
	if network_manager.peer_joined.is_connected(_on_peer_joined):
		network_manager.peer_joined.disconnect(_on_peer_joined)
	if network_manager.peer_left.is_connected(_on_peer_left):
		network_manager.peer_left.disconnect(_on_peer_left)
	if network_manager.connected_to_server.is_connected(_on_connected):
		network_manager.connected_to_server.disconnect(_on_connected)
	if network_manager.connection_failed.is_connected(_on_connection_failed):
		network_manager.connection_failed.disconnect(_on_connection_failed)
	if network_manager.disconnected.is_connected(_on_disconnected):
		network_manager.disconnected.disconnect(_on_disconnected)

func _on_peer_joined(peer_id: int) -> void:
	print("PvP: peer joined: " + str(peer_id))
	if multiplayer.is_server() and spawn_service != null:
		_sync_existing_units_to_peer(peer_id)
		var team_for_peer := peer_id
		var units_per_row := 4
		var spacing := 2.5
		var base_X := 12.0
		var base_Z := -8.0
	
		for i in range(10):
			var row := i / units_per_row
			var col := i % units_per_row
			var spawn_pos := Vector3(
				base_X + col * spacing,
				0.0,
				base_Z + row * spacing
			)
			spawn_service.call("server_spawn", team_for_peer, spawn_pos)
		_mark_test("client_joined", true, "peer="+str(peer_id))

func _sync_existing_units_to_peer(peer_id: int) -> void:
	for child in get_tree().get_nodes_in_group("selectable_units"):
		if not child.name.begins_with("unit_"):
			continue
		if not child.has_method("set_move_target"):
			continue
		spawn_service.call("sync_unit_to_peer", peer_id, child.name, int(child.get("team_id")), child.global_position)

func _on_peer_left(peer_id: int) -> void:
	print("PvP: peer left: " + str(peer_id))
	_mark_test("disconnect_stable", true, "peer="+str(peer_id))

func _on_connected(address: String, port: int) -> void:
	print("PvP: connected to: ", address, ":", str(port))
	_retry_attempts = 0
	_mark_test("rejoin_ok", true, "retry_attempts="+str(_retry_attempts))

func _on_connection_failed(reason: String) -> void:
	retry_connection()
	print("PvP: connection failed: ", reason)

func _on_disconnected() -> void:
	print("PvP: disconnected")

## Copilot SUggestion fuer Move Request fuer Host- und Client-Unitbewegung
@rpc("any_peer", "reliable")
func request_move_command(commands: Array) -> void:
	if not multiplayer.is_server():
		return
		
	var sender_id := multiplayer.get_remote_sender_id()
	var sanitized := _sanitize_move_commands(sender_id, commands)
	if sanitized.is_empty():
		return
	
	rpc("_rpc_apply_move_command", sanitized)
	print("movement::", str(sender_id))

func _count_spawned_units() -> int:
	return get_tree().get_nodes_in_group("selectable_units").size()

@rpc("authority", "call_local", "reliable")
func _rpc_apply_move_command(commands: Array) -> void:
	for cmd in commands:
		var unit_name: String = cmd.get("unit_name", "")
		var target: Vector3 = cmd.get("target", Vector3.ZERO)
		if unit_name.is_empty():
			continue
		
		var unit := _find_unit_by_name(unit_name)
		if unit == null:
			continue
		if not unit.has_method("set_move_target"):
			continue
		
		unit.set_move_target(target)
	_mark_test("move_sync", true, "commands="+str(commands.size()))

func _sanitize_move_commands(_sender_id: int, commands: Array) -> Array:
	var result: Array = []
	
	for cmd in commands:
		if typeof(cmd) != TYPE_DICTIONARY:
			continue
	
		var unit_name: String = cmd.get("unit_name", "")
		var target: Vector3 = cmd.get("target", Vector3.ZERO)
	
		if unit_name.is_empty():
			continue
		if abs(target.x) > 10000.0 or abs(target.z) > 10000.0:
			continue
	
		var unit := _find_unit_by_name(unit_name)
		if unit == null:
			continue
	
		# Optional: Ownership-Regel (vorerst nur host streng erzwingen)
		# if not _can_control_unit(sender_id, unit):
		#     continue
		
		result.append({
			"unit_name": unit_name,
			"target": target
		})
		
	return result

func retry_connection() -> void:
	if _retry_attempts >= MAX_RETRIES:
		push_warning("PVP: retry limit reached")
		return
	_retry_attempts += 1
	
	if is_host_mode:
		var err := network_manager.host_game(target_port)
		if err != OK:
			push_warning("PVP: retry host failed: " + str(err))
		
	else:
		var err := network_manager.join_game(target_address, target_port)
		if err != OK:
			push_warning("PVP: retry join failed: " + str(err))

#### TEST ####

func _mark_test(testname: String, passed: bool, details: String = "") -> void:
	if _test.has(testname):
		_test[testname] = passed
	test_checkpoint.emit(testname, passed, details)
	print("TEST::", testname, " => ", passed, " : ", details)

func test_summary() -> Dictionary:
	return _test.duplicate(true)

func _sample_unit_positions() -> Dictionary:
	var result := {}
	for child in get_tree().get_nodes_in_group("selectable_units"):
		result[child.name] = child.global_position
	return result

func _find_unit_by_name(unit_name: String) -> Node:
	if world_node == null:
		return null
	return world_node.find_child(unit_name, true, false)

func _check_spawn_sync_minimum(min_units: int = 2) -> void:
	var count := _count_spawned_units()
	_mark_test("spawn_sync", count >= min_units, "count=" + str(count))

#### Spawn Units ####

func _spawn_init_for_host() -> void:
	if spawn_service == null or not is_instance_valid(spawn_service):
		return
	var host_team := 0
	var units_per_row := 4
	var spacing := 2.5
	var base_X := -12.0
	var base_Z := -8.0
	
	for i in range(10):
		var row := i / units_per_row
		var col := i % units_per_row
		var spawn_pos := Vector3(
			base_X + col * spacing,
			0.0,
			base_Z + row * spacing
		)
		spawn_service.call("server_spawn", host_team, spawn_pos)
		
