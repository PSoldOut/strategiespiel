@tool
class_name MapPlaceable
extends Resource

## One object that the map generator can place.
##
## The plugin does not know any game classes. A placeable simply points at a
## scene and describes how it should appear in the palette.

## Text shown in the object dropdown.
@export var label: String = "Objekt"
## Palette group, also used as the folder name inside the saved map.
@export var category: String = "Objekte"
## Scene that is instanced when the user places this object.
@export var scene: PackedScene
## When enabled the lowest visible mesh of the scene is placed on the ground.
## This works for trees as well as for buildings whose origin is centered.
@export var auto_ground_offset: bool = true
## Manual vertical offset, only used when [member auto_ground_offset] is off.
@export var vertical_offset: float = 0.0
