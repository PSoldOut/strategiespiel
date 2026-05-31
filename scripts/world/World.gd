extends Node3D

const SPAWN_POINTS: Array[Vector3] = [
Vector3(-24.0, 1.0, -24.0),
Vector3(24.0, 1.0, -24.0),
Vector3(-24.0, 1.0, 24.0),
Vector3(24.0, 1.0, 24.0)
]

var agent_scene: PackedScene = preload("res://scenes/core/Agent.tscn")
var network_manager_script: Script = preload("res://scripts/network/NetworkManager.gd")

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D
@onready var agents_root: Node3D = $Agents
@onready var drag_selection: Control = $DragSelection
@onready var rts_camera: Camera3D = $RTSCamera
@onready var respawn_points_root: Node3D = $RespawnPoints

var _ui_visible: bool = true
var _player_nodes: Dictionary = {}
var _peer_slots: Dictionary = {}
var _peer_respawn_points: Dictionary = {}
var _peer_reinforcement_counters: Dictionary = {}
var _network_manager: Node

var _network_ui_layer: CanvasLayer
var _network_panel: PanelContainer
var _status_label: Label
var _local_ip_label: Label
var _ip_input: LineEdit
var _port_input: SpinBox
var _host_button: Button
var _join_button: Button
var _disconnect_button: Button
var _start_button: Button
var _pause_button: Button
var _restart_button: Button
var _reinforce_button: Button
var _self_test_button: Button
var _diagnostic_label: Label
var _stats_label: Label
var _benchmark_label: Label
var _benchmark_batch_input: SpinBox
var _benchmark_interval_input: SpinBox
var _benchmark_auto_button: Button
var _benchmark_reset_button: Button
var _benchmark_check_button: Button

var _benchmark_total_created: int = 0
var _benchmark_current_units: int = 0
var _benchmark_peak_units: int = 0
var _benchmark_runtime_sec: float = 0.0
var _benchmark_min_fps: float = INF
var _benchmark_fps_sum: float = 0.0
var _benchmark_fps_samples: int = 0
var _benchmark_auto_spawn_enabled: bool = false
var _benchmark_auto_spawn_timer: float = 0.0
var _benchmark_created_per_peer: Dictionary = {}
var _slot_respawn_points: Array[Vector3] = []


func _ready() -> void:
	add_to_group("world_root")
	_collect_respawn_points_from_scene()
	nav_region.bake_navigation_mesh()
	_setup_network_manager()
	_create_ui()
	_reset_benchmark_metrics()
	_refresh_local_ip_info()
	_update_role_actions()
	_set_status("Offline. F1 blendet das Multiplayer-Panel ein/aus.")


func _process(delta: float) -> void:
	if _network_manager and _network_manager.has_method("process_tick"):
		_network_manager.process_tick(delta)
	_process_benchmark(delta)
	_update_stats()


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed:
		return
	match event.keycode:
		KEY_F1:
			_toggle_network_panel()
		KEY_P:
			if _network_manager:
				_network_manager.request_pause_toggle()
		KEY_F5:
			if _network_manager and _network_manager.is_host():
				_network_manager.host_restart_match()
		KEY_N:
			_on_reinforce_pressed()


func _on_drag_selection_move_command(positions: Array) -> void:
	for i in range(drag_selection.current_selected.size()):
		var unit = drag_selection.current_selected[i]
		var controlled_unit: Node3D = unit.get_unit()
		if not controlled_unit.is_multiplayer_authority():
			continue
		if controlled_unit.has_method("issue_move_order"):
			controlled_unit.issue_move_order(positions[i])


func _on_drag_selection_interact_command(target) -> void:
	for i in range(drag_selection.current_selected.size()):
		var unit = drag_selection.current_selected[i]
		var controlled_unit: Node3D = unit.get_unit()
		if not controlled_unit.is_multiplayer_authority():
			continue
		if controlled_unit.has_method("issue_attack_order"):
			controlled_unit.issue_attack_order(target.get_unit())


