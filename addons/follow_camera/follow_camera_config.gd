class_name FollowCameraConfig
extends Resource
## Configures positioning, aiming, and smoothing for FollowCamera3D.

enum OffsetSpace {
	WORLD = 0,
	TARGET = 1,
}

@export var offset := Vector3(0.0, 5.0, 10.0)
@export var look_at_offset := Vector3.ZERO
@export_range(0.0, 100.0, 0.1, "or_greater") var position_smoothing_speed := 8.0
@export_range(0.0, 100.0, 0.1, "or_greater") var rotation_smoothing_speed := 8.0
@export var follow_enabled := true
@export var require_current_camera := false
@export var offset_space := OffsetSpace.WORLD
