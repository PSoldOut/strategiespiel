class_name PvEModule extends GameModule

var world_node = Node

func boot(context: Dictionary) -> void:
	print("PVE start..", context)
	world_node = context.get("world_node", null)

func shutdown() -> void:
	print("PVE shutdown..")