func _setup_network_manager() -> void:
	_network_manager = network_manager_script.new()
	_network_manager.name = "NetworkManager"
	add_child(_network_manager)
	_network_manager.status_changed.connect(_on_network_status_changed)
	_network_manager.spawn_player_requested.connect(_on_network_spawn_player)
	_network_manager.reinforcements_requested.connect(_on_network_reinforcements_requested)
	_network_manager.clear_players_requested.connect(_on_network_clear_players)
	_network_manager.peer_left.connect(_on_network_peer_left)
	_network_manager.match_started_changed.connect(_on_network_match_started_changed)
	_network_manager.pause_state_changed.connect(_on_network_pause_state_changed)


func _create_ui() -> void:
	_network_ui_layer = CanvasLayer.new()
	_network_ui_layer.name = "MultiplayerUI"
	add_child(_network_ui_layer)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.scale = Vector2(0.5, 0.5)
	_network_ui_layer.add_child(root)

	_network_panel = PanelContainer.new()
	_network_panel.anchor_left = 0.02
	_network_panel.anchor_top = 0.03
	_network_panel.anchor_right = 0.38
	_network_panel.anchor_bottom = 0.58
	root.add_child(_network_panel)

	var panel_vbox := VBoxContainer.new()
	panel_vbox.add_theme_constant_override("separation", 8)
	_network_panel.add_child(panel_vbox)

	var title := Label.new()
	title.text = "Multiplayer"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	panel_vbox.add_child(title)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel_vbox.add_child(_status_label)

	_local_ip_label = Label.new()
	_local_ip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel_vbox.add_child(_local_ip_label)

	var ip_row := HBoxContainer.new()
	panel_vbox.add_child(ip_row)
	var ip_label := Label.new()
	ip_label.text = "IP"
	ip_row.add_child(ip_label)
	_ip_input = LineEdit.new()
	_ip_input.text = "127.0.0.1"
	_ip_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ip_row.add_child(_ip_input)

	var port_row := HBoxContainer.new()
	panel_vbox.add_child(port_row)
	var port_label := Label.new()
	port_label.text = "Port"
	port_row.add_child(port_label)
	_port_input = SpinBox.new()
	_port_input.min_value = 1000
	_port_input.max_value = 65535
	_port_input.step = 1
	_port_input.value = _network_manager.get_default_port()
	_port_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	port_row.add_child(_port_input)

	var button_row := HBoxContainer.new()
	panel_vbox.add_child(button_row)
	_host_button = Button.new()
	_host_button.text = "Host"
	_host_button.pressed.connect(_on_host_pressed)
	button_row.add_child(_host_button)
	_join_button = Button.new()
	_join_button.text = "Join"
	_join_button.pressed.connect(_on_join_pressed)
	button_row.add_child(_join_button)
	_disconnect_button = Button.new()
	_disconnect_button.text = "Disconnect"
	_disconnect_button.pressed.connect(_on_disconnect_pressed)
	button_row.add_child(_disconnect_button)

	_start_button = Button.new()
	_start_button.text = "Spiel Starten (Host)"
	_start_button.pressed.connect(_on_start_pressed)
	panel_vbox.add_child(_start_button)

	_pause_button = Button.new()
	_pause_button.text = "Pause / Fortsetzen (Alle)"
	_pause_button.pressed.connect(_on_pause_pressed)
	panel_vbox.add_child(_pause_button)

	_restart_button = Button.new()
	_restart_button.text = "Neustart (Host)"
	_restart_button.pressed.connect(_on_restart_pressed)
	panel_vbox.add_child(_restart_button)

	_reinforce_button = Button.new()
	_reinforce_button.text = "Batch erzeugen"
	_reinforce_button.pressed.connect(_on_reinforce_pressed)
	panel_vbox.add_child(_reinforce_button)

	var benchmark_title := Label.new()
	benchmark_title.text = "Benchmark"
	benchmark_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	benchmark_title.add_theme_font_size_override("font_size", 18)
	panel_vbox.add_child(benchmark_title)

	var benchmark_batch_row := HBoxContainer.new()
	panel_vbox.add_child(benchmark_batch_row)
	var benchmark_batch_label := Label.new()
	benchmark_batch_label.text = "Batch"
	benchmark_batch_row.add_child(benchmark_batch_label)
	_benchmark_batch_input = SpinBox.new()
	_benchmark_batch_input.min_value = 1
	_benchmark_batch_input.max_value = 500
	_benchmark_batch_input.step = 1
	_benchmark_batch_input.value = 10
	_benchmark_batch_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	benchmark_batch_row.add_child(_benchmark_batch_input)

	var benchmark_interval_row := HBoxContainer.new()
	panel_vbox.add_child(benchmark_interval_row)
	var benchmark_interval_label := Label.new()
	benchmark_interval_label.text = "Auto s"
	benchmark_interval_row.add_child(benchmark_interval_label)
	_benchmark_interval_input = SpinBox.new()
	_benchmark_interval_input.min_value = 0.1
	_benchmark_interval_input.max_value = 10.0
	_benchmark_interval_input.step = 0.1
	_benchmark_interval_input.value = 0.5
	_benchmark_interval_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	benchmark_interval_row.add_child(_benchmark_interval_input)

	var benchmark_button_row := HBoxContainer.new()
	panel_vbox.add_child(benchmark_button_row)
	_benchmark_auto_button = Button.new()
	_benchmark_auto_button.text = "Auto-Spawn: AUS"
	_benchmark_auto_button.pressed.connect(_on_benchmark_auto_pressed)
	benchmark_button_row.add_child(_benchmark_auto_button)
	_benchmark_reset_button = Button.new()
	_benchmark_reset_button.text = "Benchmark-Reset"
	_benchmark_reset_button.pressed.connect(_on_benchmark_reset_pressed)
	benchmark_button_row.add_child(_benchmark_reset_button)
	_benchmark_check_button = Button.new()
	_benchmark_check_button.text = "Host/Client-Check"
	_benchmark_check_button.pressed.connect(_on_benchmark_check_pressed)
	benchmark_button_row.add_child(_benchmark_check_button)

	_benchmark_label = Label.new()
	_benchmark_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_benchmark_label.text = "Benchmark: bereit"
	panel_vbox.add_child(_benchmark_label)

	_self_test_button = Button.new()
	_self_test_button.text = "Netzwerk-Selbsttest"
	_self_test_button.pressed.connect(_on_self_test_pressed)
	panel_vbox.add_child(_self_test_button)

	_diagnostic_label = Label.new()
	_diagnostic_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_diagnostic_label.text = "Diagnose: nicht ausgefuehrt"
	panel_vbox.add_child(_diagnostic_label)

	var help := Label.new()
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.text = "RTS-Steuerung: Einheiten auswaehlen und mit Rechtsklick bewegen/angreifen\nUI ein/aus: F1 | Pause/Fortsetzen: P | Host-Neustart: F5"
	panel_vbox.add_child(help)

	var stats_panel := PanelContainer.new()
	stats_panel.anchor_left = 0.79
	stats_panel.anchor_top = 0.03
	stats_panel.anchor_right = 0.98
	stats_panel.anchor_bottom = 0.25
	root.add_child(stats_panel)

	_stats_label = Label.new()
	_stats_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_stats_label.text = "FPS: 0\nPing: -\nGesendet: 0\nEmpfangen: 0"
	stats_panel.add_child(_stats_label)


