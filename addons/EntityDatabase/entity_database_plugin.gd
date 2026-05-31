@tool
extends EditorPlugin

const AUTOLOAD_NAME := "EntityDatabase"
const AUTOLOAD_PATH := "res://addons/entity_database/entity_database.gd"


func _enter_tree() -> void:
	if not ProjectSettings.has_setting("autoload/" + AUTOLOAD_NAME):
		add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)
		print("[EntityDatabasePlugin] Autoload added: ", AUTOLOAD_NAME)


func _exit_tree() -> void:
	if ProjectSettings.has_setting("autoload/" + AUTOLOAD_NAME):
		remove_autoload_singleton(AUTOLOAD_NAME)
		print("[EntityDatabasePlugin] Autoload removed: ", AUTOLOAD_NAME)
