extends Node

@onready var world: WorldController = $World
@onready var network_manager: NetworkManager = $NetworkManager
@onready var module_registry: ModuleRegistry = $GameRegistry
@onready var cam_rig: Node3D = $CamRig

@onready var setup_ui: Control = $SetupUI

## TODO: Verbindungsmenu erst ab PvP-Auswahl einblenden lassen
@onready var network_container: Control = $SetupUI/SetupSectionUI/NetworkContainer
@onready var ip_input: LineEdit = $SetupUI/SetupSectionUI/NetworkContainer/IPContainer/IP
@onready var port_input: LineEdit = $SetupUI/SetupSectionUI/NetworkContainer/PortContainer/Port
@onready var role_input: OptionButton = $SetupUI/SetupSectionUI/NetworkContainer/RoleContainer/Role
@onready var is_localhost_check: CheckBox = $SetupUI/SetupSectionUI/NetworkContainer/LocalCheckBox

## TODO: temporaere Loesung fuer MapErstellung
@onready var tile_x: SpinBox = $SetupUI/SetupSectionUI/WorldContainer/TileXContainer/TileX
@onready var tile_y: SpinBox = $SetupUI/SetupSectionUI/WorldContainer/TileYContainer/TileY
@onready var tile_size: SpinBox = $SetupUI/SetupSectionUI/WorldContainer/TileSizeContainer/TileSize
@onready var start_button: Button = $SetupUI/SetupSectionUI/WorldContainer/StartButton

@onready var mode_select: OptionButton = $SetupUI/SetupSectionUI/WorldContainer/ModeContainer/ModeSelect

var player_name_input: LineEdit
var lobby_list: ItemList
var ready_button: Button
var lobby_status: Label

var _is_lobby_open: bool = false
var _pvp_launch_done: bool = false

const LOCALHOST_IP: String = "127.0.0.1"
const LOCALHOST_PORT: int = 24570

enum ENUM_MODE_SELECT {
	PVP = 0, PVE = 1, TD = 2, MAP_EDITOR = 3
}

enum ENUM_ROLE_SELECT {
	HOST = 0, JOIN = 1
}

func _ready() -> void:
	_setup_field_inputs()
	_setup_mode_select()
	_setup_role_select()
	_setup_network_lobby_ui()
	_setup_network_connections()
	
	mode_select.item_selected.connect(_on_mode_selected)
	role_input.item_selected.connect(_on_role_selected)
	is_localhost_check.toggled.connect(_on_localhost_toggled)
	_apply_network_ui_state(mode_select.get_selected_id())
	_apply_localhost_lock(is_localhost_check.button_pressed)
	_update_start_button_label()
	start_button.pressed.connect(_on_start_pressed)

func _to_mode_id(mode_selection: int) -> String:
	match mode_selection:
		ENUM_MODE_SELECT.PVP:
			return "pvp"
		ENUM_MODE_SELECT.PVE:
			return "pve"
		ENUM_MODE_SELECT.TD:
			return "td"
		ENUM_MODE_SELECT.MAP_EDITOR:
			return "mapeditor"
		_:
			return "pve"
			
func _on_mode_selected(selected_index: int) -> void:
	_apply_network_ui_state(mode_select.get_item_id(selected_index))

func _apply_network_ui_state(selected_mode: ENUM_MODE_SELECT) -> void:
	var is_pvp := selected_mode == ENUM_MODE_SELECT.PVP
	network_container.visible = is_pvp
	ip_input.editable = is_pvp and not is_localhost_check.button_pressed and role_input.get_selected_id() == ENUM_ROLE_SELECT.JOIN
	port_input.editable = is_pvp and not is_localhost_check.button_pressed
	role_input.disabled = not is_pvp
	if ready_button != null:
		ready_button.visible = is_pvp
	if lobby_list != null:
		lobby_list.visible = is_pvp
	if lobby_status != null:
		lobby_status.visible = is_pvp
	if player_name_input != null:
		player_name_input.visible = is_pvp
	_update_start_button_label()

func _setup_field_inputs() -> void:
	tile_x.min_value = 8
	tile_y.min_value = 8
	tile_x.max_value = 512
	tile_y.max_value = 512

	tile_size.min_value = 0.25
	tile_size.max_value = 8.0
	tile_size.step = 0.25

	tile_x.value = world.field_tiles.x
	tile_y.value = world.field_tiles.y
	tile_size.value = world.tile_world_size

func _setup_mode_select() -> void:
	mode_select.clear()
	mode_select.add_item("PvP", ENUM_MODE_SELECT.PVP)
	mode_select.add_item("PvE", ENUM_MODE_SELECT.PVE)
	mode_select.add_item("TowerDefense", ENUM_MODE_SELECT.TD)
	mode_select.add_item("MapEditor", ENUM_MODE_SELECT.MAP_EDITOR)
	mode_select.select(ENUM_MODE_SELECT.PVP)

