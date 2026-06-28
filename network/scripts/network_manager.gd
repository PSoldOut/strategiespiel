class_name NetworkManager extends Node

signal hosting_started(port: int)
signal connected_to_server(address: String, port: int)
signal connection_failed(reason: String)
signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)
signal disconnected()
signal state_changed(state: ENUM_NETWORK_STATE, reason: String)
signal lobby_updated(players: Array)
signal local_ready_changed(is_ready: bool)
signal game_start_authorized()
signal lobby_message(message: String)

const DEFAULT_PORT: int = 24570
const DEFAULT_MAX_CLIENTS: int = 32
const PING_INTERVAL_SECONDS: float = 2.0
const UNKNOWN_PING: int = -1

var is_host: bool = false
var server_address: String = "127.0.0.1"
var server_port: int = DEFAULT_PORT
var local_player_name: String = ""

var state: ENUM_NETWORK_STATE = ENUM_NETWORK_STATE.IDLE
var last_error: String = ""
var _players: Dictionary = {}
var _pending_ping: Dictionary = {}
var _ping_nonce: int = 0
var _ping_timer: Timer

enum ENUM_NETWORK_STATE {
	IDLE, HOSTING, CONNECTING, CONNECTED, FAILED
}

## TODO: Liste an Default-Names mit Anlehnung an Cowboy-Woertern in Verbindung

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	_ping_timer = Timer.new()
	_ping_timer.one_shot = false
	_ping_timer.wait_time = PING_INTERVAL_SECONDS
	_ping_timer.autostart = false
	add_child(_ping_timer)
	_ping_timer.timeout.connect(_on_ping_timer_timeout)

func enter_lobby(as_host: bool, address: String, port: int, player_name: String) -> Error:
	local_player_name = _sanitize_player_name(player_name)
	if local_player_name.is_empty():
		local_player_name = _default_player_name()

	if as_host:
		var host_err := host_game(port)
		if host_err != OK:
			return host_err
		_register_host_player(local_player_name)
		return OK

	return join_game(address, port)

func get_lobby_players() -> Array:
	return _sorted_players_snapshot()

func is_local_player_ready() -> bool:
	if multiplayer.multiplayer_peer == null:
		return false
	var local_id := multiplayer.get_unique_id()
	if not _players.has(local_id):
		return false
	return bool(_players[local_id].get("ready", false))

func set_local_ready(ready: bool) -> void:
	if multiplayer.multiplayer_peer == null:
		return

	if multiplayer.is_server():
		var local_id := multiplayer.get_unique_id()
		if _players.has(local_id):
			_players[local_id]["ready"] = ready
			_sync_lobby_to_all()
		return

	rpc_id(1, "_rpc_set_ready", ready)

func toggle_local_ready() -> void:
	set_local_ready(not is_local_player_ready())

func can_start_match() -> bool:
	return multiplayer.is_server() and _are_all_players_ready()

func request_start_match() -> void:
	if not multiplayer.is_server():
		return

	if not _are_all_players_ready():
		lobby_message.emit("Start blockiert: Nicht alle Spieler sind ready.")
		return

	rpc("_rpc_begin_match")

@rpc("authority", "call_local", "reliable")
func _rpc_begin_match() -> void:
	game_start_authorized.emit()

func host_game(port: int = DEFAULT_PORT, max_clients: int = DEFAULT_MAX_CLIENTS) -> Error:
	disconnect_game()
	
	_set_state(ENUM_NETWORK_STATE.CONNECTING)
	
	var peer:= ENetMultiplayerPeer.new()
	var err:= peer.create_server(port, max_clients)
	if err != OK:
		_set_state(ENUM_NETWORK_STATE.FAILED, "create_server failed: " + str(err))
		connection_failed.emit("create_server failed: " + str(err))
		return err 
	
	multiplayer.multiplayer_peer = peer
	is_host = true
	server_address = "127.0.0.1"
	server_port = port
	_pending_ping.clear()
	_ping_nonce = 0
	_start_ping_loop_if_needed()
	_set_state(ENUM_NETWORK_STATE.HOSTING)
	hosting_started.emit(port)
	return OK

