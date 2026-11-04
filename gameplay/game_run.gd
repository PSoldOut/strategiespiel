class_name GameRun
extends Node3D
## Orchestrates one minimal generated-map survival run.

const ENEMY_SCENE_PATH := "res://gameplay/entities/enemy.tscn"
const RANGED_ENEMY_SCENE_PATH := "res://gameplay/entities/ranged_enemy.tscn"
const MAP_WIDTH := 32
const MAP_HEIGHT := 32
const TILE_SIZE := 2.0

@export_range(0, 1000, 1) var gold_per_enemy := 1

@onready var map_spawner: MapSpawner = $MapSpawner
@onready var player: Player = $Player
@onready var follow_camera: FollowCamera3D = $FollowCamera3D
@onready var enemy_spawner: EntitySpawner = $EnemySpawner
@onready var wave_controller: WaveController = $WaveController
@onready var placement_system: PlacePickupBuildingSystem = $BuildingPlacement
@onready var placement_controller: BuildingPlacementController = $BuildingPlacementController
@onready var health_label: Label = $HUD/Margin/VBox/HealthLabel
@onready var wave_label: Label = $HUD/Margin/VBox/WaveLabel
@onready var enemies_label: Label = $HUD/Margin/VBox/EnemiesLabel
@onready var time_label: Label = $HUD/Margin/VBox/TimeLabel
@onready var gold_label: Label = $HUD/Margin/VBox/GoldLabel
@onready var building_label: Label = $HUD/Margin/VBox/BuildingLabel
@onready var controls_label: Label = $HUD/ControlsLabel
@onready var game_over_panel: Control = $HUD/GameOverPanel
@onready var restart_button: Button = $HUD/GameOverPanel/VBox/RestartButton
@onready var menu_button: Button = $HUD/GameOverPanel/VBox/MenuButton

var _elapsed_time := 0.0
var _game_over := false
var current_gold := 0


func _ready() -> void:
	_generate_map()
	_place_player_at_center()
	_configure_enemy_spawner()
	follow_camera.target = player
	follow_camera.snap_to_target()

	player.health_component.health_changed.connect(_on_player_health_changed)
	player.died.connect(_on_player_died)
	wave_controller.wave_started.connect(_on_wave_started)
	wave_controller.enemy_count_changed.connect(_on_enemy_count_changed)
	wave_controller.enemy_defeated.connect(_on_enemy_defeated)
	placement_controller.selected_building_changed.connect(_on_building_selected)
	restart_button.pressed.connect(_on_restart_pressed)
	menu_button.pressed.connect(_on_menu_pressed)

	game_over_panel.visible = false
	controls_label.text = (
		"WASD Move | E/Q Select Building | LMB Place | RMB Pickup | R Rotate"
	)
	_update_health_label(
		player.health_component.current_life,
		player.health_component.max_life,
	)
	_on_building_selected(placement_system.selected_building_id)
	wave_controller.start()


func _process(delta: float) -> void:
	if _game_over:
		return
	_elapsed_time += delta
	time_label.text = "Time: %02d:%02d" % [int(_elapsed_time) / 60, int(_elapsed_time) % 60]
	gold_label.text = "Gold: %d" % current_gold


func exit_state() -> void:
	wave_controller.stop()


func _generate_map() -> void:
	var config := GameMapGeneratorConfig.create_default(MAP_WIDTH, MAP_HEIGHT)
	var random := RandomNumberGenerator.new()
	random.randomize()
	map_spawner.generate_new_run_map(config, random.randi_range(1, 2_147_483_647))


func _place_player_at_center() -> void:
	var center_grid := Vector2i(int(MAP_WIDTH / 2), int(MAP_HEIGHT / 2))
	player.global_position = Vector3(
		float(MAP_WIDTH) * TILE_SIZE * 0.5,
		map_spawner.get_tile_height(center_grid) + 1.0,
		float(MAP_HEIGHT) * TILE_SIZE * 0.5,
	)


func _configure_enemy_spawner() -> void:
	var catalog := EntitySpawnCatalog.new()
	catalog.register_scene(&"enemy_crawler", load(ENEMY_SCENE_PATH) as PackedScene)
	catalog.register_scene(&"enemy_spitter", load(RANGED_ENEMY_SCENE_PATH) as PackedScene)
	enemy_spawner.catalog = catalog

	var center := Vector3(
		float(MAP_WIDTH) * TILE_SIZE * 0.5,
		0.7,
		float(MAP_HEIGHT) * TILE_SIZE * 0.5,
	)
	var radius := float(mini(MAP_WIDTH, MAP_HEIGHT)) * TILE_SIZE * 0.42
	for index in 8:
		var angle := TAU * float(index) / 8.0
		var marker := Marker3D.new()
		marker.name = "EnemySpawn%02d" % index
		var marker_position := center + Vector3(cos(angle), 0.0, sin(angle)) * radius
		var marker_grid := map_spawner.world_position_to_grid(marker_position)
		marker_position.y = map_spawner.get_tile_height(marker_grid) + 0.8
		marker.position = marker_position
		enemy_spawner.add_child(marker)
		enemy_spawner.spawn_points.append(marker)


func _on_player_health_changed(current_life: float, max_life: float) -> void:
	_update_health_label(current_life, max_life)


func _update_health_label(current_life: float, max_life: float) -> void:
	health_label.text = "Life: %d / %d" % [int(ceil(current_life)), int(ceil(max_life))]


func _on_wave_started(wave: int, enemy_count: int) -> void:
	wave_label.text = "Wave: %d" % wave
	enemies_label.text = "Enemies: %d" % enemy_count


func _on_enemy_count_changed(alive_enemies: int) -> void:
	enemies_label.text = "Enemies: %d" % alive_enemies


func _on_enemy_defeated() -> void:
	var storage := placement_system.get_placed_node(&"storage")
	if storage == null or not storage.has_method(&"is_dead") or storage.call(&"is_dead"):
		return
	current_gold += gold_per_enemy
	gold_label.text = "Gold: %d" % current_gold


func _on_building_selected(building_id: StringName) -> void:
	building_label.text = (
		"Building: %s" % String(building_id).capitalize()
		if not building_id.is_empty()
		else "Building: None held"
	)


func _on_player_died() -> void:
	_game_over = true
	wave_controller.stop()
	placement_controller.enabled = false
	game_over_panel.visible = true


func _on_restart_pressed() -> void:
	var game_manager := get_node_or_null("../../GameManager") as GameManager
	if game_manager != null:
		game_manager.reload_current_state()


func _on_menu_pressed() -> void:
	var game_manager := get_node_or_null("../../GameManager") as GameManager
	if game_manager != null:
		game_manager.change_state(EnumMappings.GameState.MAIN_MENU)
