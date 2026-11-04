extends SceneTree

const HEALTH_COMPONENT_SCRIPT := preload("res://gameplay/entities/health_component.gd")
const ENEMY_SCRIPT := preload("res://gameplay/entities/enemy.gd")
const COMBAT_PROJECTILE_SCRIPT := preload("res://gameplay/combat/combat_projectile.gd")
const COMBAT_PROJECTILE_SCENE := preload("res://gameplay/combat/combat_projectile.tscn")
const BUILDING_SCRIPT := preload("res://gameplay/buildings/building.gd")
const PLAYER_SCENE := preload("res://gameplay/entities/player.tscn")
const ENEMY_SCENE := preload("res://gameplay/entities/enemy.tscn")
const RANGED_ENEMY_SCENE := preload("res://gameplay/entities/ranged_enemy.tscn")
const TOWER_SCENE := preload("res://buildings/tower.tscn")
const FRIENDLY_SOLDIER_SCENE := preload(
	"res://gameplay/entities/friendly_soldier.tscn"
)


class DamageTarget extends Node3D:
	var received_damage := 0.0


	func take_damage(amount: float) -> void:
		received_damage += amount


	func is_dead() -> bool:
		return false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_health_damage_and_death()
	_test_enemy_wave_scaling()
	_test_entity_scenes()
	_test_enemy_targets_buildings()
	_test_projectile_damage()
	print("Entity tests passed.")
	quit()


func _test_health_damage_and_death() -> void:
	var health: HEALTH_COMPONENT_SCRIPT = HEALTH_COMPONENT_SCRIPT.new()
	health.max_life = 100.0
	health.current_life = 100.0
	root.add_child(health)
	var death_count := [0]
	health.died.connect(func() -> void: death_count[0] += 1)

	health.damage(30.0)
	assert(is_equal_approx(health.current_life, 70.0))
	health.heal(10.0)
	assert(is_equal_approx(health.current_life, 80.0))
	health.damage(200.0)
	assert(is_zero_approx(health.current_life))
	assert(death_count[0] == 1)
	health.damage(1.0)
	assert(death_count[0] == 1)
	health.free()


func _test_enemy_wave_scaling() -> void:
	var enemy: ENEMY_SCRIPT = ENEMY_SCENE.instantiate() as ENEMY_SCRIPT
	root.add_child(enemy)
	enemy.configure_for_wave(3, 1.5, 1.2, 2.0)

	assert(enemy.configured_wave == 3)
	assert(is_equal_approx(enemy.health_component.max_life, 78.0))
	assert(is_equal_approx(enemy.speed, 3.816))
	assert(is_equal_approx(enemy.attack_damage, 19.2))
	enemy.free()


func _test_entity_scenes() -> void:
	var scenes: Array[PackedScene] = [
		PLAYER_SCENE,
		ENEMY_SCENE,
		RANGED_ENEMY_SCENE,
		FRIENDLY_SOLDIER_SCENE,
	]
	for scene in scenes:
		var entity := scene.instantiate() as CharacterBody3D
		assert(entity != null)
		assert(entity.get_node_or_null("MeshInstance3D") != null)
		assert(entity.get_node_or_null("CollisionShape3D") != null)
		assert(entity.get_node_or_null("HealthComponent") != null)
		entity.free()

	var ranged_enemy: ENEMY_SCRIPT = RANGED_ENEMY_SCENE.instantiate()
	assert(ranged_enemy.projectile_scene == COMBAT_PROJECTILE_SCENE)
	ranged_enemy.free()


func _test_projectile_damage() -> void:
	var target := DamageTarget.new()
	target.position = Vector3(0.0, 0.0, 1.0)
	root.add_child(target)

	var projectile: COMBAT_PROJECTILE_SCRIPT = COMBAT_PROJECTILE_SCENE.instantiate()
	projectile.configure(target, 12.0, 1000.0, Color.MAGENTA)
	root.add_child(projectile)
	projectile._process(1.0)

	assert(is_equal_approx(target.received_damage, 12.0))
	target.free()


func _test_enemy_targets_buildings() -> void:
	var tower: BUILDING_SCRIPT = TOWER_SCENE.instantiate()
	root.add_child(tower)
	tower.position = Vector3(2.0, 0.0, 0.0)
	tower.activate()

	var enemy: ENEMY_SCRIPT = ENEMY_SCENE.instantiate()
	root.add_child(enemy)
	assert(enemy._find_nearest_target() == tower)
	enemy.free()
	tower.free()
