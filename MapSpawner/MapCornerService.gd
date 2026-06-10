extends RefCounted
class_name MapCornerService

static func make_flat_corners(height: float) -> Dictionary:
	return {
		"sw": float(height),
		"se": float(height),
		"nw": float(height),
		"ne": float(height)
	}


static func recalculate_auto_ramps(map_data: Array) -> void:
	AutoRampBuilderAvg.recalculate_auto_ramps(map_data)


static func is_cell_flat(cell: Dictionary) -> bool:
	var height: float = float(cell.get("height", 0.0))
	var corners: Dictionary = cell.get("corners", make_flat_corners(height))

	return (
		is_equal_approx(float(corners.get("sw", height)), height)
		and is_equal_approx(float(corners.get("se", height)), height)
		and is_equal_approx(float(corners.get("nw", height)), height)
		and is_equal_approx(float(corners.get("ne", height)), height)
	)
