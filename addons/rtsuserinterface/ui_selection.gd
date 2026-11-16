extends Resource
class_name UISelection

## Description of the current selection displayed by [RTSUserInterface].
##
## The interface only renders the text lines and the optional image. The game
## decides what the selection means.

## Headline, usually the name of the selected object.
@export var title: String = ""
## Optional image of the selected object.
@export var icon: Texture2D
## Additional lines below the title, for example life, cargo or amount left.
@export var details: Array[String] = []


static func make(
	title: String,
	icon: Texture2D = null,
	details: Array = []
) -> UISelection:
	var selection := UISelection.new()
	selection.title = title
	selection.icon = icon
	selection.details.assign(details)
	return selection
