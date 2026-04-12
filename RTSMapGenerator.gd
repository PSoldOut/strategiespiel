extends RefCounted
class_name RTSMapGenerator

enum CellType {
	EMPTY,
	PLAYER_START,
	RESOURCE1,
	RESOURCE2,
	ROCK
}

var subtile_size: int = 64
var player_count: int = 2

var quadrant_data: Array = []
var full_map_data: Array = []


func generate() -> void:
	var tiles_per_axis: int = player_count+1   # 🔥 zentrale Änderung
	
	var full_size: int = subtile_size * tiles_per_axis
	
	# Basis Quadrant bleibt immer gleich groß
	quadrant_data = create_empty_map(subtile_size, subtile_size)
	generate_quadrant(quadrant_data)
	
	# Gesamtmap
	full_map_data = create_empty_map(full_size, full_size)
	build_full_map(quadrant_data, tiles_per_axis)


func get_quadrant() -> Array:
	return duplicate_map(quadrant_data)


func get_full_map() -> Array:
	return duplicate_map(full_map_data)


# -------------------------------
# GENERATION
# -------------------------------
func generate_quadrant(q: Array) -> void:
	var size: int = q.size()

	set_cell_safe(q, 4, 4, CellType.PLAYER_START)
	set_cell_safe(q, 10, 6, CellType.RESOURCE1)
	set_cell_safe(q, 6, 10, CellType.RESOURCE2)

	for y in range(size):
		for x in range(size):
			if q[y][x] != CellType.EMPTY:
				continue

			if x < 12 and y < 12:
				continue

			if (x * y) % 11 == 0 or (x + y) % 17 == 0:
				q[y][x] = CellType.ROCK


# -------------------------------
# TILE REPLICATION
# -------------------------------
func build_full_map(q: Array, tiles_per_axis: int) -> void:
	var qh: int = q.size()
	var qw: int = q[0].size()

	for ty in range(tiles_per_axis):
		for tx in range(tiles_per_axis):
			
			var tile := get_transformed_tile(q, tx, ty)
			
			for y in range(qh):
				for x in range(qw):
					var gx := tx * qw + x
					var gy := ty * qh + y
					
					full_map_data[gy][gx] = tile[y][x]


func get_transformed_tile(q: Array, tx: int, ty: int) -> Array:
	# 🔥 einfache Symmetrie-Regel
	var mode := (tx + ty) % 4
	
	match mode:
		0:
			return duplicate_map(q)
		1:
			return mirror_horizontal(q)
		2:
			return mirror_vertical(q)
		3:
			return rotate_180(q)
	
	return duplicate_map(q)


# -------------------------------
# HELPERS
# -------------------------------
func create_empty_map(width: int, height: int) -> Array:
	var result: Array = []
	for y in range(height):
		var row: Array = []
		for x in range(width):
			row.append(CellType.EMPTY)
		result.append(row)
	return result


func duplicate_map(source: Array) -> Array:
	var result: Array = []
	for row in source:
		result.append(row.duplicate())
	return result


func mirror_horizontal(source: Array) -> Array:
	var h: int = source.size()
	var w: int = source[0].size()
	var result: Array = create_empty_map(w, h)

	for y in range(h):
		for x in range(w):
			result[y][w - 1 - x] = source[y][x]

	return result


func mirror_vertical(source: Array) -> Array:
	var h: int = source.size()
	var w: int = source[0].size()
	var result: Array = create_empty_map(w, h)

	for y in range(h):
		for x in range(w):
			result[h - 1 - y][x] = source[y][x]

	return result


func rotate_180(source: Array) -> Array:
	var h: int = source.size()
	var w: int = source[0].size()
	var result: Array = create_empty_map(w, h)

	for y in range(h):
		for x in range(w):
			result[h - 1 - y][w - 1 - x] = source[y][x]

	return result


func set_cell_safe(grid: Array, x: int, y: int, value: int) -> void:
	if y >= 0 and y < grid.size() and x >= 0 and x < grid[y].size():
		grid[y][x] = value
