extends Node3D
class_name WeaponSchwertSchild

@export_group("Node Paths")
@export var shield_path: NodePath
@export var sword_path: NodePath

@export_group("Idle")
@export var idle_speed: float = 2.0
@export var idle_offset_strength: float = 0.03
@export var idle_rot_strength: float = deg_to_rad(2.0)

@export_group("Move")
@export var move_speed: float = 5.0
@export var move_offset_strength: float = 0.06
@export var move_rot_strength: float = deg_to_rad(5.0)

@export_group("Attack")
@export var attack_duration: float = 0.32
@export var sword_attack_angle: float = deg_to_rad(70.0)
@export var sword_attack_twist: float = deg_to_rad(18.0)
@export var sword_forward_offset: float = 0.18
@export var shield_guard_offset: float = 0.08
@export var shield_guard_angle: float = deg_to_rad(10.0)

@export_group("Return")
@export var return_speed: float = 12.0

var _shield: Node3D
var _sword: Node3D

var _shield_base_pos: Vector3
var _shield_base_rot: Vector3
var _sword_base_pos: Vector3
var _sword_base_rot: Vector3

var _time: float = 0.0
var _is_moving: bool = false
var _attacking: bool = false
var _attack_timer: float = 0.0

func _ready() -> void:
	_shield = get_node_or_null(shield_path) as Node3D
	_sword = get_node_or_null(sword_path) as Node3D

	if _shield == null:
		push_error("WeaponSchwertSchild: shield node not found")
	if _sword == null:
		push_error("WeaponSchwertSchild: sword node not found")

	if _shield != null:
		_shield_base_pos = _shield.position
		_shield_base_rot = _shield.rotation

	if _sword != null:
		_sword_base_pos = _sword.position
		_sword_base_rot = _sword.rotation

func set_moving(is_moving: bool) -> void:
	_is_moving = is_moving

func update_animation(delta: float) -> void:
	_time += delta

	if _attacking:
		_update_attack(delta)
	else:
		if _is_moving:
			_update_move(delta)
		else:
			_update_idle(delta)

func play_attack() -> void:
	_attacking = true
	_attack_timer = 0.0

func _update_idle(delta: float) -> void:
	var wave := sin(_time * idle_speed)
	var wave_half := sin(_time * idle_speed + 0.7)

	if _shield != null:
		var pos := _shield_base_pos
		var rot := _shield_base_rot

		pos.y += wave * idle_offset_strength
		rot.z += wave * idle_rot_strength * 0.5
		rot.x += wave_half * idle_rot_strength * 0.25

		_shield.position = _shield.position.lerp(pos, return_speed * delta)
		_shield.rotation = _shield.rotation.lerp(rot, return_speed * delta)

	if _sword != null:
		var pos := _sword_base_pos
		var rot := _sword_base_rot

		pos.y += -wave * idle_offset_strength * 0.6
		rot.z += -wave * idle_rot_strength
		rot.x += wave_half * idle_rot_strength * 0.4

		_sword.position = _sword.position.lerp(pos, return_speed * delta)
		_sword.rotation = _sword.rotation.lerp(rot, return_speed * delta)

func _update_move(delta: float) -> void:
	var wave := sin(_time * move_speed)
	var wave2 := sin(_time * move_speed + PI)

	if _shield != null:
		var pos := _shield_base_pos
		var rot := _shield_base_rot

		pos.y += abs(wave) * move_offset_strength
		pos.x += wave * move_offset_strength * 0.35
		rot.z += wave * move_rot_strength * 0.5
		rot.x += abs(wave) * move_rot_strength * 0.25

		_shield.position = _shield.position.lerp(pos, return_speed * delta)
		_shield.rotation = _shield.rotation.lerp(rot, return_speed * delta)

	if _sword != null:
		var pos := _sword_base_pos
		var rot := _sword_base_rot

		pos.y += abs(wave2) * move_offset_strength
		pos.x += wave2 * move_offset_strength * 0.45
		rot.z += wave2 * move_rot_strength
		rot.x += abs(wave2) * move_rot_strength * 0.35

		_sword.position = _sword.position.lerp(pos, return_speed * delta)
		_sword.rotation = _sword.rotation.lerp(rot, return_speed * delta)

func _update_attack(delta: float) -> void:
	_attack_timer += delta

	var t := _attack_timer / attack_duration
	if t >= 1.0:
		_attacking = false
		_attack_timer = 0.0
		return

	# 0..1 vorwärts, dann wieder zurück
	var attack_phase := 0.0
	if t < 0.5:
		attack_phase = t / 0.5
	else:
		attack_phase = 1.0 - ((t - 0.5) / 0.5)

	if _shield != null:
		var shield_pos := _shield_base_pos
		var shield_rot := _shield_base_rot

		# Schild leicht anheben / vorsetzen
		shield_pos.z -= shield_guard_offset * attack_phase
		shield_pos.x += shield_guard_offset * 0.25 * attack_phase
		shield_rot.y += shield_guard_angle * attack_phase
		shield_rot.x += shield_guard_angle * 0.4 * attack_phase

		_shield.position = shield_pos
		_shield.rotation = shield_rot

	if _sword != null:
		var sword_pos := _sword_base_pos
		var sword_rot := _sword_base_rot

		# Schlag von rechts nach vorne
		sword_pos.z -= sword_forward_offset * attack_phase
		sword_rot.y -= sword_attack_angle * attack_phase
		sword_rot.z -= sword_attack_twist * attack_phase
		sword_rot.x += sword_attack_twist * 0.35 * attack_phase

		_sword.position = sword_pos
		_sword.rotation = sword_rot
