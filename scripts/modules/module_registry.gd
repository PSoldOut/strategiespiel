class_name ModuleRegistry extends Node

var _loaded_modules: Array[GameModule] = []

func _build_modules_for_mode(mode_id: String) -> Array[GameModule]:
	var modules: Array[GameModule] = []
	match mode_id:
		"pvp":
			modules.append(preload("res://scripts/modules/pvp_module.gd").new())
		"pve":
			modules.append(preload("res://scripts/modules/pve_module.gd").new())
		"td":
			modules.append(preload("res://scripts/modules/td_module.gd").new())
		"mapeditor":
			pass
		_:
			modules.append(preload("res://scripts/modules/pve_module.gd").new())
	return modules

func activate_mode(mode_id: String, context: Dictionary) -> void:
	shutdown_all()
	var modules := _build_modules_for_mode(mode_id)
	for i in range(modules.size()):
		var module := modules[i]
		module.name = _runtime_module_name(mode_id, i)
		add_child(module)
		module.boot(context)
		_loaded_modules.append(module)

func _runtime_module_name(mode_id: String, index: int) -> String:
	return "RuntimeModule_%s_%d" % [mode_id, index]

func shutdown_all() -> void:
	for module in _loaded_modules:
		if is_instance_valid(module):
			module.shutdown()
			module.queue_free()
	_loaded_modules.clear()
