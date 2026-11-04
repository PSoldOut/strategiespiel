extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var parent := Node3D.new()
	root.add_child(parent)
	var system := PlacePickupBuildingSystem.new()
	system.config = PlacePickupBuildingConfig.new()
	system.config.input_enabled = false
	system.building_parent = parent
	root.add_child(system)

	var tower := _make_definition(&"tower", Vector2i.ONE)
	var barracks := _make_definition(&"barracks", Vector2i(2, 2))
	var storage := _make_definition(&"storage", Vector2i(2, 1))
	assert(system.initialize([tower, barracks, storage]))
	assert(system.selected_building_id == &"tower")
	assert(system.select_next_held() == &"barracks")

	var preview := system.begin_preview()
	assert(preview != null)
	assert(preview.process_mode == Node.PROCESS_MODE_DISABLED)
	var preview_collision := preview.get_node("StaticBody3D/CollisionShape3D") as CollisionShape3D
	assert(preview_collision.disabled)
	var placed_transform := Transform3D(Basis.IDENTITY, Vector3(4.0, 1.0, 6.0))
	assert(system.update_preview(placed_transform, true))
	var placed := system.confirm_placement()
	assert(placed != null)
	assert(system.get_state(&"barracks").is_placed())
	assert(system.selected_building_id == &"tower")

	var save := system.create_save_state()
	assert(save.building_states.size() == 3)
	assert(system.pickup_building(placed))
	assert(system.get_state(&"barracks").is_held())
	assert(system.selected_building_id == &"barracks")

	assert(system.restore_save_state(save))
	assert(system.get_state(&"barracks").is_placed())
	var restored := system.get_placed_node(&"barracks")
	assert(restored != null)
	assert(restored.global_transform == placed_transform)
	assert(system.get_held_building_ids().size() == 2)

	system.free()
	parent.free()
	print("Place pickup building tests passed.")
	quit()


func _make_definition(
	building_id: StringName,
	footprint: Vector2i,
) -> PlaceableBuildingDefinition:
	var scene_root := Node3D.new()
	var body := StaticBody3D.new()
	body.name = "StaticBody3D"
	scene_root.add_child(body)
	body.owner = scene_root
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	collision.shape = BoxShape3D.new()
	body.add_child(collision)
	collision.owner = scene_root

	var scene := PackedScene.new()
	assert(scene.pack(scene_root) == OK)
	scene_root.free()

	var definition := PlaceableBuildingDefinition.new()
	definition.building_id = building_id
	definition.scene = scene
	definition.footprint = footprint
	return definition
