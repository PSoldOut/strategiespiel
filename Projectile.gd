extends Area3D
class_name Projectile

## Homing projectile used by [Tower]. It is a real scene with a mesh and a
## collision shape, so it can hit units on its way to the target.

var speed := 25.0
var damage := 10.0
var shooter_team := ""
var target: Node3D
var lifetime := 6.0

var _hit := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func setup(
	new_target: Node3D,
	team: String,
	amount: float,
	travel_speed: float
) -> void:
	target = new_target
	shooter_team = team
	damage = amount
	speed = travel_speed


func _physics_process(delta: float) -> void:
	if _hit:
		return

	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return

	if not is_instance_valid(target) or target.is_queued_for_deletion():
		queue_free()
		return

	var aim_point := target.global_position + Vector3(0.0, 0.8, 0.0)
	var offset := aim_point - global_position
	var step := speed * delta

	if offset.length() <= step:
		global_position = aim_point
		_apply_hit(target)
		return

	global_position += offset.normalized() * step


func _on_body_entered(body: Node) -> void:
	if _hit or body == null:
		return
	if not body.has_method("take_damage"):
		return
	var body_team = body.get("team")
	if body_team != null and str(body_team) == shooter_team:
		return
	_apply_hit(body)


func _apply_hit(body: Node) -> void:
	if _hit:
		return
	_hit = true
	if is_instance_valid(body) and body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()
