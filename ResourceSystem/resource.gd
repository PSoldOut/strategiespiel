extends Node3D
class_name GameResource

@onready var visual: Node3D = $Visual
@onready var hitbox: Node3D = $Hitbox

@export var vorkommen: int = 100
@export var infinite: bool = true
@export var regen_value: int = 1

# Keeps the resource sitting on the tile while Visual is scaled down.
# Without this, scaling around the mesh/origin makes the resource float.
@export var keep_visual_bottom_anchored: bool = true

# Keeps Hitbox in the same scaled/anchored place as Visual.
@export var sync_hitbox_with_visual: bool = true

var abbau: int = 0
var last_step: int = -1

var _visual_base_scale: Vector3 = Vector3.ONE
var _visual_base_position: Vector3 = Vector3.ZERO
var _visual_anchor_bottom_y: float = 0.0
var _has_visual_anchor: bool = false

var _hitbox_base_scale: Vector3 = Vector3.ONE
var _hitbox_base_position: Vector3 = Vector3.ZERO


func _ready() -> void:
	add_to_group("resources")

	if visual != null:
		_visual_base_scale = visual.scale
		_visual_base_position = visual.position
		_visual_anchor_bottom_y = _get_node_mesh_bottom_y(visual)
		_has_visual_anchor = _visual_anchor_bottom_y < INF

	if hitbox != null:
		_hitbox_base_scale = hitbox.scale
		_hitbox_base_position = hitbox.position

	update_visual(true)


func on_resource_timer() -> void:
	mine(2)
	if infinite:
		regen()
	update_visual()


func mine(amount: int) -> void:
	abbau += amount
	abbau = clamp(abbau, 0, vorkommen)

	if abbau >= vorkommen and infinite == false:
		on_depleted()


func regen() -> void:
	abbau -= regen_value
	abbau = clamp(abbau, 0, vorkommen)


func update_visual(force: bool = false) -> void:
	if visual == null:
		return

	if vorkommen <= 0:
		return

	var remaining_ratio := float(vorkommen - abbau) / float(vorkommen)
	var step := int(floor(remaining_ratio * 10.0)) # 0-10
	step = clamp(step, 0, 10)

	# Only update if the 10% step changed.
	if not force and step == last_step:
		return

	last_step = step

	var scale_factor := float(step) / 10.0
	scale_factor = max(scale_factor, 0.1) # never completely invisible

	visual.position = _visual_base_position
	visual.scale = _visual_base_scale * scale_factor

	if keep_visual_bottom_anchored and _has_visual_anchor:
		_anchor_visual_bottom()

	if sync_hitbox_with_visual:
		_sync_hitbox_to_visual(scale_factor)

	print("Resource Step:", step, " Scale:", scale_factor)


func _anchor_visual_bottom() -> void:
	var current_bottom_y := _get_node_mesh_bottom_y(visual)
	if current_bottom_y >= INF:
		return

	# Move Visual vertically so its lowest mesh point stays at the original bottom height.
	visual.position.y += _visual_anchor_bottom_y - current_bottom_y


func _sync_hitbox_to_visual(scale_factor: float) -> void:
	if hitbox == null:
		return

	# Reset first, then apply the same 10% scaling as the Visual.
	# This avoids accumulated position/scale errors after many timer ticks.
	hitbox.scale = _hitbox_base_scale * scale_factor

	if visual != null:
		# Visual may have been moved by _anchor_visual_bottom(), so copy the final anchored position.
		hitbox.position = _hitbox_base_position + (visual.position - _visual_base_position)
	else:
		hitbox.position = _hitbox_base_position


func _get_node_mesh_bottom_y(root: Node3D) -> float:
	var result := [INF]
	_collect_mesh_bottom_y(root, result)
	return float(result[0])


func _collect_mesh_bottom_y(node: Node, result: Array) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			var aabb := mesh_instance.get_aabb()
			var min_pos := aabb.position
			var max_pos := aabb.position + aabb.size

			var corners: Array[Vector3] = [
				Vector3(min_pos.x, min_pos.y, min_pos.z),
				Vector3(max_pos.x, min_pos.y, min_pos.z),
				Vector3(min_pos.x, min_pos.y, max_pos.z),
				Vector3(max_pos.x, min_pos.y, max_pos.z),
				Vector3(min_pos.x, max_pos.y, min_pos.z),
				Vector3(max_pos.x, max_pos.y, min_pos.z),
				Vector3(min_pos.x, max_pos.y, max_pos.z),
				Vector3(max_pos.x, max_pos.y, max_pos.z),
			]

			for corner in corners:
				var global_corner := mesh_instance.to_global(corner)
				var resource_local_corner := to_local(global_corner)
				result[0] = min(float(result[0]), resource_local_corner.y)

	for child in node.get_children():
		_collect_mesh_bottom_y(child, result)


func on_depleted() -> void:
	print("Resource leer")
	queue_free()
