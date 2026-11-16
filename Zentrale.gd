extends Building
class_name Zentrale

## Main building. Pioneers deliver harvested resources here.

## Emitted when a pioneer hands in resources. The world listens to this and
## keeps the totals per team.
signal resource_deposited(resource_type: StringName, amount: int, team: String)


func _ready() -> void:
	super()
	add_to_group("resource_dropoff")


## Accepts a delivery from a pioneer. Only finished buildings accept anything.
func deposit(resource_type: StringName, amount: int, team: String) -> void:
	if not constructed or amount <= 0:
		return
	resource_deposited.emit(resource_type, amount, team)
