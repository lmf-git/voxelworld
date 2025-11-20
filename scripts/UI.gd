extends Control

## UI controller for the voxel world

@onready var stats_label: Label = $Panel/VBoxContainer/StatsLabel
@onready var controls_label: Label = $Panel/VBoxContainer/ControlsLabel

var voxel_world: SphericalVoxelWorld
var camera: Camera3D

func _ready() -> void:
	# Find voxel world and camera
	voxel_world = get_parent().get_node("SphericalVoxelWorld")
	camera = get_parent().get_node("SphericalVoxelWorld/PlayerCamera")

	# Setup controls text
	controls_label.text = """Controls:
WASD - Move
Mouse - Look
Click - Destroy Terrain
Shift+Click - Add Terrain
Space - Up | Ctrl - Down
Shift (hold) - Speed Boost
ESC - Toggle Mouse Capture
"""

	# Connect buttons
	$Panel/VBoxContainer/ButtonContainer/RegenerateButton.pressed.connect(_on_regenerate_pressed)
	$Panel/VBoxContainer/ButtonContainer/AddTerrainButton.pressed.connect(_on_add_terrain_pressed)
	$Panel/VBoxContainer/ButtonContainer/RemoveTerrainButton.pressed.connect(_on_remove_terrain_pressed)

func _process(_delta: float) -> void:
	update_stats()

func update_stats() -> void:
	if not voxel_world or not voxel_world.terrain_mesh_instance:
		return

	var terrain_mesh := voxel_world.terrain_mesh_instance.mesh as ArrayMesh
	var water_mesh := voxel_world.water_mesh_instance.mesh as ArrayMesh

	var terrain_triangles := 0
	var water_triangles := 0

	if terrain_mesh and terrain_mesh.get_surface_count() > 0:
		var arrays := terrain_mesh.surface_get_arrays(0)
		if arrays and arrays[Mesh.ARRAY_VERTEX]:
			terrain_triangles = arrays[Mesh.ARRAY_VERTEX].size() / 3

	if water_mesh and water_mesh.get_surface_count() > 0:
		var arrays := water_mesh.surface_get_arrays(0)
		if arrays and arrays[Mesh.ARRAY_VERTEX]:
			water_triangles = arrays[Mesh.ARRAY_VERTEX].size() / 3

	var cam_pos := camera.global_position if camera else Vector3.ZERO

	stats_label.text = "Terrain Triangles: %d\nWater Triangles: %d\nPosition: (%.1f, %.1f, %.1f)\nFPS: %d" % [
		terrain_triangles,
		water_triangles,
		cam_pos.x,
		cam_pos.y,
		cam_pos.z,
		Engine.get_frames_per_second()
	]

func _on_regenerate_pressed() -> void:
	if voxel_world:
		voxel_world.regenerate()

func _on_add_terrain_pressed() -> void:
	if camera and voxel_world:
		var ray_origin := camera.global_position
		var ray_direction := -camera.transform.basis.z
		var result := voxel_world.raycast_voxel(ray_origin, ray_direction, 150.0)
		if result.hit:
			voxel_world.modify_terrain(result.voxel_pos, 2, true)

func _on_remove_terrain_pressed() -> void:
	if camera and voxel_world:
		var ray_origin := camera.global_position
		var ray_direction := -camera.transform.basis.z
		var result := voxel_world.raycast_voxel(ray_origin, ray_direction, 150.0)
		if result.hit:
			voxel_world.modify_terrain(result.voxel_pos, 2, false)
