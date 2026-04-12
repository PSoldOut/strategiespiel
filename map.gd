extends Node2D

@onready var preview: RTSMapPreview = $RTSMapPreview

var generator := RTSMapGenerator.new()
var show_full_map: bool = true

func _ready() -> void:
	generator.generate()
	update_preview()
	call_deferred("_fit_preview_camera")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			show_full_map = !show_full_map
			update_preview()
			call_deferred("_fit_preview_camera")


func update_preview() -> void:
	if show_full_map:
		preview.set_map(generator.get_full_map())
		print("View: Full Map")
	else:
		preview.set_map(generator.get_quadrant())
		print("View: Quadrant")


func _fit_preview_camera() -> void:
	preview.fit_camera_to_map()