func _setup_role_select() -> void:
	role_input.clear()
	role_input.add_item("Host", ENUM_ROLE_SELECT.HOST)
	role_input.add_item("Join", ENUM_ROLE_SELECT.JOIN)
	role_input.select(ENUM_ROLE_SELECT.HOST)

func _setup_network_lobby_ui() -> void:
	player_name_input = network_container.get_node_or_null("PlayerName")
	if player_name_input == null:
		player_name_input = LineEdit.new()
		player_name_input.name = "PlayerName"
		player_name_input.placeholder_text = "Player Name"
		player_name_input.text = OS.get_environment("USERNAME")
		network_container.add_child(player_name_input)

	lobby_status = network_container.get_node_or_null("LobbyStatus")
	if lobby_status == null:
		lobby_status = Label.new()
		lobby_status.name = "LobbyStatus"
		lobby_status.text = "Lobby nicht verbunden"
		network_container.add_child(lobby_status)

	lobby_list = network_container.get_node_or_null("LobbyPlayers")
	if lobby_list == null:
		lobby_list = ItemList.new()
		lobby_list.name = "LobbyPlayers"
		lobby_list.custom_minimum_size = Vector2(380, 170)
		network_container.add_child(lobby_list)

	ready_button = network_container.get_node_or_null("ReadyButton")
	if ready_button == null:
		ready_button = Button.new()
		ready_button.name = "ReadyButton"
		ready_button.text = "Set Ready"
		network_container.add_child(ready_button)

	ready_button.disabled = true
	ready_button.pressed.connect(_on_ready_pressed)

func _setup_network_connections() -> void:
	network_manager.lobby_updated.connect(_on_lobby_updated)
	network_manager.local_ready_changed.connect(_on_local_ready_changed)
	network_manager.game_start_authorized.connect(_on_game_start_authorized)
	network_manager.lobby_message.connect(_on_lobby_message)
	network_manager.connected_to_server.connect(_on_network_connected)
	network_manager.hosting_started.connect(_on_hosting_started)
	network_manager.connection_failed.connect(_on_network_connection_failed)
	network_manager.disconnected.connect(_on_network_disconnected)

func _setup_network_config() -> Dictionary:
	var ip := ip_input.text.strip_edges()
	if ip.is_empty() or is_localhost_check.button_pressed:
		ip = LOCALHOST_IP
	var port := int(port_input.text)
	port = clamp(port, 1024, 65535)
	
	var is_host := role_input.get_selected_id() == ENUM_ROLE_SELECT.HOST
	
	return {
		"is_host": is_host,
		"address": ip,
		"port": port
	}

func _is_pvp_mode_selected() -> bool:
	return mode_select.get_selected_id() == ENUM_MODE_SELECT.PVP

## Copilot-Suggestion fuer robuste Validierung der Eingabe
func _validate_network_inputs() -> bool:
	if not _is_pvp_mode_selected():
		return true
		
	if is_localhost_check.button_pressed:
		return true
		
	var raw_ip := ip_input.text.strip_edges()
	var raw_port := port_input.text.strip_edges()
	
	if not raw_port.is_valid_int():
		push_warning("Network setup: Port muss eine Zahl sein.")
		return false
		
	var parsed_port := int(raw_port)
	if parsed_port < 1024 or parsed_port > 65535:
		push_warning("Network setup: Port muss zwischen 1024 und 65535 liegen.")
		return false
		
	var is_host := role_input.get_selected_id() == ENUM_ROLE_SELECT.HOST
	if not is_host and raw_ip.is_empty():
		push_warning("Network setup: Join benoetigt eine gueltige Server-IP.")
		return false
		
	return true

func _on_start_pressed() -> void:
	var mode_id : String = _to_mode_id(mode_select.get_selected_id())
	if mode_id != "pvp":
		_start_non_pvp_mode(mode_id)
		return

	if not _is_lobby_open:
		_open_pvp_lobby()
		return

	if network_manager.can_start_match():
		network_manager.request_start_match()
	else:
		push_warning("Lobby: Start nicht moeglich, weil nicht alle ready sind.")

func _open_pvp_lobby() -> void:
	if not _validate_network_inputs():
		return
		
	var net := _setup_network_config()
	var player_name := "Player"
	if player_name_input != null:
		player_name = player_name_input.text.strip_edges()
		
	var err := network_manager.enter_lobby(net["is_host"], net["address"], net["port"], player_name)
	if err != OK:
		push_warning("Lobby: Verbindung fehlgeschlagen: " + str(err))
		return
		
	_is_lobby_open = true
	ready_button.disabled = false
	ip_input.editable = false
	port_input.editable = false
	role_input.disabled = true
	is_localhost_check.disabled = true
	
	if player_name_input != null:
		player_name_input.editable = false
	_update_start_button_label()

