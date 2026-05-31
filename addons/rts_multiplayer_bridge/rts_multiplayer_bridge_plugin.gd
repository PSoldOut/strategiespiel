@tool
extends EditorPlugin

func _enter_tree() -> void:
	add_custom_type("RTSMultiplayerBridge", "Node", preload("rts_multiplayer_bridge.gd"), null)


func _exit_tree() -> void:
	remove_custom_type("RTSMultiplayerBridge")