func join_game(address: String, port: int = DEFAULT_PORT) -> Error:
	disconnect_game()
	_set_state(ENUM_NETWORK_STATE.CONNECTING)
	var peer := ENetMultiplayerPeer.new()
	
	var err := peer.create_client(address, port)
	if err != OK:
		_set_state(ENUM_NETWORK_STATE.FAILED, "create_client failed: " + str(err))
		connection_failed.emit("create_client failed: " + str(err))
		return err
	
	multiplayer.multiplayer_peer = peer
	is_host = false
	server_address = address
	server_port = port
	_pending_ping.clear()
	_ping_nonce = 0
	return OK

func disconnect_game() -> void:
	_stop_ping_loop()
	_pending_ping.clear()
	_players.clear()
	lobby_updated.emit([])
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	_set_state(ENUM_NETWORK_STATE.IDLE)
	disconnected.emit()

###SIGNALS###

func _on_peer_connected(peer_id: int) -> void:
	peer_joined.emit(peer_id)
	if multiplayer.is_server():
		_sync_lobby_to_all()

func _on_peer_disconnected(peer_id: int) -> void:
	if multiplayer.is_server() and _players.has(peer_id):
		_players.erase(peer_id)
		_sync_lobby_to_all()
	peer_left.emit(peer_id)

func _on_connected_to_server() -> void:
	state = ENUM_NETWORK_STATE.CONNECTED
	_start_ping_loop_if_needed()
	_register_local_player_on_server()
	connected_to_server.emit(server_address, server_port)

func _on_connection_failed() -> void:
	state = ENUM_NETWORK_STATE.FAILED
	_stop_ping_loop()
	connection_failed.emit("connection_failed")

func _on_server_disconnected() -> void:
	state = ENUM_NETWORK_STATE.IDLE
	_stop_ping_loop()
	_players.clear()
	lobby_updated.emit([])
	disconnected.emit()
#######

func _set_state(next_state: ENUM_NETWORK_STATE, reason: String = "") -> void:
	state = next_state
	if reason != "":
		last_error = reason
	state_changed.emit(state, reason)

func _register_host_player(player_name: String) -> void:
	if multiplayer.multiplayer_peer == null:
		return
	var local_id := multiplayer.get_unique_id()
	_players.clear()
	_players[local_id] = {
		"peer_id": local_id,
		"name": _sanitize_player_name(player_name),
		"ip": _guess_local_ip(),
		"ping_ms": 0,
		"ready": false,
		"is_host": true
	}
	_sync_lobby_to_all()

func _register_local_player_on_server() -> void:
	if multiplayer.multiplayer_peer == null:
		return
	if multiplayer.is_server():
		return
	rpc_id(1, "_rpc_register_player", local_player_name)

@rpc("any_peer", "reliable")
func _rpc_register_player(player_name: String) -> void:
	if not multiplayer.is_server():
		return

	var sender_id := multiplayer.get_remote_sender_id()
	_players[sender_id] = {
		"peer_id": sender_id,
		"name": _sanitize_player_name(player_name),
		"ip": _resolve_remote_ip(sender_id),
		"ping_ms": UNKNOWN_PING,
		"ready": false,
		"is_host": false
	}
	_sync_lobby_to_all()

@rpc("any_peer", "reliable")
func _rpc_set_ready(ready: bool) -> void:
	if not multiplayer.is_server():
		return

	var sender_id := multiplayer.get_remote_sender_id()
	if not _players.has(sender_id):
		return

	_players[sender_id]["ready"] = ready
	_sync_lobby_to_all()

func _sync_lobby_to_all() -> void:
	if multiplayer.multiplayer_peer == null:
		return
	if not multiplayer.is_server():
		return

	var snapshot := _sorted_players_snapshot()
	rpc("_rpc_sync_lobby", snapshot)

