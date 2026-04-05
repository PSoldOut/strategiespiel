extends Control
class_name SpawnTester

@export var unit_scene: PackedScene
@export var body_scenes: Array[PackedScene] = []
@export var weapon_scenes: Array[PackedScene] = []
@export var spawn_parent: Node3D
@export var camera: Camera3D

@onready var body_select: OptionButton = $BodySelect
@onready var weapon_select: OptionButton = $WeaponSelect
@onready var spawn_button: Button = $SpawnButton

var current_unit: Unit = null

func _ready() -> void:
	for i in range(body_scenes.size()):
		var body := body_scenes[i]
		if body != null:
			body_select.add_item(body.resource_path.get_file().get_basename(), i)
	
	for i in range(weapon_scenes.size()):
		var weapon := weapon_scenes[i]
		if weapon != null:
			weapon_select.add_item(weapon.resource_path.get_file().get_basename(), i)
	
	spawn_button.pressed.connect(on_spawn_button_pressed)

func on_spawn_button_pressed() -> void:
	print("SPAWN BUTTON PRESSED")
	if unit_scene == null or spawn_parent == null:
		return
	
	if body_select.selected < 0 or body_select.selected >= body_scenes.size():
		return
	
	if weapon_select.selected < 0 or weapon_select.selected >= weapon_scenes.size():
		return
	
	# Alte Unit entfernen
	if current_unit != null and is_instance_valid(current_unit):
		current_unit.queue_free()
		current_unit = null
	
	# Neue Unit erzeugen
	var unit := unit_scene.instantiate() as Unit
	if unit == null:
		return
	
	spawn_parent.add_child(unit)
	unit.global_position = Vector3.ZERO
	unit.setup(
		body_scenes[body_select.selected],
		weapon_scenes[weapon_select.selected]
	)
	
	current_unit = unit
	
	if camera != null and camera.has_method("focus_on"):
		camera.focus_on(unit)
	get_viewport().gui_release_focus()
