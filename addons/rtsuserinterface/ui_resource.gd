extends Resource
class_name UIResource

## A single resource amount displayed by [RTSUserInterface].

## Identifier of the resource. The interface only forwards it, the game defines
## the meaning.
@export var id: StringName = &""
## Text shown next to the amount. Falls back to [member id] when empty.
@export var label: String = ""
## Amount that is displayed.
@export var amount: int = 0
## Optional icon shown left of the label.
@export var icon: Texture2D


static func make(
	id: StringName,
	label: String,
	amount: int = 0,
	icon: Texture2D = null
) -> UIResource:
	var resource := UIResource.new()
	resource.id = id
	resource.label = label
	resource.amount = amount
	resource.icon = icon
	return resource
