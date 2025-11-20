class_name SphericalVoxelWorld
extends Node3D

## Spherical voxel world with destructible terrain, caves, mountains, rivers and oceans
## Uses threaded generation for better performance

#region Signals
signal terrain_generation_started()
signal terrain_generation_progress(progress: float) # Used via call_deferred for thread safety
signal terrain_generation_completed()
signal terrain_modified(position: Vector3i, radius: int, added: bool)
signal mesh_update_started()
signal mesh_update_completed(terrain_triangles: int, water_triangles: int)
#endregion

#region Exported Properties
@export_group("Planet Configuration")
@export_range(10.0, 200.0, 1.0) var planet_radius: float = 50.0
@export_range(16, 128, 1) var voxel_resolution: int = 64
@export_range(0.0, 0.2, 0.01) var water_level: float = 0.02

@export_group("Noise Seeds")
@export var terrain_seed: int = 12345
@export var cave_seed: int = 67890
@export var mountain_seed: int = 11111
@export var river_seed: int = 22222

@export_group("Terrain Parameters")
@export_range(0.0, 2.0, 0.01) var continent_strength: float = 0.35
@export_range(0.0, 2.0, 0.01) var mountain_strength: float = 0.45
@export_range(0.0, 1.0, 0.01) var cave_threshold: float = 0.15
@export_range(0.0, 0.5, 0.01) var cave_min_depth: float = 0.1
@export_range(0.0, 1.0, 0.01) var river_threshold: float = 0.1

@export_group("Performance")
@export var use_threading: bool = true
@export var generate_on_ready: bool = true
#endregion

#region Private Variables
var _voxel_size: float
var _voxels: PackedFloat32Array
var _marching_cubes: MarchingCubes
var _terrain_noise: SimplexNoise3D
var _cave_noise: SimplexNoise3D
var _mountain_noise: SimplexNoise3D
var _river_noise: SimplexNoise3D

var _terrain_mesh_instance: MeshInstance3D
var _water_mesh_instance: MeshInstance3D
var _terrain_material: StandardMaterial3D
var _water_material: StandardMaterial3D

var _is_generating: bool = false
var _generation_thread: Thread
#endregion

#region Constants
const BASE_RADIUS_MULTIPLIER: float = 0.85
const WATER_DENSITY_MARKER: float = -10.0
const CONTINENT_SCALE: float = 2.0
const MOUNTAIN_SCALE: float = 4.0
const CAVE_SCALE: float = 6.0
const RIVER_SCALE: float = 3.0
#endregion

#region Lifecycle Methods
func _ready() -> void:
	_initialize()

	if generate_on_ready:
		generate_terrain()

func _exit_tree() -> void:
	_cleanup()
#endregion

#region Initialization
func _initialize() -> void:
	_voxel_size = (planet_radius * 2.0) / float(voxel_resolution)

	# Initialize voxel array
	_voxels = PackedFloat32Array()
	var total_voxels: int = voxel_resolution * voxel_resolution * voxel_resolution
	_voxels.resize(total_voxels)
	_voxels.fill(0.0)

	# Initialize noise generators
	_terrain_noise = SimplexNoise3D.new(terrain_seed)
	_cave_noise = SimplexNoise3D.new(cave_seed)
	_mountain_noise = SimplexNoise3D.new(mountain_seed)
	_river_noise = SimplexNoise3D.new(river_seed)

	# Initialize marching cubes
	_marching_cubes = MarchingCubes.new()

	# Create materials
	_create_materials()

	# Create mesh instances
	_terrain_mesh_instance = MeshInstance3D.new()
	_terrain_mesh_instance.name = "TerrainMesh"
	_terrain_mesh_instance.material_override = _terrain_material
	add_child(_terrain_mesh_instance)

	_water_mesh_instance = MeshInstance3D.new()
	_water_mesh_instance.name = "WaterMesh"
	_water_mesh_instance.material_override = _water_material
	add_child(_water_mesh_instance)

