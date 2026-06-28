class_name WorldController extends Node3D

@export_group("Field Config")
@export var field_tiles: Vector2i = Vector2i(64, 64)
@export var tile_world_size: float = 2.0
@export var auto_rebuild_on_ready: bool = true

@onready var ground: MeshInstance3D = $Field/Ground
@onready var ground_collision: CollisionShape3D = $Field/GroundBody/Collision
@onready var nav_region: NavigationRegion3D = $NavRegion

func _ready() -> void:
	if auto_rebuild_on_ready:
		rebuild_field()

func configure_field(new_tiles: Vector2i, new_tile_size: float) -> void:
	field_tiles = Vector2i(max(8, new_tiles.x), max(8, new_tiles.y))
	tile_world_size = max(0.25, new_tile_size)
	rebuild_field()

func rebuild_field() -> void:
	var world_size := Vector2(field_tiles.x, field_tiles.y) * tile_world_size
	
	var plane := PlaneMesh.new()
	plane.size = world_size
	ground.mesh = plane
	ground.position = Vector3.ZERO
	
	var shape := BoxShape3D.new()
	shape.size = Vector3(world_size.x, 0.2, world_size.y)
	ground_collision.shape = shape
	ground_collision.position = Vector3(0.0, -0.1, 0.0)
	_rebuild_navigation_mesh()

func _rebuild_navigation_mesh() -> void:
	var src := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(NavigationMesh.new(), src, self)

	var nav_mesh := NavigationMesh.new()
	nav_mesh.cell_size = 0.5
	nav_mesh.cell_height = 0.2
	nav_mesh.agent_radius = 0.6
	nav_mesh.agent_height = 2.0
	nav_mesh.agent_max_climb = 0.6
	nav_mesh.agent_max_slope = 45.0
	NavigationServer3D.bake_from_source_geometry_data(nav_mesh, src)

	nav_region.navigation_mesh = nav_mesh
