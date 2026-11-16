extends StaticBody3D
class_name Building

## Emitted once the construction site is finished.
signal construction_completed

@export var type : String = "x"
@export var abilities : Array[String] = []
var build_progress = 0
var build_end = 100
var constructed : bool = false

func _ready() -> void:
	$SelectionUnit.team = "blue"
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func place():
	$ContructionMesh.visible = true
	$MeshInstance3D.visible = false
	

func interaction() -> bool:
	if constructed:
		return true
	build_progress += 25
	if build_progress >= build_end:
		constructed = true
		$ContructionMesh.visible = false
		$MeshInstance3D.visible = true
		construction_completed.emit()
		return true
	return false


func is_constructed() -> bool:
	return constructed


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