func _toggle_network_panel() -> void:
	_ui_visible = not _ui_visible
	if _network_panel:
		_network_panel.visible = _ui_visible


func _on_host_pressed() -> void:
	_network_manager.host_game(int(_port_input.value))
	_refresh_local_ip_info()
	_update_role_actions()


func _on_join_pressed() -> void:
	_network_manager.join_game(_ip_input.text.strip_edges(), int(_port_input.value))
	_update_role_actions()


func _on_disconnect_pressed() -> void:
	_network_manager.disconnect_game()
	_update_role_actions()


func _on_start_pressed() -> void:
	_network_manager.start_match_as_host()
	_update_role_actions()


func _on_pause_pressed() -> void:
	_network_manager.request_pause_toggle()


func _on_restart_pressed() -> void:
	_network_manager.host_restart_match()
	_update_role_actions()


func _on_reinforce_pressed() -> void:
	var count := int(_benchmark_batch_input.value) if _benchmark_batch_input else 3
	_spawn_reinforcements_for_local_peer(max(1, count))


func _on_benchmark_auto_pressed() -> void:
	if _benchmark_auto_spawn_enabled:
		_benchmark_auto_spawn_enabled = false
		_benchmark_auto_spawn_timer = 0.0
		_update_benchmark_ui()
		return

	if _network_manager and _network_manager.has_peer() and not _network_manager.is_host():
		_set_status("Auto-Spawn ist nur fuer Offline oder Host aktiviert.")
		return

	_benchmark_auto_spawn_enabled = true
	_benchmark_auto_spawn_timer = 0.0
	_update_benchmark_ui()


