@tool
extends EditorPlugin

const CONFIG_SCRIPT := preload("res://addons/follow_camera/follow_camera_config.gd")
const CAMERA_SCRIPT := preload("res://addons/follow_camera/follow_camera_3d.gd")


func _enter_tree() -> void:
	add_custom_type("FollowCameraConfig", "Resource", CONFIG_SCRIPT, null)
	add_custom_type("FollowCamera3D", "Camera3D", CAMERA_SCRIPT, null)


func _exit_tree() -> void:
	remove_custom_type("FollowCamera3D")
	remove_custom_type("FollowCameraConfig")
