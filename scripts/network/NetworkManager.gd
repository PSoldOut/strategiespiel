extends Node

signal status_changed(message: String)
signal spawn_player_requested(peer_id: int, slot: int, color: Color)
signal reinforcements_requested(peer_id: int, count: int)
signal clear_players_requested
signal peer_left(peer_id: int)
signal match_started_changed(started: bool)
signal pause_state_changed(paused: bool)

const MAX_PLAYERS: int = 4
const DEFAULT_PORT: int = 4242
const PLAYER_COLORS: Array[Color] = [
	Color(0.18, 0.58, 0.98, 1.0),
	Color(0.98, 0.42, 0.18, 1.0),
	Color(0.23, 0.78, 0.35, 1.0),
	Color(0.95, 0.84, 0.2, 1.0)
]

var _match_started: bool = false
var _game_paused: bool = false
var _packets_sent: int = 0
var _packets_received: int = 0
var _ping_ms: float = 0.0
var _ping_timer: float = 0.0
var _last_error_code: int = OK
var _active_port: int = DEFAULT_PORT
var _last_join_address: String = ""


func _ready() -> void:
	_connect_multiplayer_signals()


func process_tick(delta: float) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server() and _match_started:
		_ping_timer += delta
		if _ping_timer >= 1.0:
			_ping_timer = 0.0
			var sent_msec := Time.get_ticks_msec()
			register_network_packet_sent(1)
			rpc_id(1, "_rpc_ping_request", sent_msec)


func get_default_port() -> int:
	return DEFAULT_PORT


func is_host() -> bool:
	return multiplayer.has_multiplayer_peer() and multiplayer.is_server()


func has_peer() -> bool:
	return multiplayer.has_multiplayer_peer()


func is_match_started() -> bool:
	return _match_started


func is_game_paused() -> bool:
	return _game_paused


func get_ping_ms() -> float:
	return _ping_ms


func get_packets_sent() -> int:
	return _packets_sent


func get_packets_received() -> int:
	return _packets_received


func get_last_error_code() -> int:
	return _last_error_code


func get_last_error_name() -> String:
	return error_string(_last_error_code)


func get_local_ipv4_addresses() -> Array[String]:
	var result: Array[String] = []
	for addr in IP.get_local_addresses():
		if addr == "127.0.0.1":
			continue
		if addr.contains(":"):
			continue
		result.append(addr)
	return result


func get_connection_diagnostics() -> Dictionary:
	var peer_active := multiplayer.has_multiplayer_peer()
	return {
		"has_peer": peer_active,
		"is_host": is_host(),
		"unique_id": multiplayer.get_unique_id() if peer_active else 0,
		"peer_count": multiplayer.get_peers().size() if peer_active else 0,
		"active_port": _active_port,
		"last_join_address": _last_join_address,
		"last_error_code": _last_error_code,
		"last_error_name": error_string(_last_error_code),
		"local_ipv4": get_local_ipv4_addresses()
	}


func host_game(port: int) -> void:
	disconnect_game(false)
	_active_port = port
	_last_join_address = ""
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		_last_error_code = err
		_emit_status("Host fehlgeschlagen (Code %d - %s)" % [err, error_string(err)])
		return
	_last_error_code = OK
	multiplayer.multiplayer_peer = peer
	_match_started = false
	_set_pause_state(false)
	_emit_status("Host aktiv auf Port %d. Warte auf Spieler..." % port)
	match_started_changed.emit(_match_started)


func join_game(address: String, port: int) -> void:
	disconnect_game(false)
	_active_port = port
	_last_join_address = address
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		_last_error_code = err
		_emit_status("Join fehlgeschlagen (Code %d - %s)" % [err, error_string(err)])
		return
	_last_error_code = OK
	multiplayer.multiplayer_peer = peer
	_match_started = false
	_set_pause_state(false)
	_emit_status("Verbinde zu %s:%d ..." % [address, port])
	match_started_changed.emit(_match_started)


func disconnect_game(show_status: bool = true) -> void:
	if multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	clear_players_requested.emit()
	_match_started = false
	_set_pause_state(false)
	_ping_ms = 0.0
	_ping_timer = 0.0
	match_started_changed.emit(_match_started)
	if show_status:
		_emit_status("Verbindung getrennt.")


func start_match_as_host() -> void:
	if not multiplayer.is_server():
		_emit_status("Nur der Host kann starten.")
		return
	var peers: Array[int] = [multiplayer.get_unique_id()]
	for id in multiplayer.get_peers():
		peers.append(id)
	peers.sort()
	if peers.size() > MAX_PLAYERS:
		peers = peers.slice(0, MAX_PLAYERS)

	clear_players_requested.emit()
	for i in range(peers.size()):
		var peer_id := peers[i]
		var color := PLAYER_COLORS[i % PLAYER_COLORS.size()]
		spawn_player_requested.emit(peer_id, i, color)
		register_network_packet_sent(1)
		rpc("_rpc_spawn_player", peer_id, i, color)

	_match_started = true
	_set_pause_state(false)
	match_started_changed.emit(_match_started)
	register_network_packet_sent(1)
	rpc("_rpc_set_match_started", true)
	_emit_status("Match gestartet mit %d Spielern." % peers.size())


