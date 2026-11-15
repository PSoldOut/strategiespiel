extends Resource
class_name UIEntry

## A single generic entry displayed by [RTSUserInterface].

## Identifier that is emitted when the entry is activated.
@export var id: StringName = &""
## Text shown on the entry. Falls back to [member id] when empty.
@export var label: String = ""
## Optional icon.
@export var icon: Texture2D
## When true the entry is shown but cannot be activated.
@export var disabled := false
## Tooltip text, also useful for requirement hints.
@export var tooltip: String = ""


static func make(
	id: StringName,
	label: String,
	icon: Texture2D = null,
	disabled := false,
	tooltip := ""
) -> UIEntry:
	var entry := UIEntry.new()
	entry.id = id
	entry.label = label
	entry.icon = icon
	entry.disabled = disabled
	entry.tooltip = tooltip
	return entry
