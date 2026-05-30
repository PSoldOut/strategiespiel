extends Node3D

const SPAWN_POINTS: Array[Vector3] = [
Vector3(-12.0, 1.0, -12.0),
Vector3(12.0, 1.0, -12.0),
Vector3(-12.0, 1.0, 12.0),
Vector3(12.0, 1.0, 12.0)
]

var agent_scene: PackedScene = preload("res://scenes/core/Agent.tscn")
var network_manager_script: Script = preload("res://scripts/network/NetworkManager.gd")

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D
@onready var agents_root: Node3D = $Agents
@onready var drag_selection: Control = $DragSelection
@onready var rts_camera: Camera3D = $RTSCamera

var _ui_visible: bool = true
var _player_nodes: Dictionary = {}
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
var _self_test_button: Button
var _diagnostic_label: Label
var _stats_label: Label


func _ready() -> void:
	add_to_group("world_root")
	nav_region.bake_navigation_mesh()
	_setup_network_manager()
	_create_ui()
	_refresh_local_ip_info()
	_update_role_actions()
	_set_status("Offline. F1 blendet das Multiplayer-Panel ein/aus.")


func _process(delta: float) -> void:
	if _network_manager and _network_manager.has_method("process_tick"):
		_network_manager.process_tick(delta)
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


func _on_network_status_changed(message: String) -> void:
	_set_status(message)
	_run_self_test()


func _on_network_spawn_player(peer_id: int, slot: int, color: Color) -> void:
	_spawn_player_for_peer(peer_id, slot, color)


func _on_network_clear_players() -> void:
	_clear_players()


func _on_network_peer_left(peer_id: int) -> void:
	if _player_nodes.has(peer_id):
		var node: Node = _player_nodes[peer_id]
		if is_instance_valid(node):
			node.queue_free()
		_player_nodes.erase(peer_id)
	_refresh_drag_selection_units()


func _on_network_match_started_changed(_started: bool) -> void:
	_update_role_actions()


func _on_network_pause_state_changed(paused: bool) -> void:
	Engine.time_scale = 0.0 if paused else 1.0


func _spawn_player_for_peer(peer_id: int, slot: int, color: Color) -> void:
	if _player_nodes.has(peer_id):
		var old_node: Node = _player_nodes[peer_id]
		if is_instance_valid(old_node):
			old_node.queue_free()
			_player_nodes.erase(peer_id)

	var agent := agent_scene.instantiate()
	agent.name = "Player_%d" % peer_id
	agents_root.add_child(agent)
	agent.global_position = SPAWN_POINTS[slot % SPAWN_POINTS.size()]
	if agent.has_method("configure_player"):
		agent.configure_player(peer_id, slot, color)
	_player_nodes[peer_id] = agent
	if peer_id == multiplayer.get_unique_id():
		drag_selection.team = agent.team
	_refresh_drag_selection_units()

	if peer_id == multiplayer.get_unique_id():
		rts_camera.global_position = agent.global_position + Vector3(0.0, 18.0, 0.0)


func _clear_players() -> void:
	for peer_id in _player_nodes.keys():
		var node: Node = _player_nodes[peer_id]
		if is_instance_valid(node):
			node.queue_free()
	_player_nodes.clear()
	_refresh_drag_selection_units()


func _refresh_drag_selection_units() -> void:
	if not is_instance_valid(drag_selection):
		return
	var arr: Array = []
	for child in agents_root.get_children():
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
