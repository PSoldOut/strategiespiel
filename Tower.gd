extends Building
class_name Tower

## Defensive building that fires real projectiles at enemy units in range.
## It only starts shooting once the construction is complete.

@export var projectile_scene: PackedScene = preload("res://projectile.tscn")
@export var attack_range := 18.0
@export var attack_damage := 10.0
@export var projectile_speed := 30.0
@export var fire_interval := 1.5

@onready var _muzzle: Marker3D = $Muzzle
@onready var _turret: MeshInstance3D = $Turret

var _team := ""
var _cooldown := 0.0


func _ready() -> void:
	super()
	_team = $SelectionUnit.team
	construction_completed.connect(_on_construction_completed)


func place() -> void:
	super()
	_turret.visible = false


func _physics_process(delta: float) -> void:
	if not constructed:
		return

	if _cooldown > 0.0:
		_cooldown -= delta
		return

	var target := _find_target()
	if target == null:
		return

	_aim_at(target)
	_fire_at(target)
	_cooldown = fire_interval


func _find_target() -> Node3D:
	var best: Node3D = null
	var best_distance := attack_range * attack_range

	for node in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(node) or node.is_queued_for_deletion():
			continue
		if not node.has_method("take_damage"):
			continue
		var unit_team = node.get("team")
		if unit_team == null or str(unit_team) == _team:
			continue

		var distance := global_position.distance_squared_to(node.global_position)
		if distance < best_distance:
			best_distance = distance
			best = node

	return best


func _aim_at(target: Node3D) -> void:
	var offset := target.global_position - _turret.global_position
	if Vector2(offset.x, offset.z).length_squared() < 0.0001:
		return
	_turret.rotation.y = atan2(offset.x, offset.z)


func _fire_at(target: Node3D) -> void:
	if projectile_scene == null:
		return

	var projectile := projectile_scene.instantiate()
	var host: Node = get_tree().current_scene
	if host == null:
		host = get_tree().root
	host.add_child(projectile)
	projectile.global_position = _muzzle.global_position
	projectile.setup(target, _team, attack_damage, projectile_speed)


func _on_construction_completed() -> void:
	_turret.visible = true
