@tool
extends EditorPlugin

const CONFIG_SCRIPT := preload("res://addons/map_generator/map_generator_config.gd")
const DECORATION_RULE_SCRIPT := preload("res://addons/map_generator/map_decoration_rule.gd")
const RESULT_SCRIPT := preload("res://addons/map_generator/map_generation_result.gd")


func _enter_tree() -> void:
	add_custom_type("MapDecorationRule", "Resource", DECORATION_RULE_SCRIPT, null)
	add_custom_type("MapGeneratorConfig", "Resource", CONFIG_SCRIPT, null)
	add_custom_type("MapGenerationResult", "Resource", RESULT_SCRIPT, null)


func _exit_tree() -> void:
	remove_custom_type("MapGenerationResult")
	remove_custom_type("MapGeneratorConfig")
	remove_custom_type("MapDecorationRule")
