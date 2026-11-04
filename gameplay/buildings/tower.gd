class_name TowerBuilding
extends "res://gameplay/buildings/building.gd"
## Automatically launches projectiles at the nearest enemy within range.

const GROUP_ENEMIES := &"enemies"
const COMBAT_PROJECTILE_SCRIPT := preload("res://gameplay/combat/combat_projectile.gd")
const PROJECTILE_SCENE := preload("res://gameplay/combat/combat_projectile.tscn")

@export var attack_range: float = 10.0
@export var attack_damage: float = 14.0
@export var attack_cooldown: float = 0.8
@export var projectile_speed: float = 18.0
@export var projectile_color := Color(1.0, 0.75, 0.1)
@export var range_indicator_color := Color(0.2, 0.65, 1.0, 0.16)

@onready var attack_origin: Marker3D = $AttackOrigin
@onready var range_indicator: MeshInstance3D = $RangeIndicator

var _cooldown_remaining := 0.0


func _process(delta: float) -> void:
	if not is_active():
		return
	_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)
	if not is_zero_approx(_cooldown_remaining):
		return

	var target := _find_nearest_enemy()
	if target == null:
		return
	_launch_projectile(target)
	_cooldown_remaining = attack_cooldown


func _on_activated() -> void:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = range_indicator_color

	var mesh := CylinderMesh.new()
	mesh.top_radius = attack_range
	mesh.bottom_radius = attack_range
	mesh.height = 0.025
	mesh.radial_segments = 64
	mesh.material = material
	range_indicator.mesh = mesh


func _launch_projectile(target: Enemy) -> void:
	var projectile: COMBAT_PROJECTILE_SCRIPT = PROJECTILE_SCENE.instantiate()
	projectile.configure(target, attack_damage, projectile_speed, projectile_color)
	get_parent().add_child(projectile)
	projectile.global_position = attack_origin.global_position


func _find_nearest_enemy() -> Enemy:
	var nearest: Enemy
	var nearest_distance := attack_range
	for node in get_tree().get_nodes_in_group(GROUP_ENEMIES):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead():
			continue
		var offset := enemy.global_position - global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance <= nearest_distance:
			nearest = enemy
			nearest_distance = distance
	return nearest