func _create_materials() -> void:
	# Terrain material
	_terrain_material = StandardMaterial3D.new()
	_terrain_material.vertex_color_use_as_albedo = true
	_terrain_material.roughness = 0.8
	_terrain_material.metallic = 0.2
	_terrain_material.cull_mode = BaseMaterial3D.CULL_BACK

	# Water material
	_water_material = StandardMaterial3D.new()
	_water_material.albedo_color = Color(0.0, 0.4, 0.9, 0.7)
	_water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_water_material.roughness = 0.1
	_water_material.metallic = 0.3
	_water_material.cull_mode = BaseMaterial3D.CULL_BACK

func _cleanup() -> void:
	if _generation_thread and _generation_thread.is_alive():
		_generation_thread.wait_to_finish()

	_voxels.clear()
#endregion

#region Public API
func generate_terrain() -> void:
	if _is_generating:
		push_warning("Terrain generation already in progress")
		return

	_is_generating = true
	terrain_generation_started.emit()
	print("Generating terrain...")

	if use_threading:
		_generation_thread = Thread.new()
		_generation_thread.start(_generate_terrain_threaded)
	else:
		_generate_terrain_data()
		_on_generation_complete()

func regenerate() -> void:
	generate_terrain()

func modify_terrain(voxel_pos: Vector3i, radius: int, add_terrain: bool = false) -> void:
	if _is_generating:
		return

	var modification_value: float = 10.0 if add_terrain else -10.0

	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			for dz in range(-radius, radius + 1):
				var dist: float = sqrt(float(dx * dx + dy * dy + dz * dz))
				if dist <= float(radius):
					var x: int = voxel_pos.x + dx
					var y: int = voxel_pos.y + dy
					var z: int = voxel_pos.z + dz

					var current_density: float = get_voxel(x, y, z)
					set_voxel(x, y, z, current_density + modification_value)

	terrain_modified.emit(voxel_pos, radius, add_terrain)
	call_deferred("_update_meshes_deferred")

func raycast_voxel(origin: Vector3, direction: Vector3, max_distance: float = 100.0) -> Dictionary:
	var step: float = _voxel_size * 0.5
	var dir: Vector3 = direction.normalized()
	var steps: int = int(max_distance / step)

	for i in range(steps):
		var point: Vector3 = origin + dir * (float(i) * step)
		var voxel_pos: Vector3i = world_to_voxel(point)

		var density: float = get_voxel(voxel_pos.x, voxel_pos.y, voxel_pos.z)

		if density > 0.0:
			return {
				"hit": true,
				"voxel_pos": voxel_pos,
				"world_pos": point,
				"distance": float(i) * step
			}

	return {"hit": false}
#endregion

#region Voxel Access
func get_voxel(x: int, y: int, z: int) -> float:
	var idx: int = _get_voxel_index(x, y, z)
	return _voxels[idx] if idx >= 0 else 0.0

func set_voxel(x: int, y: int, z: int, value: float) -> void:
	var idx: int = _get_voxel_index(x, y, z)
	if idx >= 0:
		_voxels[idx] = value

func _get_voxel_index(x: int, y: int, z: int) -> int:
	if x < 0 or x >= voxel_resolution or \
	   y < 0 or y >= voxel_resolution or \
	   z < 0 or z >= voxel_resolution:
		return -1
	return x + y * voxel_resolution + z * voxel_resolution * voxel_resolution
#endregion

#region Coordinate Conversion
func world_to_voxel(world_pos: Vector3) -> Vector3i:
	var offset: float = planet_radius
	return Vector3i(
		int(floor((world_pos.x + offset) / _voxel_size)),
		int(floor((world_pos.y + offset) / _voxel_size)),
		int(floor((world_pos.z + offset) / _voxel_size))
	)

func voxel_to_world(vx: int, vy: int, vz: int) -> Vector3:
	var offset: float = planet_radius
	return Vector3(
		float(vx) * _voxel_size - offset,
		float(vy) * _voxel_size - offset,
		float(vz) * _voxel_size - offset
	)
#endregion

#region Terrain Generation
func _generate_terrain_threaded() -> void:
	_generate_terrain_data()
	call_deferred("_on_generation_complete")

