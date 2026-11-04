@tool
extends EditorPlugin

const SPAWN_CATALOG_SCRIPT := preload("res://addons/entity_spawner/entity_spawn_catalog.gd")
const SPAWNER_SCRIPT := preload("res://addons/entity_spawner/entity_spawner.gd")


func _enter_tree() -> void:
	add_custom_type("EntitySpawnCatalog", "Resource", SPAWN_CATALOG_SCRIPT, null)
	add_custom_type("EntitySpawner", "Node3D", SPAWNER_SCRIPT, null)


func _exit_tree() -> void:
	remove_custom_type("EntitySpawner")
	remove_custom_type("EntitySpawnCatalog")
