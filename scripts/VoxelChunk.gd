class_name VoxelChunk
extends Node3D

## Individual voxel chunk with LOD support
## Handles mesh generation and LOD level management for a portion of the voxel world

#region Signals
signal chunk_generated()
signal lod_changed(new_lod: int)
#endregion

#region Exported Properties
@export_group("Chunk Configuration")
@export var chunk_size: int = 32
@export var max_lod_levels: int = 3
#endregion

#region Public Variables
var chunk_position: Vector3i  ## Position in chunk grid
var voxel_offset: Vector3i  ## Offset in global voxel coordinates
#endregion

#region Private Variables
var _voxels: PackedFloat32Array  ## Local voxel data
var _current_lod: int = 0  ## Current LOD level (0 = full detail)
var _lod_meshes: Array[ArrayMesh] = []  ## Meshes for each LOD level
var _mesh_instance: MeshInstance3D
var _marching_cubes: MarchingCubes
var _is_generated: bool = false
var _is_visible: bool = true
#endregion

#region Constants
const LOD_DISTANCES: Array[float] = [50.0, 150.0, 300.0, 500.0]  ## Distance thresholds for LOD levels
#endregion

#region Lifecycle Methods
func _ready() -> void:
	_initialize_chunk()

func _exit_tree() -> void:
	_cleanup()
#endregion

#region Initialization
func _initialize_chunk() -> void:
	# Create mesh instance
	_mesh_instance = MeshInstance3D.new()
	add_child(_mesh_instance)

	# Initialize marching cubes
	_marching_cubes = MarchingCubes.new()

	# Pre-allocate voxel array
	var total_voxels: int = chunk_size * chunk_size * chunk_size
	_voxels.resize(total_voxels)
	_voxels.fill(0.0)

	# Pre-allocate LOD mesh array
	_lod_meshes.resize(max_lod_levels)

func initialize(pos: Vector3i, offset: Vector3i) -> void:
	chunk_position = pos
	voxel_offset = offset
#endregion

#region Voxel Data Management
func set_voxel(x: int, y: int, z: int, value: float) -> void:
	if not _is_valid_coordinate(x, y, z):
		return

	var index: int = _get_voxel_index(x, y, z)
	_voxels[index] = value

func get_voxel(x: int, y: int, z: int) -> float:
	if not _is_valid_coordinate(x, y, z):
		return 0.0

	var index: int = _get_voxel_index(x, y, z)
	return _voxels[index]

func _is_valid_coordinate(x: int, y: int, z: int) -> bool:
	return x >= 0 and x < chunk_size and y >= 0 and y < chunk_size and z >= 0 and z < chunk_size

func _get_voxel_index(x: int, y: int, z: int) -> int:
	return x + y * chunk_size + z * chunk_size * chunk_size
#endregion

#region Mesh Generation
func generate_meshes(planet_radius: float, water_level: float, base_radius_multiplier: float, voxel_resolution: int, material: StandardMaterial3D = null) -> void:
	# Set material if provided
	if material:
		_mesh_instance.material_override = material

	# Generate mesh for each LOD level
	for lod_level in range(max_lod_levels):
		var stride: int = 1 << lod_level  # 1, 2, 4, 8...
		_lod_meshes[lod_level] = _generate_mesh_at_lod(lod_level, stride, planet_radius, water_level, base_radius_multiplier, voxel_resolution)

	# Set initial mesh to highest detail
	if _lod_meshes[0]:
		_mesh_instance.mesh = _lod_meshes[0]

	_is_generated = true
	chunk_generated.emit()

func _generate_mesh_at_lod(_lod_level: int, stride: int, planet_radius: float, water_level: float, base_radius_multiplier: float, voxel_resolution: int) -> ArrayMesh:
	var vertices: PackedVector3Array = []
	var colors: PackedColorArray = []
	var indices: PackedInt32Array = []

	var _effective_size: int = int(chunk_size / stride)  # Calculated for documentation, not currently used

	# Iterate through voxels with stride
	for z in range(0, chunk_size - stride, stride):
		for y in range(0, chunk_size - stride, stride):
			for x in range(0, chunk_size - stride, stride):
				_process_cube_at_stride(x, y, z, stride, vertices, colors, indices, planet_radius, water_level, base_radius_multiplier, voxel_resolution)

	if vertices.size() == 0:
		return null

	# Create mesh
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	# Generate normals for proper lighting
	var st: SurfaceTool = SurfaceTool.new()
	st.create_from(mesh, 0)
	st.generate_normals()

	return st.commit()