func _generate_terrain_data() -> void:
	var total_voxels: int = voxel_resolution * voxel_resolution * voxel_resolution
	var voxel_count: int = 0

	for x in range(voxel_resolution):
		for y in range(voxel_resolution):
			for z in range(voxel_resolution):
				_generate_voxel_density(x, y, z)
				voxel_count += 1

				# Emit progress every 5%
				var progress_interval: int = maxi(1, int(float(total_voxels) / 20.0))
				if voxel_count % progress_interval == 0:
					var progress: float = float(voxel_count) / float(total_voxels)
					call_deferred("emit_signal", "terrain_generation_progress", progress)

	_add_water_layer()

func _generate_voxel_density(x: int, y: int, z: int) -> void:
	var world_pos: Vector3 = voxel_to_world(x, y, z)
	var distance_from_center: float = world_pos.length()

	# Normalize position for noise sampling
	var nx: float = world_pos.x / planet_radius
	var ny: float = world_pos.y / planet_radius
	var nz: float = world_pos.z / planet_radius

	# Base spherical shape
	var base_radius: float = planet_radius * BASE_RADIUS_MULTIPLIER
	var density: float = base_radius - distance_from_center

	# Multi-octave continent noise
	var continent_noise: float = (
		_terrain_noise.noise(nx * CONTINENT_SCALE, ny * CONTINENT_SCALE, nz * CONTINENT_SCALE) * 0.5 +
		_terrain_noise.noise(nx * CONTINENT_SCALE * 2.0, ny * CONTINENT_SCALE * 2.0, nz * CONTINENT_SCALE * 2.0) * 0.25 +
		_terrain_noise.noise(nx * CONTINENT_SCALE * 4.0, ny * CONTINENT_SCALE * 4.0, nz * CONTINENT_SCALE * 4.0) * 0.125
	)

	# Mountain noise
	var mountain_noise_val: float = (
		_mountain_noise.noise(nx * MOUNTAIN_SCALE, ny * MOUNTAIN_SCALE, nz * MOUNTAIN_SCALE) * 0.6 +
		_mountain_noise.noise(nx * MOUNTAIN_SCALE * 2.0, ny * MOUNTAIN_SCALE * 2.0, nz * MOUNTAIN_SCALE * 2.0) * 0.3
	)

	# Apply terrain features
	var mountain_factor: float = maxf(0.0, continent_noise) * 1.5
	density += continent_noise * planet_radius * continent_strength
	density += mountain_noise_val * mountain_factor * planet_radius * mountain_strength

	# Cave generation
	density = _apply_caves(nx, ny, nz, density)

	# River valleys
	density = _apply_rivers(nx, ny, nz, continent_noise, density)

	set_voxel(x, y, z, density)

func _apply_caves(nx: float, ny: float, nz: float, density: float) -> float:
	# Only carve caves if we're significantly inside the terrain
	# This prevents surface gaps and holes visible from outside
	var depth_into_terrain: float = density
	var min_depth: float = planet_radius * cave_min_depth

	if depth_into_terrain < min_depth:
		return density  # Too close to surface, no caves

	var cave_noise1: float = _cave_noise.noise(nx * CAVE_SCALE, ny * CAVE_SCALE, nz * CAVE_SCALE)
	var cave_noise2: float = _cave_noise.noise(nx * CAVE_SCALE + 100.0, ny * CAVE_SCALE + 100.0, nz * CAVE_SCALE + 100.0)

	# Create caves where both noise values are within a threshold
	if abs(cave_noise1) < cave_threshold and abs(cave_noise2) < cave_threshold:
		density -= planet_radius * 0.3

	return density

func _apply_rivers(nx: float, ny: float, nz: float, continent_noise: float, density: float) -> float:
	var river_noise_val: float = _river_noise.noise(nx * RIVER_SCALE, ny * RIVER_SCALE, nz * RIVER_SCALE)

	if continent_noise > -0.1 and continent_noise < 0.3 and abs(river_noise_val) < river_threshold:
		density -= planet_radius * 0.08

	return density

