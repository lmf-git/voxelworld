class_name SphericalVoxelWorld
extends Node3D

## Spherical voxel world with destructible terrain, caves, mountains, rivers and oceans
## Uses threaded generation for better performance

#region Signals
signal terrain_generation_started()
signal terrain_generation_progress(progress: float) # Emitted via call_deferred in _generate_terrain_data() for thread safety
signal terrain_generation_completed()
signal terrain_modified(position: Vector3i, radius: int, added: bool)
signal mesh_update_started()
signal mesh_update_completed(terrain_triangles: int, water_triangles: int)
#endregion

#region Exported Properties
@export_group("Planet Configuration")
@export_range(10.0, 200.0, 1.0) var planet_radius: float = 50.0
@export_range(16, 256, 1) var voxel_resolution: int = 96
@export_range(0.0, 0.2, 0.01) var water_level: float = 0.02

@export_group("Noise Seeds")
@export var terrain_seed: int = 12345
@export var cave_seed: int = 67890
@export var mountain_seed: int = 11111
@export var river_seed: int = 22222

@export_group("Terrain Parameters")
@export_range(0.0, 0.5, 0.01) var continent_strength: float = 0.15
@export_range(0.0, 0.5, 0.01) var mountain_strength: float = 0.25
@export_range(0.0, 1.0, 0.01) var cave_threshold: float = 0.15
@export_range(0.0, 0.5, 0.01) var cave_min_depth: float = 0.25
@export_range(0.0, 0.2, 0.01) var river_threshold: float = 0.08
@export var enable_caves: bool = false

@export_group("Performance")
@export var use_threading: bool = true
@export var generate_on_ready: bool = true
@export_range(100.0, 1000.0, 10.0) var chunk_view_distance: float = 400.0
#endregion

#region Private Variables
var _voxel_size: float
var _chunks: Array[VoxelChunk] = []
var _chunk_size: int = 32
var _chunks_per_axis: int = 0
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
var _camera: Camera3D  ## Reference to camera for LOD updates
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

func _process(_delta: float) -> void:
	# Update chunk LOD levels based on camera distance
	if _camera and not _is_generating:
		_update_chunk_lods()

func _exit_tree() -> void:
	_cleanup()
#endregion

#region Initialization
func _initialize() -> void:
	_voxel_size = (planet_radius * 2.0) / float(voxel_resolution)

	# Calculate chunk grid dimensions
	_chunks_per_axis = ceili(float(voxel_resolution) / float(_chunk_size))
	print("Chunk grid: ", _chunks_per_axis, "x", _chunks_per_axis, "x", _chunks_per_axis, " (", _chunks_per_axis * _chunks_per_axis * _chunks_per_axis, " total chunks)")

	# Initialize chunks
	_create_chunks()

	# Initialize noise generators
	_terrain_noise = SimplexNoise3D.new(terrain_seed)
	_cave_noise = SimplexNoise3D.new(cave_seed)
	_mountain_noise = SimplexNoise3D.new(mountain_seed)
	_river_noise = SimplexNoise3D.new(river_seed)

	# Initialize marching cubes
	_marching_cubes = MarchingCubes.new()

	# Create materials
	_create_materials()

	# Create mesh instances (kept for compatibility, but will be replaced by chunk meshes)
	_terrain_mesh_instance = MeshInstance3D.new()
	_terrain_mesh_instance.name = "TerrainMesh"
	_terrain_mesh_instance.material_override = _terrain_material
	add_child(_terrain_mesh_instance)
	_terrain_mesh_instance.visible = false  # Hidden - chunks render instead

	_water_mesh_instance = MeshInstance3D.new()
	_water_mesh_instance.name = "WaterMesh"
	_water_mesh_instance.material_override = _water_material
	add_child(_water_mesh_instance)
	_water_mesh_instance.visible = false  # Hidden

	# Find camera for LOD updates
	_find_camera()

