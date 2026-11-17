extends Resource
class_name BuildingDefinition

## Description of a building that can be constructed.

## Identifier used by signals and prerequisites.
@export var id: StringName = &""
## Text shown in the build menu.
@export var label: String = ""
## Scene that is instantiated when the building is placed.
@export var scene: PackedScene
## Optional icon for the build menu.
@export var icon: Texture2D
## Tooltip shown in the build menu.
@export_multiline var description: String = ""

## Resources needed to construct the building: [code]{resource_id: amount}[/code].
@export var costs : Dictionary = {}

## Ids of buildings that have to exist before this one is available.
@export var requires: Array[StringName] = []

## Abstract tags that have to be unlocked before this one is available.
## The game defines the tags and calls [method Node.unlock_tag] on the world.
@export var unlocked_by: Array[StringName] = []

## Abilities offered while this building is selected and constructed.
@export var abilities: Array[AbilityDefinition] = []