func _on_benchmark_reset_pressed() -> void:
	_reset_benchmark_metrics()


func _on_benchmark_check_pressed() -> void:
	if _diagnostic_label == null:
		return
	_diagnostic_label.text = _build_benchmark_check_report()


func _on_network_status_changed(message: String) -> void:
	_set_status(message)
	_run_self_test()


func _on_network_spawn_player(peer_id: int, slot: int, color: Color) -> void:
	_spawn_player_for_peer(peer_id, slot, color)


func _on_network_reinforcements_requested(peer_id: int, count: int) -> void:
	_spawn_reinforcements_for_peer(peer_id, count)


func _on_network_clear_players() -> void:
	_clear_players()


func _on_network_peer_left(peer_id: int) -> void:
	_remove_units_for_peer(peer_id)
	_refresh_drag_selection_units()


func _on_network_match_started_changed(_started: bool) -> void:
	_update_role_actions()


func _on_network_pause_state_changed(paused: bool) -> void:
	Engine.time_scale = 0.0 if paused else 1.0


func _spawn_player_for_peer(peer_id: int, slot: int, color: Color) -> void:
	_remove_units_for_peer(peer_id)
	_peer_slots[peer_id] = slot
	_peer_respawn_points[peer_id] = _get_slot_respawn_point(slot)

	var agent := agent_scene.instantiate()
	agent.name = "Player_%d" % peer_id
	agents_root.add_child(agent)
	agent.global_position = _peer_respawn_points[peer_id]
	if agent.has_method("configure_player"):
		agent.configure_player(peer_id, slot, color)
	_register_units_created(peer_id, 1)
	_player_nodes[peer_id] = agent
	if peer_id == multiplayer.get_unique_id():
		drag_selection.team = agent.team
	_refresh_drag_selection_units()

	if peer_id == multiplayer.get_unique_id():
		rts_camera.global_position = agent.global_position + Vector3(0.0, 18.0, 0.0)


func _clear_players() -> void:
	for child in agents_root.get_children():
		if is_instance_valid(child) and not child.is_queued_for_deletion():
			child.queue_free()
	_player_nodes.clear()
	_peer_slots.clear()
	_peer_respawn_points.clear()
	_peer_reinforcement_counters.clear()
	drag_selection.team = ""
	_refresh_drag_selection_units()
	_update_benchmark_counts()


func _remove_units_for_peer(peer_id: int) -> void:
	for child in agents_root.get_children():
		if not is_instance_valid(child):
			continue
		if child.is_queued_for_deletion():
			continue
		if child is RTSAgent and child.owner_peer_id == peer_id:
			child.queue_free()
	if _player_nodes.has(peer_id):
		_player_nodes.erase(peer_id)
	if _peer_slots.has(peer_id):
		_peer_slots.erase(peer_id)
	if _peer_respawn_points.has(peer_id):
		_peer_respawn_points.erase(peer_id)
	if _peer_reinforcement_counters.has(peer_id):
		_peer_reinforcement_counters.erase(peer_id)
	_update_benchmark_counts()


func _spawn_reinforcements_for_local_peer(count: int) -> void:
	var local_peer_id := multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	if _network_manager and _network_manager.has_method("request_reinforcements"):
		_network_manager.request_reinforcements(count)
		return
	_spawn_reinforcements_for_peer(local_peer_id, count)


