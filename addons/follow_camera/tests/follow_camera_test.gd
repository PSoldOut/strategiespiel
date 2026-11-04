extends SceneTree

const POSITION_EPSILON := 0.00001


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var target := Node3D.new()
	target.position = Vector3(4.0, 2.0, -3.0)
	root.add_child(target)

	var config := FollowCameraConfig.new()
	config.offset = Vector3(2.0, 5.0, 8.0)
	config.look_at_offset = Vector3(0.0, 1.0, 0.0)
	config.offset_space = FollowCameraConfig.OffsetSpace.WORLD

	var camera := FollowCamera3D.new()
	camera.target = target
	camera.config = config
	root.add_child(camera)

	var expected_position := target.global_position + config.offset
	_assert_vector_approx(camera.global_position, expected_position)
	_assert_camera_looks_at(camera, target.global_position + config.look_at_offset)

	target.rotation.y = PI * 0.5
	camera.snap_to_target()
	_assert_vector_approx(camera.global_position, expected_position)

	config.position_smoothing_speed = 2.0
	var start_position := camera.global_position
	target.position += Vector3(10.0, 0.0, 0.0)
	var desired_position := target.global_position + config.offset
	var expected_weight := 1.0 - exp(-config.position_smoothing_speed * 0.25)
	camera._process(0.25)
	_assert_vector_approx(
		camera.global_position,
		start_position.lerp(desired_position, expected_weight)
	)

	config.follow_enabled = false
	var disabled_position := camera.global_position
	target.position += Vector3(5.0, 0.0, 0.0)
	camera._process(1.0)
	_assert_vector_approx(camera.global_position, disabled_position)

	config.offset = Vector3.ZERO
	config.look_at_offset = Vector3.ZERO
	var rotation_before_degenerate_snap := camera.global_basis
	camera.snap_to_target()
	_assert_vector_approx(camera.global_position, target.global_position)
	assert(camera.global_basis.is_equal_approx(rotation_before_degenerate_snap))

	target.free()
	camera._process(1.0)
	camera.snap_to_target()

	camera.free()
	print("Follow camera tests passed.")
	quit()


func _assert_vector_approx(actual: Vector3, expected: Vector3) -> void:
	assert(actual.distance_to(expected) <= POSITION_EPSILON)


func _assert_camera_looks_at(camera: Camera3D, look_position: Vector3) -> void:
	var expected_direction := camera.global_position.direction_to(look_position)
	var camera_direction := -camera.global_basis.z.normalized()
	assert(camera_direction.dot(expected_direction) >= 1.0 - POSITION_EPSILON)
