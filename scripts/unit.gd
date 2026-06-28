extends CharacterBody3D

@export var move_speed: float = 6.0
@export var unit_id: int = -1
@export var team_id: int = -1

@onready var nav: NavigationAgent3D = $NavigationAgent3D
@onready var selection_decal: Node3D = $SelectionDecal

var is_selected: bool = false

func _ready() -> void:
	add_to_group("selectable_units")
	_set_selected(false)

func _physics_process(_delta: float) -> void:
	if nav.is_navigation_finished():
		velocity = Vector3.ZERO
		move_and_slide()
		return
	var next_pos := nav.get_next_path_position()
	var dir := (next_pos - global_position)
	dir.y = 0.0
	if dir.length() > 0.05:
		dir = dir.normalized()
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed
		move_and_slide()
		look_at(Vector3(next_pos.x, global_position.y, next_pos.z), Vector3.UP)
	else:
		velocity = Vector3.ZERO
		move_and_slide()

func set_move_target(target: Vector3) -> void:
	nav.target_position = target

func _set_selected(v: bool) -> void:
	is_selected = v
	if selection_decal:
		selection_decal.visible = v