func _on_game_start_authorized() -> void:
	if _pvp_launch_done:
		return
	_pvp_launch_done = true
	_start_pvp_module()

func _start_pvp_module() -> void:
	var tiles := Vector2i(int(tile_x.value), int(tile_y.value))
	var size := float(tile_size.value)
	var net := _setup_network_config()
	
	world.configure_field(tiles, size)
	if cam_rig != null and cam_rig.has_method("focus_on_world"):
		cam_rig.call("focus_on_world", true, 0.8)
		
	var context := {
		"world_node": world,
		"field_tiles": tiles,
		"tile_world_size": size,
		"network_manager": network_manager,
		"is_host": net["is_host"],
		"address": net["address"],
		"port": net["port"]
	}
	
	module_registry.activate_mode("pvp", context)
	setup_ui.visible = false

func _start_non_pvp_mode(mode_id: String) -> void:
	var tiles := Vector2i(int(tile_x.value), int(tile_y.value))
	var size := float(tile_size.value)
	
	world.configure_field(tiles, size)
	if cam_rig != null and cam_rig.has_method("focus_on_world"):
		cam_rig.call("focus_on_world", true, 0.8)
		
	var context := {
		"world_node": world,
		"field_tiles": tiles,
		"tile_world_size": size,
		"network_manager": network_manager,
		"is_host": false,
		"address": LOCALHOST_IP,
		"port": LOCALHOST_PORT
	}
	
	module_registry.activate_mode(mode_id, context)
	setup_ui.visible = false

func _on_localhost_toggled(is_pressed: bool) -> void:
	_apply_localhost_lock(is_pressed)

func _on_role_selected(_index: int) -> void:
	_apply_localhost_lock(is_localhost_check.button_pressed)

func _apply_localhost_lock(is_locked: bool) -> void:
	if is_locked:
		ip_input.text = LOCALHOST_IP
		port_input.text = str(LOCALHOST_PORT)

	var is_join := role_input.get_selected_id() == ENUM_ROLE_SELECT.JOIN
	ip_input.editable = _is_pvp_mode_selected() and not is_locked and is_join and not _is_lobby_open
	port_input.editable = _is_pvp_mode_selected() and not is_locked and not _is_lobby_open

func _on_ready_pressed() -> void:
	network_manager.toggle_local_ready()

func _on_lobby_updated(players: Array) -> void:
	if lobby_list == null:
		return

	lobby_list.clear()
	for player in players:
		if typeof(player) != TYPE_DICTIONARY:
			continue
		var name := str(player.get("name", "Unknown"))
		var ip := str(player.get("ip", "unknown"))
		var ping := int(player.get("ping_ms", -1))
		var ready := bool(player.get("ready", false))
		var is_host := bool(player.get("is_host", false))
		var ping_label := "-"
		if ping >= 0:
			ping_label = str(ping) + " ms"
		var role := "JOIN"
		if is_host:
			role = "HOST"
		var line := "%s | %s | %s | %s | %s" % [role, name, ip, ping_label, ("READY" if ready else "WAIT")]
		lobby_list.add_item(line)

	_update_start_button_label()

func _on_local_ready_changed(is_ready: bool) -> void:
	if ready_button == null:
		return
	ready_button.text = "Set Ready"
	if is_ready:
		ready_button.text = "Set Not Ready"

func _on_lobby_message(message: String) -> void:
	if lobby_status != null:
		lobby_status.text = message

func _on_hosting_started(port: int) -> void:
	if lobby_status != null:
		lobby_status.text = "Host aktiv auf Port " + str(port)

func _on_network_connected(address: String, port: int) -> void:
	if lobby_status != null:
		lobby_status.text = "Verbunden mit " + address + ":" + str(port)

func _on_network_connection_failed(reason: String) -> void:
	if lobby_status != null:
		lobby_status.text = "Verbindung fehlgeschlagen: " + reason

func _on_network_disconnected() -> void:
	if lobby_status != null:
		lobby_status.text = "Verbindung getrennt"
	_is_lobby_open = false
	_pvp_launch_done = false
	if ready_button != null:
		ready_button.disabled = true
	ip_input.editable = true
	port_input.editable = true
	role_input.disabled = false
	is_localhost_check.disabled = false
	if player_name_input != null:
		player_name_input.editable = true
	_update_start_button_label()

func _update_start_button_label() -> void:
	if not _is_pvp_mode_selected():
		start_button.disabled = false
		start_button.text = "Generate"
		return
		
	if not _is_lobby_open:
		start_button.disabled = false
		start_button.text = "Open Lobby"
		return
		
	if not network_manager.multiplayer.is_server():
		start_button.disabled = true
		start_button.text = "Waiting for Host"
		return
		
	if network_manager.can_start_match():
		start_button.disabled = false
		start_button.text = "Start Match"
	else:
		start_button.disabled = true
		start_button.text = "Waiting for Ready"
