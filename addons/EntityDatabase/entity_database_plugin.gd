@tool
extends EditorPlugin

const AUTOLOAD_NAME := "EntityDatabase"
const AUTOLOAD_PATH := "res://addons/EntityDatabase/entity_database.gd"

var _registered_autoload := false


func _enter_tree() -> void:
	if not ProjectSettings.has_setting("autoload/" + AUTOLOAD_NAME):
		add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)
		_registered_autoload = true
		print("[EntityDatabasePlugin] Autoload added: ", AUTOLOAD_NAME)


func _exit_tree() -> void:
	if _registered_autoload and ProjectSettings.has_setting("autoload/" + AUTOLOAD_NAME):
		remove_autoload_singleton(AUTOLOAD_NAME)
		_registered_autoload = false
		print("[EntityDatabasePlugin] Autoload removed: ", AUTOLOAD_NAME)
