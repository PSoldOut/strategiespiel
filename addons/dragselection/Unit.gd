extends Node3D
class_name SelectionUnit
signal selected
signal deselected

@export var drag_selection : DragSelection
@export var team : String
@export var unit : Node3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
	
func unregister():
	drag_selection.unregister_unit(self)

func set_drag_selection(ds : DragSelection):
	drag_selection = ds
	
func select():
	selected.emit()
	
func deselect():
	deselected.emit()
	
func get_unit():
	return get_parent()
	
func set_team(team : String):
	self.team = team
