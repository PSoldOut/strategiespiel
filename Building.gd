extends StaticBody3D
class_name Building

@export var type : String = "x"
@export var abilities : Array[String] = []
var build_progress = 0
var build_end = 100

func _ready() -> void:
	$SelectionUnit.team = "blue"
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func place():
	$ContructionMesh.visible = true
	$MeshInstance3D.visible = false
	

func interaction() -> bool:
	build_progress += 25
	if build_progress >= build_end:
		$ContructionMesh.visible = false
		$MeshInstance3D.visible = true
		return true
	return false


func _on_selection_unit_selected() -> void:
	print("kaserne selected")


func _on_selection_unit_deselected() -> void:
	print("kaserne deselected")
