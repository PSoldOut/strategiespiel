class_name FollowCamera3D
extends Camera3D
## Follows and looks at a target using frame-rate-independent smoothing.

const LOOK_DIRECTION_EPSILON_SQUARED := 0.000001
const PARALLEL_UP_THRESHOLD := 0.999

@export var target: Node3D
@export var config: FollowCameraConfig = FollowCameraConfig.new()


func _ready() -> void:
	if _has_valid_target() and config != null:
		snap_to_target()


func _process(delta: float) -> void:
	if not _can_follow():
		return

	var desired_position := _get_desired_position()
	var desired_basis := _get_look_basis(desired_position, global_basis)
	var position_weight := _get_smoothing_weight(config.position_smoothing_speed, delta)
	var rotation_weight := _get_smoothing_weight(config.rotation_smoothing_speed, delta)
	var smoothed_position := global_position.lerp(desired_position, position_weight)
	var current_rotation := global_basis.orthonormalized().get_rotation_quaternion()
	var desired_rotation := desired_basis.get_rotation_quaternion()
	var smoothed_basis := Basis(current_rotation.slerp(desired_rotation, rotation_weight))

	global_transform = Transform3D(smoothed_basis, smoothed_position)


func snap_to_target() -> void:
	if not _has_valid_target() or config == null:
		return

	var desired_position := _get_desired_position()
	var desired_basis := _get_look_basis(desired_position, global_basis)
	global_transform = Transform3D(desired_basis, desired_position)


func _can_follow() -> bool:
	if config == null or not config.follow_enabled or not _has_valid_target():
		return false
	return not config.require_current_camera or is_current()


func _has_valid_target() -> bool:
	return is_instance_valid(target)


func _get_desired_position() -> Vector3:
	var position_offset := config.offset
	if config.offset_space == FollowCameraConfig.OffsetSpace.TARGET:
		position_offset = target.global_basis.orthonormalized() * position_offset
	return target.global_position + position_offset


func _get_look_basis(camera_position: Vector3, fallback_basis: Basis) -> Basis:
	var look_position := target.global_position + config.look_at_offset
	var look_direction := look_position - camera_position
	if look_direction.length_squared() <= LOOK_DIRECTION_EPSILON_SQUARED:
		return fallback_basis.orthonormalized()

	look_direction = look_direction.normalized()
	var up_direction := Vector3.UP
	if absf(look_direction.dot(up_direction)) >= PARALLEL_UP_THRESHOLD:
		up_direction = Vector3.FORWARD
	return Transform3D(fallback_basis, camera_position).looking_at(
		look_position, up_direction
	).basis.orthonormalized()


func _get_smoothing_weight(speed: float, delta: float) -> float:
	return 1.0 - exp(-maxf(speed, 0.0) * maxf(delta, 0.0))
