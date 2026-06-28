extends RefCounted
class_name MapCollisionBaker


static func make_trimesh_shape(mesh: Mesh) -> Shape3D:
	if mesh == null:
		return null

	return mesh.create_trimesh_shape()


static func make_static_body_from_mesh(mesh: Mesh, body_name: String = "StaticBody3D") -> StaticBody3D:
	var shape := make_trimesh_shape(mesh)
	if shape == null:
		return null

	return make_static_body_from_shape(shape, body_name)


static func make_static_body_from_shape(shape: Shape3D, body_name: String = "StaticBody3D") -> StaticBody3D:
	if shape == null:
		return null

	var body := StaticBody3D.new()
	body.name = body_name

	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	collision_shape.shape = shape
	body.add_child(collision_shape)

	return body