func _add_water_layer() -> void:
	var water_radius: float = planet_radius * (BASE_RADIUS_MULTIPLIER + water_level)

	for x in range(voxel_resolution):
		for y in range(voxel_resolution):
			for z in range(voxel_resolution):
				var world_pos: Vector3 = voxel_to_world(x, y, z)
				var distance_from_center: float = world_pos.length()
				var current_density: float = get_voxel(x, y, z)

				if distance_from_center < water_radius and current_density < 0.0:
					set_voxel(x, y, z, WATER_DENSITY_MARKER)

func _on_generation_complete() -> void:
	if _generation_thread:
		_generation_thread.wait_to_finish()
		_generation_thread = null

	# Debug: Sample voxel values and find height range
	var sample_count: int = 0
	var positive_density: int = 0
	var negative_density: int = 0
	var water_voxels: int = 0
	var max_height: float = 0.0
	var min_density: float = 9999.0
	var max_density: float = -9999.0

	for i in range(200):
		var x: int = randi() % voxel_resolution
		var y: int = randi() % voxel_resolution
		var z: int = randi() % voxel_resolution
		var density: float = get_voxel(x, y, z)
		var world_pos: Vector3 = voxel_to_world(x, y, z)
		var height: float = world_pos.length()

		sample_count += 1
		if density > 0:
			positive_density += 1
			max_height = maxf(max_height, height)
		else:
			negative_density += 1
		if density < 0 and density > -50:
			water_voxels += 1

		max_density = maxf(max_density, density)
		min_density = minf(min_density, density)

	var water_radius: float = planet_radius * (BASE_RADIUS_MULTIPLIER + water_level)

	print("=== Terrain Generation Complete ===")
	print("  Positive density: ", positive_density, "/", sample_count)
	print("  Negative density: ", negative_density, "/", sample_count)
	print("  Water voxels: ", water_voxels, "/", sample_count)
	print("  Density range: ", min_density, " to ", max_density)
	print("  Max terrain height: ", max_height)
	print("  Water level: ", water_radius)
	print("  Base radius: ", planet_radius * BASE_RADIUS_MULTIPLIER)
	if max_height > water_radius:
		print("  ✓ Land exists above water!")
	else:
		print("  ✗ WARNING: No land above water level!")
	print("  Creating meshes...")

	_update_meshes()
	_is_generating = false
	terrain_generation_completed.emit()
	print("Complete!")
#endregion

#region Mesh Generation
func _update_meshes_deferred() -> void:
	_update_meshes()

func _update_meshes() -> void:
	mesh_update_started.emit()

	var terrain_data: Dictionary = _generate_terrain_mesh()

	# Update terrain mesh (includes water-colored areas)
	if terrain_data.vertices.size() > 0:
		var terrain_mesh: ArrayMesh = _create_mesh_from_data(terrain_data.vertices, terrain_data.colors)
		_terrain_mesh_instance.mesh = terrain_mesh

	# Hide water mesh (not used - water is shown via terrain vertex colors)
	_water_mesh_instance.mesh = null

	var terrain_tris: int = terrain_data.vertices.size() / 3
	mesh_update_completed.emit(terrain_tris, 0)

func _generate_terrain_mesh() -> Dictionary:
	var vertices: PackedVector3Array = []
	var colors: PackedColorArray = []
	const ISOLEVEL: float = 0.0

	for x in range(voxel_resolution - 1):
		for y in range(voxel_resolution - 1):
			for z in range(voxel_resolution - 1):
				var cube_data: Dictionary = _get_cube_data(x, y, z)
				var triangles: Array[Vector3] = _marching_cubes.polygonise(
					cube_data.points,
					cube_data.values,
					ISOLEVEL
				)

				for vert in triangles:
					vertices.append(vert)
					colors.append(_get_terrain_color(vert, cube_data.values))

	return {"vertices": vertices, "colors": colors}

