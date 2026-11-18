extends StaticBody3D
class_name ResourceNode

## Harvestable resource deposit, for example a tree. Pioneers gather from it
## and deliver the harvested amount to a dropoff building.
##
## A NavigationObstacle3D carves this deposit out of the navigation mesh so
## agents walk around it instead of through it.

## Emitted when the last unit has been harvested. The node removes itself.
signal depleted

## Resource type that is added to the inventory when this is harvested.
@export var resource_id: StringName = &"wood"
## Amount that is still available.
@export var amount: int = 2000
## Image shown in the UI when this deposit is selected.
@export var icon: Texture2D
## Radius of the baked navigation hole around this deposit.
@export var navigation_radius: float = 1.0
## Height of the baked navigation obstacle.
@export var navigation_height: float = 3.0

const NAVIGATION_OUTLINE_SEGMENTS := 12

var _depleted := false


func _ready() -> void:
	_add_navigation_obstacle()


## Small StaticBody3D colliders are not reliably baked as navigation holes.
## An explicit obstacle outline is parsed by NavigationMesh baking instead.
func _add_navigation_obstacle() -> void:
	if navigation_radius <= 0.0:
		return

	var outline := PackedVector3Array()
	for index in range(NAVIGATION_OUTLINE_SEGMENTS):
		var angle := TAU * float(index) / float(NAVIGATION_OUTLINE_SEGMENTS)
		outline.append(Vector3(
			cos(angle) * navigation_radius,
			0.0,
			sin(angle) * navigation_radius
		))

	var obstacle := NavigationObstacle3D.new()
	obstacle.name = "NavigationObstacle"
	obstacle.affect_navigation_mesh = true
	obstacle.carve_navigation_mesh = true
	obstacle.radius = navigation_radius
	obstacle.height = navigation_height
	obstacle.vertices = outline
	add_child(obstacle)


func can_gather() -> bool:
	return not _depleted and amount > 0


## Removes and returns up to [param requested] units from this deposit.
## When nothing is left the node is removed from the scene.
func harvest(requested: int) -> int:
	if requested <= 0 or not can_gather():
		return 0

	var taken := mini(requested, amount)
	amount -= taken
	if amount <= 0:
		_depleted = true
		_disable_navigation_source()
		depleted.emit()
		queue_free()
	return taken


## Stops this deposit from being parsed as navigation geometry before the
## node leaves the tree, so the following re-bake closes the carved hole.
func _disable_navigation_source() -> void:
	for child in find_children("*", "NavigationObstacle3D", true, false):
		var obstacle := child as NavigationObstacle3D
		obstacle.affect_navigation_mesh = false
		obstacle.get_parent().remove_child(obstacle)
		obstacle.queue_free()
	for child in find_children("*", "CollisionShape3D", true, false):
		(child as CollisionShape3D).disabled = true