func _spawn_reinforcements_for_peer(peer_id: int, count: int) -> void:
	var color := _get_peer_color(peer_id)
	var base_position := _get_peer_base_position(peer_id)
	var slot := int(_peer_slots.get(peer_id, 0))
	var start_index := int(_peer_reinforcement_counters.get(peer_id, 0))
	for i in range(count):
		var reinforcement_index := start_index + i
		var agent := agent_scene.instantiate()
		agent.name = "Reinforcement_%d_%d" % [peer_id, reinforcement_index]
		agents_root.add_child(agent)
		agent.global_position = base_position + _get_reinforcement_offset(reinforcement_index)
		if agent.has_method("configure_player"):
			agent.configure_player(peer_id, slot, color)
	_register_units_created(peer_id, count)
	_peer_reinforcement_counters[peer_id] = start_index + count
	_refresh_drag_selection_units()


func _get_reinforcement_offset(index: int) -> Vector3:
	# Deterministic spawn offsets keep names/paths and placement identical on all peers.
	var ring := int(index / 8)
	var slot := index % 8
	var radius := 3.0 + float(ring) * 2.5
	var angle := TAU * float(slot) / 8.0
	return Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)


func _get_peer_color(peer_id: int) -> Color:
	if _player_nodes.has(peer_id):
		var node = _player_nodes.get(peer_id)
		if is_instance_valid(node) and node.has_method("get_player_color"):
			return node.get_player_color()
	return Color(0.2, 0.5, 1.0, 1.0)


func _get_peer_base_position(peer_id: int) -> Vector3:
	if _peer_respawn_points.has(peer_id):
		return _peer_respawn_points[peer_id]

	if _peer_slots.has(peer_id):
		return _get_slot_respawn_point(int(_peer_slots[peer_id]))

	var fallback_index: int = int(absi(peer_id) % SPAWN_POINTS.size())
	return _get_slot_respawn_point(fallback_index)


func _collect_respawn_points_from_scene() -> void:
	_slot_respawn_points.clear()
	if respawn_points_root == null:
		for point in SPAWN_POINTS:
			_slot_respawn_points.append(point)
		return

	var markers: Array[Node3D] = []
	for child in respawn_points_root.get_children():
		if child is Node3D:
			markers.append(child)

	markers.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return a.name.naturalnocasecmp_to(b.name) < 0
	)

	for marker in markers:
		_slot_respawn_points.append(marker.global_position)

	if _slot_respawn_points.is_empty():
		for point in SPAWN_POINTS:
			_slot_respawn_points.append(point)


func _get_slot_respawn_point(slot: int) -> Vector3:
	if _slot_respawn_points.is_empty():
		return SPAWN_POINTS[slot % SPAWN_POINTS.size()]
	return _slot_respawn_points[slot % _slot_respawn_points.size()]


func _build_benchmark_check_report() -> String:
	var lines: PackedStringArray = []
	lines.append("Benchmark-Check")
	lines.append("1) Host starten, 2) Client verbinden, 3) Match starten, 4) Auto-Spawn aktivieren")

	var peer_active: bool = false
	var host_active: bool = false
	if _network_manager != null:
		peer_active = _network_manager.has_peer()
		host_active = _network_manager.is_host()
	lines.append("Verbindung aktiv: %s" % ("Ja" if peer_active else "Nein"))
	lines.append("Host: %s" % ("Ja" if host_active else "Nein"))
	lines.append("Peers in Session: %d" % _player_nodes.size())
	lines.append("Einheiten aktiv: %d | Peak: %d" % [_benchmark_current_units, _benchmark_peak_units])

	var avg_fps := 0.0
	if _benchmark_fps_samples > 0:
		avg_fps = _benchmark_fps_sum / float(_benchmark_fps_samples)
	var min_fps_text := "-"
	if _benchmark_fps_samples > 0 and _benchmark_min_fps < INF:
		min_fps_text = "%.1f" % _benchmark_min_fps
	lines.append("FPS Min/Ø: %s / %.1f" % [min_fps_text, avg_fps])
	lines.append("Pro Spieler:")
	lines.append(_get_per_player_summary())

	var spawn_preview: PackedStringArray = []
	for i in range(_slot_respawn_points.size()):
		var p := _slot_respawn_points[i]
		spawn_preview.append("P%d Spawn: (%.1f, %.1f, %.1f)" % [i + 1, p.x, p.y, p.z])
	lines.append("Respawnpunkte:")
	lines.append("\n".join(spawn_preview))

	return "\n".join(lines)


