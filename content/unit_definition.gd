extends Resource
class_name UnitDefinition

## Data-only description of a spawnable unit.

@export var id: StringName = &""
@export var label: String = ""
@export var scene: PackedScene
@export var icon: Texture2D
@export_multiline var description: String = ""
@export var abilities: Array[AbilityDefinition] = []
