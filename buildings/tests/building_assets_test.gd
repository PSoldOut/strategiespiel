extends SceneTree

const BUILDING_SCRIPT := preload("res://gameplay/buildings/building.gd")
const TOWER_SCRIPT := preload("res://gameplay/buildings/tower.gd")
const BARRACKS_SCRIPT := preload("res://gameplay/buildings/barracks.gd")

const EXPECTED_BUILDINGS := {
	&"tower": {
		"definition": "res://buildings/tower_definition.tres",
		"footprint": Vector2i.ONE,
		"marker": NodePath("AttackOrigin"),
		"max_life": 160.0,
	},
	&"barracks": {
		"definition": "res://buildings/barracks_definition.tres",
		"footprint": Vector2i(2, 2),
		"marker": NodePath("UnitSpawnPoint"),
		"max_life": 220.0,
	},
	&"storage": {
		"definition": "res://buildings/storage_definition.tres",
		"footprint": Vector2i(2, 1),
		"marker": NodePath("DepositPoint"),
		"max_life": 180.0,
	},
}
const REQUIRED_ACTIONS: Array[StringName] = [
	&"building_select_next",
	&"building_select_previous",
	&"building_place",
	&"building_pickup",
	&"building_rotate",
	&"building_cancel",
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for building_id in EXPECTED_BUILDINGS:
		var expected: Dictionary = EXPECTED_BUILDINGS[building_id]
		var definition := load(expected["definition"]) as PlaceableBuildingDefinition
		assert(definition != null)
		assert(definition.building_id == building_id)
		assert(definition.footprint == expected["footprint"])
		assert(definition.is_valid())

		var building: BUILDING_SCRIPT = definition.scene.instantiate()
		assert(building != null)
		root.add_child(building)
		assert(building.get_node_or_null("StaticBody3D/CollisionShape3D") != null)
		assert(building.get_node_or_null(expected["marker"]) != null)
		assert(building.get_node_or_null("HealthComponent") != null)
		assert(building.get_node_or_null("HealthBar") != null)
		building.activate()
		assert(is_equal_approx(building.health_component.current_life, expected["max_life"]))
		building.take_damage(expected["max_life"] * 0.5)
		assert(is_equal_approx(building.health_bar.get_ratio(), 0.5))
		building.free()

	_test_tower_range_indicator()
	_test_barracks_spawn_progress()

	var placement_scene := load("res://buildings/building_placement.tscn") as PackedScene
	var placement := placement_scene.instantiate() as PlacePickupBuildingSystem
	root.add_child(placement)
	assert(placement.definitions.size() == 3)
	assert(placement.get_held_building_ids().size() == 3)
	placement.free()

	for action in REQUIRED_ACTIONS:
		assert(InputMap.has_action(action))
		assert(not InputMap.action_get_events(action).is_empty())

	print("Building asset tests passed.")
	quit()


func _test_tower_range_indicator() -> void:
	var tower_scene := load("res://buildings/tower.tscn") as PackedScene
	var tower: TOWER_SCRIPT = tower_scene.instantiate()
	root.add_child(tower)
	tower.activate()
	var range_mesh := tower.range_indicator.mesh as CylinderMesh
	assert(range_mesh != null)
	assert(is_equal_approx(range_mesh.top_radius, tower.attack_range))
	tower.free()


func _test_barracks_spawn_progress() -> void:
	var barracks_scene := load("res://buildings/barracks.tscn") as PackedScene
	var barracks: BARRACKS_SCRIPT = barracks_scene.instantiate()
	root.add_child(barracks)
	barracks.activate()
	barracks._process(barracks.spawn_interval * 0.5)
	assert(is_equal_approx(barracks.get_spawn_progress(), 0.5))
	assert(is_equal_approx(barracks.spawn_progress_bar.get_ratio(), 0.5))
	barracks.free()