func _get_peer_display_name(peer_id: int) -> String:
	if _peer_slots.has(peer_id):
		return "P%d" % (int(_peer_slots[peer_id]) + 1)
	return "Peer %d" % peer_id


func _get_per_player_summary() -> String:
	var alive_per_peer: Dictionary = {}
	for child in agents_root.get_children():
		if not is_instance_valid(child):
			continue
		if child.is_queued_for_deletion():
			continue
		if child is RTSAgent:
			alive_per_peer[child.owner_peer_id] = int(alive_per_peer.get(child.owner_peer_id, 0)) + 1

	var peer_ids: Array[int] = []
	for key in _benchmark_created_per_peer.keys():
		peer_ids.append(int(key))
	for key in alive_per_peer.keys():
		var pid := int(key)
		if not peer_ids.has(pid):
			peer_ids.append(pid)
	peer_ids.sort_custom(func(a: int, b: int) -> bool:
		var slot_a := int(_peer_slots.get(a, 9999))
		var slot_b := int(_peer_slots.get(b, 9999))
		if slot_a == slot_b:
			return a < b
		return slot_a < slot_b
	)

	if peer_ids.is_empty():
		return "-"

	var lines: PackedStringArray = []
	for pid in peer_ids:
		var alive := int(alive_per_peer.get(pid, 0))
		var created := int(_benchmark_created_per_peer.get(pid, 0))
		lines.append("%s: aktiv %d | erstellt %d" % [_get_peer_display_name(pid), alive, created])
	return "\n".join(lines)


func _refresh_drag_selection_units() -> void:
	if not is_instance_valid(drag_selection):
		return
	var arr: Array = []
	for child in agents_root.get_children():
		if child.is_queued_for_deletion():
			continue
		arr.append(child)
	drag_selection.set_units(arr)


func register_network_packet_sent(count: int = 1) -> void:
	if _network_manager and _network_manager.has_method("register_network_packet_sent"):
		_network_manager.register_network_packet_sent(count)


func register_network_packet_received(count: int = 1) -> void:
	if _network_manager and _network_manager.has_method("register_network_packet_received"):
		_network_manager.register_network_packet_received(count)


func is_game_paused() -> bool:
	if _network_manager and _network_manager.has_method("is_game_paused"):
		return _network_manager.is_game_paused()
	return false


func _set_status(message: String) -> void:
	if _status_label:
		_status_label.text = message


func _refresh_local_ip_info() -> void:
	if _network_manager == null or not _network_manager.has_method("get_local_ipv4_addresses"):
		return
	var ips: Array[String] = _network_manager.get_local_ipv4_addresses()
	if ips.is_empty():
		_local_ip_label.text = "Lokale IP: keine LAN-IP gefunden"
		return
	_local_ip_label.text = "Lokale IP(s): %s" % ", ".join(ips)
	if _ip_input and (_ip_input.text == "" or _ip_input.text == "127.0.0.1"):
		_ip_input.text = ips[0]


func _on_self_test_pressed() -> void:
	_run_self_test()


func _run_self_test() -> void:
	if _network_manager == null or not _network_manager.has_method("get_connection_diagnostics"):
		return
	var diag: Dictionary = _network_manager.get_connection_diagnostics()
	var host_state := "Ja" if diag.get("is_host", false) else "Nein"
	var peer_state := "Ja" if diag.get("has_peer", false) else "Nein"
	var local_ips: Array = diag.get("local_ipv4", [])
	var ips_text := "keine"
	if local_ips.size() > 0:
		ips_text = ", ".join(local_ips)
	_diagnostic_label.text = "Diagnose:\nPeer aktiv: %s\nHost: %s\nPort: %s\nPeers: %s\nLast Join IP: %s\nFehler: %s (%s)\nLokale IP(s): %s" % [
		peer_state,
		host_state,
		str(diag.get("active_port", "-")),
		str(diag.get("peer_count", 0)),
		str(diag.get("last_join_address", "-")),
		str(diag.get("last_error_code", OK)),
		str(diag.get("last_error_name", "OK")),
		ips_text
	]


