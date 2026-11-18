extends StaticBody3D
class_name Building

## Emitted once the construction site is finished.
signal construction_completed
## Emitted when this building is destroyed.
signal destroyed
## Emitted on each successful repair tick.
signal repaired

@export var type : String = "x"
@export var abilities : Array[String] = []
## Team string used by agents when deciding whether this is an enemy.
@export var team : String = "blue"
## Hit points. Agents use take_damage() to attack buildings.
@export var max_hp : int = 200
var hp : int = 200
## HP restored per interaction tick when a friendly unit repairs this building.
@export var repair_amount : int = 25
var build_progress = 0
var build_end = 100
var constructed : bool = false

func _ready() -> void:
	$SelectionUnit.team = team
	hp = max_hp
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func place():
	$ContructionMesh.visible = true
	$MeshInstance3D.visible = false
	

## Called by allied agents in INTERACT state: finish construction or repair.
## Returns true when no more work is needed so the agent can return to IDLE.
func interaction() -> bool:
	if not constructed:
		build_progress += 25
		if build_progress >= build_end:
			constructed = true
			$ContructionMesh.visible = false
			$MeshInstance3D.visible = true
			construction_completed.emit()
		else:
			return false

	if hp >= max_hp:
		return true
	hp = mini(hp + repair_amount, max_hp)
	repaired.emit()
	return hp >= max_hp


func is_constructed() -> bool:
	return constructed


## Agents and projectiles call this to damage the building.
func take_damage(amount: Variant) -> void:
	hp -= int(amount)
	if hp <= 0:
		_destroy()


func _destroy() -> void:
	var selection_unit := get_node_or_null("SelectionUnit")
	if selection_unit != null and selection_unit.has_method("unregister"):
		selection_unit.call("unregister")
	destroyed.emit()
	queue_free()


## Team that owns this building, taken from its selection unit.
func get_team() -> String:
	var selection_unit = get_node_or_null("SelectionUnit")
	if selection_unit == null:
		return ""
	return str(selection_unit.team)


func _on_selection_unit_selected() -> void:
	print("kaserne selected")


func _on_selection_unit_deselected() -> void:
	print("kaserne deselected")
