class_name EntitySpawnCatalog
extends Resource
## Maps stable entity IDs to scenes that an EntitySpawner may instantiate.

@export var scenes: Dictionary[StringName, PackedScene] = {}


func has_entity(entity_id: StringName) -> bool:
	return not entity_id.is_empty() and scenes.has(entity_id) and scenes[entity_id] != null


func get_scene(entity_id: StringName) -> PackedScene:
	return scenes.get(entity_id) as PackedScene


func get_entity_ids() -> Array[StringName]:
	var entity_ids: Array[StringName] = []
	for entity_id in scenes:
		entity_ids.append(entity_id)
	entity_ids.sort()
	return entity_ids


func register_scene(entity_id: StringName, scene: PackedScene) -> bool:
	if entity_id.is_empty() or scene == null:
		return false
	scenes[entity_id] = scene
	emit_changed()
	return true


func unregister_scene(entity_id: StringName) -> bool:
	if not scenes.erase(entity_id):
		return false
	emit_changed()
	return true