func _update_role_actions() -> void:
	var is_host: bool = _network_manager != null and _network_manager.is_host()
	_start_button.disabled = not is_host
	_restart_button.disabled = not is_host
	_pause_button.disabled = false
	if _network_manager and _network_manager.has_peer() and not is_host and _benchmark_auto_spawn_enabled:
		_benchmark_auto_spawn_enabled = false
		_benchmark_auto_spawn_timer = 0.0
	_update_benchmark_ui()


func _update_stats() -> void:
	if not _stats_label:
		return
	var ping_text := "-"
	if _network_manager and _network_manager.has_peer():
		if _network_manager.is_host():
			ping_text = "0"
		else:
			ping_text = "%.0f" % _network_manager.get_ping_ms()
	_stats_label.text = "FPS: %d\nPing: %s ms\nGesendet: %d\nEmpfangen: %d" % [
		Engine.get_frames_per_second(),
		ping_text,
		0 if _network_manager == null else _network_manager.get_packets_sent(),
		0 if _network_manager == null else _network_manager.get_packets_received()
	]
	_update_benchmark_ui()


func _process_benchmark(delta: float) -> void:
	_update_benchmark_counts()
	_benchmark_runtime_sec += delta
	var fps := float(Engine.get_frames_per_second())
	if fps > 0.0:
		_benchmark_min_fps = min(_benchmark_min_fps, fps)
		_benchmark_fps_sum += fps
		_benchmark_fps_samples += 1

	if not _benchmark_auto_spawn_enabled:
		return

	_benchmark_auto_spawn_timer += delta
	var interval: float = 0.5
	if _benchmark_interval_input != null:
		interval = maxf(0.1, float(_benchmark_interval_input.value))
	if _benchmark_auto_spawn_timer >= interval:
		_benchmark_auto_spawn_timer = 0.0
		_on_reinforce_pressed()


func _register_units_created(peer_id: int, count: int) -> void:
	if count <= 0:
		return
	_benchmark_total_created += count
	_benchmark_created_per_peer[peer_id] = int(_benchmark_created_per_peer.get(peer_id, 0)) + count


func _update_benchmark_counts() -> void:
	var alive := 0
	for child in agents_root.get_children():
		if not is_instance_valid(child):
			continue
		if child.is_queued_for_deletion():
			continue
		if child is RTSAgent:
			alive += 1
	_benchmark_current_units = alive
	_benchmark_peak_units = max(_benchmark_peak_units, _benchmark_current_units)


func _reset_benchmark_metrics() -> void:
	_benchmark_total_created = 0
	_benchmark_created_per_peer.clear()
	_benchmark_current_units = 0
	_benchmark_peak_units = 0
	_benchmark_runtime_sec = 0.0
	_benchmark_min_fps = INF
	_benchmark_fps_sum = 0.0
	_benchmark_fps_samples = 0
	_benchmark_auto_spawn_timer = 0.0
	_update_benchmark_counts()
	_update_benchmark_ui()


func _update_benchmark_ui() -> void:
	if _benchmark_auto_button:
		_benchmark_auto_button.text = "Auto-Spawn: AN" if _benchmark_auto_spawn_enabled else "Auto-Spawn: AUS"

	if not _benchmark_label:
		return

	var avg_fps := 0.0
	if _benchmark_fps_samples > 0:
		avg_fps = _benchmark_fps_sum / float(_benchmark_fps_samples)
	var min_fps_text := "-"
	if _benchmark_fps_samples > 0 and _benchmark_min_fps < INF:
		min_fps_text = "%.1f" % _benchmark_min_fps
	var per_player_text := _get_per_player_summary()

	_benchmark_label.text = "Erstellt gesamt: %d\nAktuell aktiv: %d\nPeak aktiv: %d\nLaufzeit: %.1f s\nFPS Min/Ø: %s / %.1f\nPro Spieler:\n%s" % [
		_benchmark_total_created,
		_benchmark_current_units,
		_benchmark_peak_units,
		_benchmark_runtime_sec,
		min_fps_text,
		avg_fps,
		per_player_text
	]