@rpc("authority", "call_local", "reliable")
func _rpc_sync_lobby(snapshot: Array) -> void:
	_players.clear()
	for entry in snapshot:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var peer_id := int(entry.get("peer_id", 0))
		if peer_id <= 0:
			continue
		_players[peer_id] = {
			"peer_id": peer_id,
			"name": str(entry.get("name", "Unknown")),
			"ip": str(entry.get("ip", "unknown")),
			"ping_ms": int(entry.get("ping_ms", UNKNOWN_PING)),
			"ready": bool(entry.get("ready", false)),
			"is_host": bool(entry.get("is_host", false))
		}
	lobby_updated.emit(_sorted_players_snapshot())
	local_ready_changed.emit(is_local_player_ready())

func _sorted_players_snapshot() -> Array:
	var ids: Array = _players.keys()
	ids.sort()
	var snapshot: Array = []
	for peer_id in ids:
		var info: Dictionary = _players[peer_id]
		snapshot.append({
			"peer_id": int(info.get("peer_id", peer_id)),
			"name": str(info.get("name", "Unknown")),
			"ip": str(info.get("ip", "unknown")),
			"ping_ms": int(info.get("ping_ms", UNKNOWN_PING)),
			"ready": bool(info.get("ready", false)),
			"is_host": bool(info.get("is_host", false))
		})
	return snapshot

func _are_all_players_ready() -> bool:
	if _players.is_empty():
		return false
	for peer_id in _players.keys():
		if not bool(_players[peer_id].get("ready", false)):
			return false
	return true

func _start_ping_loop_if_needed() -> void:
	if _ping_timer == null:
		return
	if multiplayer.multiplayer_peer == null:
		return
	if multiplayer.is_server():
		_ping_timer.stop()
		return
	_ping_timer.start()

func _stop_ping_loop() -> void:
	if _ping_timer != null:
		_ping_timer.stop()

func _on_ping_timer_timeout() -> void:
	if multiplayer.multiplayer_peer == null:
		return
	if multiplayer.is_server():
		return
	_ping_nonce += 1
	var nonce := _ping_nonce
	_pending_ping[nonce] = Time.get_ticks_msec()
	rpc_id(1, "_rpc_ping_request", nonce)

@rpc("any_peer", "unreliable")
func _rpc_ping_request(nonce: int) -> void:
	if not multiplayer.is_server():
		return
	rpc_id(multiplayer.get_remote_sender_id(), "_rpc_ping_response", nonce)

@rpc("any_peer", "unreliable")
func _rpc_ping_response(nonce: int) -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return
	if not _pending_ping.has(nonce):
		return
	var sent_at := int(_pending_ping[nonce])
	_pending_ping.erase(nonce)
	var rtt := maxi(0, Time.get_ticks_msec() - sent_at)
	rpc_id(1, "_rpc_report_ping", rtt)

@rpc("any_peer", "unreliable")
func _rpc_report_ping(rtt_ms: int) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if not _players.has(sender_id):
		return
	_players[sender_id]["ping_ms"] = clampi(rtt_ms, 0, 9999)
	_sync_lobby_to_all()

func _resolve_remote_ip(peer_id: int) -> String:
	if multiplayer.multiplayer_peer == null:
		return "unknown"
	if not (multiplayer.multiplayer_peer is ENetMultiplayerPeer):
		return "unknown"
	var enet_peer := (multiplayer.multiplayer_peer as ENetMultiplayerPeer).get_peer(peer_id)
	if enet_peer == null:
		return "unknown"
	if enet_peer.has_method("get_remote_address"):
		var addr := str(enet_peer.call("get_remote_address"))
		if not addr.is_empty():
			return addr
	return "unknown"

func _guess_local_ip() -> String:
	for addr in IP.get_local_addresses():
		if not addr.contains("."):
			continue
		if addr.begins_with("127."):
			continue
		return addr
	return "127.0.0.1"

func _sanitize_player_name(raw_name: String) -> String:
	var trimmed := raw_name.strip_edges()
	if trimmed.is_empty():
		return ""
	if trimmed.length() > 20:
		return trimmed.substr(0, 20)
	return trimmed

func _default_player_name() -> String:
	var env_name := OS.get_environment("USERNAME").strip_edges()
	if env_name.is_empty():
		env_name = "Player"
	return _sanitize_player_name(env_name)