func _generate_water_mesh() -> Dictionary:
	var vertices: PackedVector3Array = []
	var colors: PackedColorArray = []
	const ISOLEVEL: float = -5.0
	const WATER_COLOR: Color = Color(0.0, 0.4, 0.9, 0.7)

	for x in range(voxel_resolution - 1):
		for y in range(voxel_resolution - 1):
			for z in range(voxel_resolution - 1):
				var cube_data: Dictionary = _get_cube_data_clamped(x, y, z)

				if not _has_water(cube_data.values):
					continue

				var triangles: Array[Vector3] = _marching_cubes.polygonise(
					cube_data.points,
					cube_data.values,
					ISOLEVEL
				)

				for vert in triangles:
					vertices.append(vert)
					colors.append(WATER_COLOR)

	return {"vertices": vertices, "colors": colors}

func _get_cube_data(x: int, y: int, z: int) -> Dictionary:
	var points: Array[Vector3] = [
		voxel_to_world(x, y, z),
		voxel_to_world(x + 1, y, z),
		voxel_to_world(x + 1, y, z + 1),
		voxel_to_world(x, y, z + 1),
		voxel_to_world(x, y + 1, z),
		voxel_to_world(x + 1, y + 1, z),
		voxel_to_world(x + 1, y + 1, z + 1),
		voxel_to_world(x, y + 1, z + 1)
	]

	var values: Array[float] = [
		get_voxel(x, y, z),
		get_voxel(x + 1, y, z),
		get_voxel(x + 1, y, z + 1),
		get_voxel(x, y, z + 1),
		get_voxel(x, y + 1, z),
		get_voxel(x + 1, y + 1, z),
		get_voxel(x + 1, y + 1, z + 1),
		get_voxel(x, y + 1, z + 1)
	]

	return {"points": points, "values": values}

func _get_cube_data_clamped(x: int, y: int, z: int) -> Dictionary:
	var data: Dictionary = _get_cube_data(x, y, z)
	for i in range(data.values.size()):
		data.values[i] = maxf(-20.0, data.values[i])
	return data

func _has_water(values: Array[float]) -> bool:
	for val in values:
		if val < 0.0:
			return true
	return false

## Generate terrain color based on height above water level (biomes)
## Returns appropriate color for snow, mountains, grass, beaches, etc.
func _get_terrain_color(vert: Vector3, _cube_values: Array[float]) -> Color:
	var height: float = vert.length()
	var water_radius: float = planet_radius * (BASE_RADIUS_MULTIPLIER + water_level)

	# Normalize height relative to water level
	var height_above_water: float = (height - water_radius) / (planet_radius * 0.15)

	# Check if this is underwater (based on height, not density)
	# Water level is at water_radius
	if height < water_radius:
		# Below water - show underwater colors
		var depth: float = (water_radius - height) / (planet_radius * 0.05)
		if depth > 0.5:
			return Color(0.05, 0.1, 0.3)  # Deep water - dark blue
		else:
			return Color(0.1, 0.3, 0.6)  # Shallow water - medium blue

	# Above water - show terrain biomes based on height
	if height_above_water > 0.8:
		# High peaks - Snow
		return Color(0.95, 0.95, 1.0)
	elif height_above_water > 0.5:
		# Mountains - Rocky gray with some variation
		var rock_variation: float = sin(vert.x * 10.0 + vert.y * 10.0) * 0.1
		return Color(0.5 + rock_variation, 0.5 + rock_variation, 0.5 + rock_variation)
	elif height_above_water > 0.3:
		# Hills - Dark green grass
		return Color(0.2, 0.5, 0.2)
	elif height_above_water > 0.1:
		# Lowlands - Bright green grass
		return Color(0.3, 0.7, 0.3)
	elif height_above_water > -0.05:
		# Beach/sand
		return Color(0.85, 0.8, 0.6)
	elif height_above_water > -0.15:
		# Shallow water / mud
		return Color(0.6, 0.55, 0.4)
	else:
		# Ocean floor / deep areas
		return Color(0.3, 0.4, 0.3)

func _create_mesh_from_data(vertices: PackedVector3Array, colors: PackedColorArray) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors

	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	# Generate normals
	var st: SurfaceTool = SurfaceTool.new()
	st.create_from(mesh, 0)
	st.generate_normals()
	return st.commit()
#endregion
