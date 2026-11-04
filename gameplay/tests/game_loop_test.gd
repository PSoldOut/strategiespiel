extends SceneTree

const RANGED_ENEMY_SCRIPT := preload("res://gameplay/entities/ranged_enemy.gd")
const BUILDING_SCRIPT := preload("res://gameplay/buildings/building.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://gameplay/game_run.tscn") as PackedScene
	var game_run := scene.instantiate() as GameRun
	root.add_child(game_run)
	await process_frame

	assert(game_run.map_spawner.get_map_width() == 32)
	assert(game_run.map_spawner.get_map_height() == 32)
	var has_nonzero_height := false
	for row in game_run.map_spawner.map_data:
		for cell in row:
			assert(cell["type"] == EnumMappings.GroundType.GRAS_TILE)
			has_nonzero_height = has_nonzero_height or not is_zero_approx(cell["height"])
	assert(has_nonzero_height)
	assert(game_run.wave_controller.running)
	assert(game_run.follow_camera.target == game_run.player)
	assert(game_run.placement_system.get_held_building_ids().size() == 3)
	_test_storage_gold_and_building_replacement(game_run)

	await create_timer(2.0).timeout
	assert(game_run.wave_controller.current_wave >= 1)
	assert(game_run.wave_controller.get_alive_enemy_count() > 0)
	var has_ranged_enemy := false
	for enemy in get_nodes_in_group(&"enemies"):
		has_ranged_enemy = has_ranged_enemy or enemy.get_script() == RANGED_ENEMY_SCRIPT
	assert(has_ranged_enemy)

	game_run.player.take_damage(100_000.0)
	await process_frame
	assert(game_run.game_over_panel.visible)
	assert(not game_run.wave_controller.running)

	game_run.free()
	await physics_frame
	await process_frame
	print("Game loop tests passed.")
	call_deferred("_finish")


func _finish() -> void:
	quit()


func _test_storage_gold_and_building_replacement(game_run: GameRun) -> void:
	game_run._on_enemy_defeated()
	assert(game_run.current_gold == 0)

	var placement := game_run.placement_system
	placement.cancel_preview()
	assert(placement.select_building(&"storage"))
	assert(placement.begin_preview() != null)
	var storage_transform := Transform3D(Basis.IDENTITY, Vector3(4.0, 0.0, 4.0))
	assert(placement.update_preview(storage_transform, true))
	var storage: BUILDING_SCRIPT = placement.confirm_placement()
	assert(storage != null)
	assert(is_equal_approx(storage.health_component.current_life, storage.max_life))

	game_run._on_enemy_defeated()
	assert(game_run.current_gold == game_run.gold_per_enemy)
	storage.take_damage(storage.max_life)
	assert(placement.get_placed_node(&"storage") == null)
	game_run._on_enemy_defeated()
	assert(game_run.current_gold == game_run.gold_per_enemy)

	placement.cancel_preview()
	assert(placement.begin_preview(&"storage") != null)
	var replacement_transform := Transform3D(Basis.IDENTITY, Vector3(6.0, 0.0, 4.0))
	assert(placement.update_preview(replacement_transform, true))
	var replacement: BUILDING_SCRIPT = placement.confirm_placement()
	assert(replacement != null)
	assert(is_equal_approx(replacement.health_component.current_life, replacement.max_life))