func _create_chunks() -> void:
	_chunks.clear()

	for cx in range(_chunks_per_axis):
		for cy in range(_chunks_per_axis):
			for cz in range(_chunks_per_axis):
				var chunk: VoxelChunk = VoxelChunk.new()
				chunk.chunk_size = _chunk_size
				chunk.name = "Chunk_%d_%d_%d" % [cx, cy, cz]

				var chunk_pos: Vector3i = Vector3i(cx, cy, cz)
				var voxel_offset: Vector3i = Vector3i(
					cx * _chunk_size,
					cy * _chunk_size,
					cz * _chunk_size
				)

				chunk.initialize(chunk_pos, voxel_offset)

				# Add chunk to tree first (required before accessing global_position)
				add_child(chunk)
				_chunks.append(chunk)

				# Calculate chunk center in world space and set position
				var half_chunk: int = _chunk_size / 2
				var chunk_center_voxel: Vector3i = voxel_offset + Vector3i(half_chunk, half_chunk, half_chunk)
				var chunk_center_world: Vector3 = voxel_to_world(chunk_center_voxel.x, chunk_center_voxel.y, chunk_center_voxel.z)
				chunk.global_position = chunk_center_world

func _find_camera() -> void:
	# Look for PlayerCamera child
	for child in get_children():
		if child is Camera3D:
			_camera = child
			print("Found camera for LOD updates: ", _camera.name)
			return

	print("Warning: No camera found for LOD updates")

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

	for chunk in _chunks:
		chunk.queue_free()
	_chunks.clear()
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
	var affected_chunks: Array[VoxelChunk] = []

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

					# Track affected chunk
					var chunk: VoxelChunk = _get_chunk_for_voxel(x, y, z)
					if chunk and not affected_chunks.has(chunk):
						affected_chunks.append(chunk)

	# Regenerate meshes for affected chunks only
	for chunk in affected_chunks:
		chunk.generate_meshes(planet_radius, water_level, BASE_RADIUS_MULTIPLIER, voxel_resolution, _terrain_material)

	terrain_modified.emit(voxel_pos, radius, add_terrain)

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
	if x < 0 or x >= voxel_resolution or \
	   y < 0 or y >= voxel_resolution or \
	   z < 0 or z >= voxel_resolution:
		return 0.0

	var chunk: VoxelChunk = _get_chunk_for_voxel(x, y, z)
	if not chunk:
		return 0.0

	var local_x: int = x % _chunk_size
	var local_y: int = y % _chunk_size
	var local_z: int = z % _chunk_size

	return chunk.get_voxel(local_x, local_y, local_z)

func set_voxel(x: int, y: int, z: int, value: float) -> void:
	if x < 0 or x >= voxel_resolution or \
	   y < 0 or y >= voxel_resolution or \
	   z < 0 or z >= voxel_resolution:
		return

	var chunk: VoxelChunk = _get_chunk_for_voxel(x, y, z)
	if not chunk:
		return

	var local_x: int = x % _chunk_size
	var local_y: int = y % _chunk_size
	var local_z: int = z % _chunk_size

	chunk.set_voxel(local_x, local_y, local_z, value)

func _get_chunk_for_voxel(x: int, y: int, z: int) -> VoxelChunk:
	var cx: int = x / _chunk_size
	var cy: int = y / _chunk_size
	var cz: int = z / _chunk_size

	if cx < 0 or cx >= _chunks_per_axis or \
	   cy < 0 or cy >= _chunks_per_axis or \
	   cz < 0 or cz >= _chunks_per_axis:
		return null

	var chunk_index: int = cx + cy * _chunks_per_axis + cz * _chunks_per_axis * _chunks_per_axis
	if chunk_index >= 0 and chunk_index < _chunks.size():
		return _chunks[chunk_index]

	return null
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

