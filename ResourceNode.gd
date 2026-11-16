extends StaticBody3D
class_name ResourceNode

## Harvestable resource deposit, for example a tree. Pioneers gather from it
## and deliver the harvested amount to a dropoff building.

## Emitted when the last unit has been harvested. The node removes itself.
signal depleted

## Resource type that is added to the inventory when this is harvested.
@export var resource_id: StringName = &"wood"
## Amount that is still available.
@export var amount: int = 2000
## Image shown in the UI when this deposit is selected.
@export var icon: Texture2D

var _depleted := false


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
		depleted.emit()
		queue_free()
	return taken
