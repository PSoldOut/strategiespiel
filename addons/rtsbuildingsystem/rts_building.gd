extends Node3D
class_name RTSBuilding

@export var main_area : Area3D
@export var ground_area1 : Area3D
@export var ground_area2 : Area3D
@export var ground_area3 : Area3D
@export var ground_area4 : Area3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
	
func get_main_area():
	return main_area

func get_ground_area1():
	return ground_area1
	
func get_ground_area2():
	return ground_area2
	
func get_ground_area3():
	return ground_area3
	
func get_ground_area4():
	return ground_area4
