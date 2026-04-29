extends Node3D
class_name GameResource

@onready var visual: Node3D = $Visual
@onready var hitbox: Node3D = $Hitbox

@export var vorkommen: int = 100
@export var infinite: bool = true
@export var regen_value: int = 1
var abbau: int = 0  

var last_step: int = 10

func _ready() -> void:
	add_to_group("resources")
	update_visual()


func on_resource_timer() -> void:
	mine(1)
	if infinite:
		regen()
	update_visual()

func mine(amount: int) -> void:
	abbau += amount
	abbau = clamp(abbau, 0, vorkommen)

	if abbau >= vorkommen and infinite != false:
		on_depleted()
		
func regen() -> void:
	if abbau - regen_value > 0:
		abbau -= regen_value
		abbau = clamp(abbau, 0, vorkommen)

func update_visual() -> void:
	var remaining_ratio := float(vorkommen - abbau) / float(vorkommen)
	var step := int(floor(remaining_ratio * 10.0))  # 0–10

	# nur updaten wenn sich Step geändert hat
	if step != last_step:
		last_step = step

		var scale_factor := step / 10.0
		scale_factor = max(scale_factor, 0.1) # nie komplett unsichtbar

		visual.scale = Vector3.ONE * scale_factor

		print("Resource Step:", step, " Scale:", scale_factor)


func on_depleted() -> void:
	print("Resource leer")
	queue_free()
