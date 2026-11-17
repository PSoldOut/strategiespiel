extends Resource
class_name AbilityDefinition

## Data-only base class for something a selected building or unit can do.
## Concrete subclasses decide what happens when the ability is used.

@export var id: StringName = &""
@export var label: String = ""
@export var icon: Texture2D
@export_multiline var description: String = ""
## Resources consumed when the ability is used: [code]{resource_id: amount}[/code].
@export var costs: Dictionary = {}
## Reserved for timed training. A value of 0 means instant execution.
@export var duration: float = 0.0
@export var requirements: Array[ContentRequirement] = []