func _process_cube_at_stride(x: int, y: int, z: int, stride: int, vertices: PackedVector3Array, colors: PackedColorArray, indices: PackedInt32Array, planet_radius: float, water_level: float, base_radius_multiplier: float, voxel_resolution: int) -> void:
	# Get 8 corner values for this cube
	var cube_values: Array[float] = []
	cube_values.resize(8)

	var corner_offsets: Array[Vector3i] = [
		Vector3i(0, 0, 0),
		Vector3i(stride, 0, 0),
		Vector3i(stride, 0, stride),
		Vector3i(0, 0, stride),
		Vector3i(0, stride, 0),
		Vector3i(stride, stride, 0),
		Vector3i(stride, stride, stride),
		Vector3i(0, stride, stride)
	]

	for i in range(8):
		var offset: Vector3i = corner_offsets[i]
		cube_values[i] = get_voxel(x + offset.x, y + offset.y, z + offset.z)

	# Get cube corner positions in world space
	var cube_points: Array[Vector3] = []
	cube_points.resize(8)
	for i in range(8):
		var local_pos: Vector3i = Vector3i(x, y, z) + corner_offsets[i]
		var global_pos: Vector3i = voxel_offset + local_pos
		cube_points[i] = _voxel_to_world_space(global_pos, planet_radius, voxel_resolution)

	# Generate triangles using marching cubes
	var triangles: Array = _marching_cubes.polygonize(cube_points, cube_values, 0.0)

	if triangles.size() == 0:
		return

	# Add triangles to mesh arrays
	var base_index: int = vertices.size()
	for triangle in triangles:
		for vert in triangle:
			vertices.append(vert)
			var color: Color = _get_terrain_color(vert, cube_values, planet_radius, water_level, base_radius_multiplier)
			colors.append(color)

		indices.append(base_index)
		indices.append(base_index + 1)
		indices.append(base_index + 2)
		base_index += 3

func _voxel_to_world_space(voxel_pos: Vector3i, planet_radius: float, voxel_resolution: int) -> Vector3:
	var voxel_size: float = (planet_radius * 2.0) / float(voxel_resolution)
	var offset: float = planet_radius
	return Vector3(
		float(voxel_pos.x) * voxel_size - offset,
		float(voxel_pos.y) * voxel_size - offset,
		float(voxel_pos.z) * voxel_size - offset
	)

func _get_terrain_color(vert: Vector3, _cube_values: Array[float], planet_radius: float, water_level: float, base_radius_multiplier: float) -> Color:
	var height: float = vert.length()
	var water_radius: float = planet_radius * (base_radius_multiplier + water_level)

	# Underwater coloring
	if height < water_radius:
		var depth: float = (water_radius - height) / (planet_radius * 0.05)
		if depth > 0.5:
			return Color(0.05, 0.1, 0.3)  # Deep ocean
		else:
			return Color(0.1, 0.3, 0.6)  # Shallow water

	# Above water - height-based biomes
	var height_above_water: float = (height - water_radius) / (planet_radius * 0.15)

	if height_above_water > 0.8:
		return Color(0.95, 0.95, 1.0)  # Snow peaks
	elif height_above_water > 0.5:
		var mountain_variation: float = randf_range(0.45, 0.55)
		return Color(mountain_variation, mountain_variation, mountain_variation)  # Rocky mountains
	elif height_above_water > 0.3:
		return Color(0.2, 0.4, 0.2)  # Dark grass hills
	elif height_above_water > 0.1:
		return Color(0.3, 0.6, 0.3)  # Bright grass
	elif height_above_water > -0.05:
		return Color(0.8, 0.7, 0.5)  # Beach/sand
	elif height_above_water > -0.15:
		return Color(0.6, 0.5, 0.3)  # Muddy shallows
	else:
		return Color(0.1, 0.3, 0.2)  # Ocean floor
#endregion

#region LOD Management
func update_lod_for_distance(camera_position: Vector3) -> void:
	if not _is_generated:
		return

	var chunk_center: Vector3 = global_position
	var distance: float = camera_position.distance_to(chunk_center)

	# Determine appropriate LOD level
	var new_lod: int = 0
	for i in range(LOD_DISTANCES.size()):
		if distance > LOD_DISTANCES[i]:
			new_lod = i + 1
			if new_lod >= max_lod_levels:
				new_lod = max_lod_levels - 1
				break

	if new_lod != _current_lod:
		set_lod_level(new_lod)

func set_lod_level(lod: int) -> void:
	if lod < 0 or lod >= max_lod_levels:
		return

	if lod == _current_lod:
		return

	_current_lod = lod

	# Switch to appropriate mesh
	if _lod_meshes[_current_lod]:
		_mesh_instance.mesh = _lod_meshes[_current_lod]

	lod_changed.emit(_current_lod)

func get_current_lod() -> int:
	return _current_lod
#endregion

#region Visibility Management
func set_chunk_visible(is_visible: bool) -> void:
	_is_visible = is_visible
	_mesh_instance.visible = is_visible

func is_chunk_visible() -> bool:
	return _is_visible
#endregion

#region Cleanup
func _cleanup() -> void:
	_voxels.clear()
	_lod_meshes.clear()

	if _mesh_instance:
		_mesh_instance.queue_free()
#endregion