## Generates voxel density using radial height-based approach
## This method ensures coherent terrain by:
## 1. Starting with a solid spherical base
## 2. Adding large-scale continent/ocean heights (smooth features)
## 3. Adding mountains only on elevated continents (prevents underwater mountains)
## 4. Adding small detail variation for texture
## 5. Carving rivers only on elevated land
## 6. Converting final surface radius to density field
## This approach eliminates floating geometry and creates natural-looking planets
func _generate_voxel_density(x: int, y: int, z: int) -> void:
	var world_pos: Vector3 = voxel_to_world(x, y, z)
	var distance_from_center: float = world_pos.length()

	# Normalize position for noise sampling (on unit sphere)
	var normalized_pos: Vector3 = world_pos.normalized()
	var nx: float = normalized_pos.x
	var ny: float = normalized_pos.y
	var nz: float = normalized_pos.z

	# 1. BASE SPHERE - Start with solid planet core
	var base_surface_radius: float = planet_radius * BASE_RADIUS_MULTIPLIER

	# 2. LARGE-SCALE CONTINENT/OCEAN HEIGHTS (very smooth, big features)
	var continent_height: float = (
		_terrain_noise.noise(nx * CONTINENT_SCALE, ny * CONTINENT_SCALE, nz * CONTINENT_SCALE) * 0.6 +
		_terrain_noise.noise(nx * CONTINENT_SCALE * 1.7, ny * CONTINENT_SCALE * 1.7, nz * CONTINENT_SCALE * 1.7) * 0.3 +
		_terrain_noise.noise(nx * CONTINENT_SCALE * 2.5, ny * CONTINENT_SCALE * 2.5, nz * CONTINENT_SCALE * 2.5) * 0.1
	) * planet_radius * continent_strength

	# 3. MEDIUM-SCALE MOUNTAINS (only on elevated continents)
	var mountain_height: float = 0.0
	if continent_height > 0.0:  # Only add mountains to land that's above base level
		var mountain_noise: float = (
			_mountain_noise.noise(nx * MOUNTAIN_SCALE, ny * MOUNTAIN_SCALE, nz * MOUNTAIN_SCALE) * 0.7 +
			_mountain_noise.noise(nx * MOUNTAIN_SCALE * 2.2, ny * MOUNTAIN_SCALE * 2.2, nz * MOUNTAIN_SCALE * 2.2) * 0.3
		)
		# Mountains appear more on higher continents
		var mountain_factor: float = (continent_height / (planet_radius * continent_strength)) * 0.8
		mountain_height = maxf(0.0, mountain_noise) * mountain_factor * planet_radius * mountain_strength

	# 4. SMALL-SCALE DETAIL (subtle terrain variation)
	var detail_height: float = _terrain_noise.noise(
		nx * MOUNTAIN_SCALE * 3.5,
		ny * MOUNTAIN_SCALE * 3.5,
		nz * MOUNTAIN_SCALE * 3.5
	) * planet_radius * 0.01

	# 5. CALCULATE FINAL SURFACE RADIUS with all height modifications
	var final_surface_radius: float = base_surface_radius + continent_height + mountain_height + detail_height

	# 6. RIVER VALLEYS (carve into elevated land)
	if continent_height > planet_radius * continent_strength * 0.1:  # Only rivers on higher land
		var river_noise: float = _river_noise.noise(nx * RIVER_SCALE, ny * RIVER_SCALE, nz * RIVER_SCALE)
		if abs(river_noise) < river_threshold:
			var river_depth: float = (river_threshold - abs(river_noise)) / river_threshold
			final_surface_radius -= river_depth * planet_radius * 0.06

	# 7. CONVERT TO DENSITY: positive inside planet, negative outside
	var density: float = final_surface_radius - distance_from_center

	# 8. CAVES (optional - only deep underground to avoid surface artifacts)
	if enable_caves and density > planet_radius * cave_min_depth:
		density = _apply_caves(nx, ny, nz, density)

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

	var total_triangles: int = 0

	# Generate meshes for all chunks
	for chunk in _chunks:
		chunk.generate_meshes(planet_radius, water_level, BASE_RADIUS_MULTIPLIER, voxel_resolution, _terrain_material)

		# Count triangles (approximate - LOD 0 mesh only)
		if chunk._mesh_instance.mesh:
			var mesh: ArrayMesh = chunk._mesh_instance.mesh as ArrayMesh
			if mesh and mesh.get_surface_count() > 0:
				var arrays: Array = mesh.surface_get_arrays(0)
				if arrays[Mesh.ARRAY_VERTEX]:
					total_triangles += arrays[Mesh.ARRAY_VERTEX].size() / 3

	mesh_update_completed.emit(total_triangles, 0)
	print("  Total triangles across all chunks: ", total_triangles)
#endregion

#region LOD Management
func _update_chunk_lods() -> void:
	if not _camera:
		return

	var camera_pos: Vector3 = _camera.global_position

	for chunk in _chunks:
		var chunk_center: Vector3 = chunk.global_position
		var distance: float = camera_pos.distance_to(chunk_center)

		# Visibility culling based on distance
		if distance > chunk_view_distance:
			chunk.set_chunk_visible(false)
		else:
			chunk.set_chunk_visible(true)
			# Only update LOD for visible chunks
			chunk.update_lod_for_distance(camera_pos)
#endregion
