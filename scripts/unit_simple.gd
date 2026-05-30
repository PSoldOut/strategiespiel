extends CharacterBody3D

enum ENUM_ACTION_STATE {
	IDLE,	MOVE,	CHASE,	ATTACK,	SEARCH
}
enum ENUM_PLAYER_TYPE {
	NPC,	COMPUTER,	PLAYER1,	PLAYER2,	PLAYER3,	PLAYER4
}
enum TEAM_COLOR_THEME {
	NONE,	WHITE,	RED,	BLUE,	GREEN,	YELLOW,	BLACK
}

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var detection_area: Area3D = $Area3D

## Auswahl-Effekt
@export var selection_glow_color: Color = Color(0.95, 0.85, 0.15, 1.0)
@export var selection_ring_color: Color = Color(0.95, 0.85, 0.15, 0.85)
@export var selection_ring_radius: float = 0.75
@export var selection_ring_width: float = 0.08
@export var drag_selection: DragSelection
##

var _base_material: StandardMaterial3D
var _selected_material: StandardMaterial3D
var _selection_ring: MeshInstance3D
var _pulse_time: float = 0.0

var current_action_state: ENUM_ACTION_STATE
var current_owner: ENUM_PLAYER_TYPE
var has_been_selected: bool

var max_hp: int
var current_hp: int

var movement_speed: float

var attack_damage: float

var attack_range: float
var detection_range: float

var attack_speed: float
var attack_cooldown: float

var target = null

func _init_inner_values():
	current_owner = ENUM_PLAYER_TYPE.NPC
	has_been_selected = false
	
	max_hp = 100
	current_hp = max_hp
	
	movement_speed = 10.0
	velocity = Vector3.ZERO
	
	attack_damage = 10.0
	
	attack_range = 2.0
	detection_range = 10.0
	
	attack_speed = 1.0
	attack_cooldown = 1.0
	
	_prepare_materials()
	_create_selection_ring()
	_apply_selection_visuals(false)

func _ready() -> void:
	_init_inner_values()

func _unhandled_input(event: InputEvent) -> void:
	if not has_been_selected:
		return
	
	if event.is_action_pressed("ui_accept"):
		var random_position := Vector3(
			randf_range(-20.0, 20.0),
			global_position.y,
			randf_range(-20.0, 20.0)
		)
		nav_agent.set_target_position(random_position)
		current_action_state = ENUM_ACTION_STATE.MOVE

func _prepare_materials():
	pass
	
func _create_selection_ring():
	pass
	
func _apply_selection_visuals(active: bool):
	pass

func _physics_process(delta: float) -> void:
	move_and_slide()

func select():
	has_been_selected = true
	mesh.scale = Vector3(1.2, 1.2, 1.2)

func deselect():
	has_been_selected = false
	mesh.scale = Vector3(1.0, 1.0, 1.0)

func update_team_color():
	var material = mesh.get_active_material(0)
	
	match current_owner:
		ENUM_PLAYER_TYPE.NPC:
			material.albedo_color = Color(0.3, 0.3, 0.3, 1.0)

		ENUM_PLAYER_TYPE.COMPUTER:
			material.albedo_color = Color(0.6, 0.6, 0.6, 1.0)

		ENUM_PLAYER_TYPE.PLAYER1:
			material.albedo_color = Color(0.0, 0.6, 0.6, 1.0)	
		
		ENUM_PLAYER_TYPE.PLAYER2:
			material.albedo_color = Color(1.0, 0.0, 0, 1.0)	

		ENUM_PLAYER_TYPE.PLAYER3:
			material.albedo_color = Color(1.0, 1.0, 0, 1.0)	

		ENUM_PLAYER_TYPE.PLAYER4:
			material.albedo_color = Color(0.7, 0.3, 1.0, 1.0)	

func move_to_target():
	var destination = nav_agent.get_next_path_position()
	var direction = (destination - global_position).normalized()
	velocity = direction * movement_speed
	
func handle_move():
	if nav_agent.is_navigation_finished():
		current_action_state = ENUM_ACTION_STATE.IDLE
		target = null
		return

	move_to_target()

func _on_drag_selection_unit_selected() -> void:
	select()

func _on_drag_selection_unit_deselected() -> void:
	deselect()
	
func _on_timer_timeout() -> void:
	scan_for_enemys()
	$Timer.start()

func scan_for_enemys():
	if target != null or self.current_action_state == ENUM_ACTION_STATE.MOVE or self.current_action_state == ENUM_ACTION_STATE.ATTACK:
		return
	for body in detection_area.get_overlapping_bodies():
		if body == self:
			continue
			
		if !body.has_method("take_damage"):
			continue
			
		if body.current_owner == current_owner:
			continue
			
		target = body
		current_action_state = ENUM_ACTION_STATE.CHASE