func host_restart_match() -> void:
	if not multiplayer.is_server():
		return
	start_match_as_host()
	register_network_packet_sent(1)
	rpc("_rpc_restart_notice")
	_emit_status("Host hat das Spiel neugestartet.")


func request_pause_toggle() -> void:
	if not multiplayer.has_multiplayer_peer():
		_set_pause_state(not _game_paused)
		return
	if multiplayer.is_server():
		_set_pause_state(not _game_paused)
		register_network_packet_sent(1)
		rpc("_rpc_set_pause_state", _game_paused)
	else:
		register_network_packet_sent(1)
		rpc_id(1, "_rpc_request_pause_toggle")


func request_reinforcements(count: int = 3) -> void:
	if not multiplayer.has_multiplayer_peer():
		reinforcements_requested.emit(1, count)
		return
	if multiplayer.is_server():
		_process_reinforcement_request(multiplayer.get_unique_id(), count)
		return
	register_network_packet_sent(1)
	rpc_id(1, "_rpc_request_reinforcements", count)


func register_network_packet_sent(count: int = 1) -> void:
	_packets_sent += count


func register_network_packet_received(count: int = 1) -> void:
	_packets_received += count


func _connect_multiplayer_signals() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func _on_peer_connected(id: int) -> void:
	if not multiplayer.is_server():
		return
	var peer_count := multiplayer.get_peers().size() + 1
	if peer_count > MAX_PLAYERS:
		(multiplayer.multiplayer_peer as ENetMultiplayerPeer).disconnect_peer(id, true)
		return
	_emit_status("Spieler %d beigetreten (%d/%d)." % [id, peer_count, MAX_PLAYERS])
	if _match_started:
		(multiplayer.multiplayer_peer as ENetMultiplayerPeer).disconnect_peer(id, true)
		_emit_status("Spiel laeuft bereits. Beitritt abgelehnt.")


func _on_peer_disconnected(id: int) -> void:
	peer_left.emit(id)
	_emit_status("Spieler %d getrennt." % id)


func _on_connected_to_server() -> void:
	_last_error_code = OK
	_emit_status("Mit Host verbunden. Warte auf Start...")


func _on_connection_failed() -> void:
	_last_error_code = ERR_CANT_CONNECT
	_emit_status("Verbindung fehlgeschlagen (Code %d - %s)." % [_last_error_code, error_string(_last_error_code)])
	disconnect_game(false)


func _on_server_disconnected() -> void:
	_last_error_code = ERR_CONNECTION_ERROR
	_emit_status("Host-Verbindung verloren (Code %d - %s)." % [_last_error_code, error_string(_last_error_code)])
	disconnect_game(false)


@rpc("authority", "reliable")
func _rpc_spawn_player(peer_id: int, slot: int, color: Color) -> void:
	register_network_packet_received(1)
	spawn_player_requested.emit(peer_id, slot, color)


@rpc("authority", "reliable")
func _rpc_set_match_started(started: bool) -> void:
	register_network_packet_received(1)
	_match_started = started
	if not started:
		clear_players_requested.emit()
	match_started_changed.emit(_match_started)


@rpc("authority", "reliable")
func _rpc_restart_notice() -> void:
	register_network_packet_received(1)
	_emit_status("Host hat die Runde neugestartet.")


@rpc("any_peer", "reliable")
func _rpc_request_pause_toggle() -> void:
	register_network_packet_received(1)
	if not multiplayer.is_server():
		return
	_set_pause_state(not _game_paused)
	register_network_packet_sent(1)
	rpc("_rpc_set_pause_state", _game_paused)


@rpc("any_peer", "reliable")
func _rpc_request_reinforcements(count: int) -> void:
	register_network_packet_received(1)
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	_process_reinforcement_request(sender, count)


@rpc("authority", "reliable")
func _rpc_set_pause_state(value: bool) -> void:
	register_network_packet_received(1)
	_set_pause_state(value)


func _process_reinforcement_request(peer_id: int, count: int) -> void:
	reinforcements_requested.emit(peer_id, count)
	if not multiplayer.has_multiplayer_peer():
		return
	for id in multiplayer.get_peers():
		register_network_packet_sent(1)
		rpc_id(id, "_rpc_apply_reinforcements", peer_id, count)


@rpc("authority", "reliable")
func _rpc_apply_reinforcements(peer_id: int, count: int) -> void:
	register_network_packet_received(1)
	reinforcements_requested.emit(peer_id, count)


@rpc("any_peer", "unreliable")
func _rpc_ping_request(client_sent_msec: int) -> void:
	register_network_packet_received(1)
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	register_network_packet_sent(1)
	rpc_id(sender, "_rpc_ping_response", client_sent_msec)


@rpc("authority", "unreliable")
func _rpc_ping_response(client_sent_msec: int) -> void:
	register_network_packet_received(1)
	_ping_ms = float(Time.get_ticks_msec() - client_sent_msec)


func _set_pause_state(value: bool) -> void:
	_game_paused = value
	pause_state_changed.emit(_game_paused)
	_emit_status("Spiel pausiert." if _game_paused else "Spiel fortgesetzt.")


func _emit_status(message: String) -> void:
	status_changed.emit(message)
