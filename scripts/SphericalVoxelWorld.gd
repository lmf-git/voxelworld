class_name SphericalVoxelWorld
extends Node3D

## Spherical voxel world with destructible terrain, caves, mountains, rivers and oceans

@export var planet_radius: float = 50.0
@export var voxel_resolution: int = 64
@export var water_level: float = 0.02

var voxel_size: float
var voxels: PackedFloat32Array
var marching_cubes: MarchingCubes
var terrain_noise: SimplexNoise3D
var cave_noise: SimplexNoise3D
var mountain_noise: SimplexNoise3D
var river_noise: SimplexNoise3D

var terrain_mesh_instance: MeshInstance3D
var water_mesh_instance: MeshInstance3D

func _ready() -> void:
	voxel_size = (planet_radius * 2.0) / float(voxel_resolution)

	# Initialize voxel array
	voxels = PackedFloat32Array()
	voxels.resize(voxel_resolution * voxel_resolution * voxel_resolution)

	# Initialize noise generators
	terrain_noise = SimplexNoise3D.new(12345)
	cave_noise = SimplexNoise3D.new(67890)
	mountain_noise = SimplexNoise3D.new(11111)
	river_noise = SimplexNoise3D.new(22222)

	# Initialize marching cubes
	marching_cubes = MarchingCubes.new()

	# Create mesh instances
	terrain_mesh_instance = MeshInstance3D.new()
	add_child(terrain_mesh_instance)

	water_mesh_instance = MeshInstance3D.new()
	add_child(water_mesh_instance)

	# Generate terrain
	print("Generating terrain...")
	generate_terrain()
	print("Generating meshes...")
	update_meshes()
	print("World generated!")

func get_voxel_index(x: int, y: int, z: int) -> int:
	if x < 0 or x >= voxel_resolution or y < 0 or y >= voxel_resolution or z < 0 or z >= voxel_resolution:
		return -1
	return x + y * voxel_resolution + z * voxel_resolution * voxel_resolution

func get_voxel(x: int, y: int, z: int) -> float:
	var idx := get_voxel_index(x, y, z)
	return voxels[idx] if idx >= 0 else 0.0

func set_voxel(x: int, y: int, z: int, value: float) -> void:
	var idx := get_voxel_index(x, y, z)
	if idx >= 0:
		voxels[idx] = value

func world_to_voxel(world_pos: Vector3) -> Vector3i:
	var offset := planet_radius
	return Vector3i(
		int(floor((world_pos.x + offset) / voxel_size)),
		int(floor((world_pos.y + offset) / voxel_size)),
		int(floor((world_pos.z + offset) / voxel_size))
	)

func voxel_to_world(vx: int, vy: int, vz: int) -> Vector3:
	var offset := planet_radius
	return Vector3(
		float(vx) * voxel_size - offset,
		float(vy) * voxel_size - offset,
		float(vz) * voxel_size - offset
	)

func generate_terrain() -> void:
	for x in range(voxel_resolution):
		for y in range(voxel_resolution):
			for z in range(voxel_resolution):
				var world_pos := voxel_to_world(x, y, z)
				var distance_from_center := world_pos.length()

				# Normalize position for noise sampling
				var nx := world_pos.x / planet_radius
				var ny := world_pos.y / planet_radius
				var nz := world_pos.z / planet_radius

				# Base spherical shape
				var base_radius := planet_radius * 0.85
				var density := base_radius - distance_from_center

				# Add continents with multiple octaves of noise
				var continent_scale := 2.0
				var continent_noise := (
					terrain_noise.noise(nx * continent_scale, ny * continent_scale, nz * continent_scale) * 0.5 +
					terrain_noise.noise(nx * continent_scale * 2.0, ny * continent_scale * 2.0, nz * continent_scale * 2.0) * 0.25 +
					terrain_noise.noise(nx * continent_scale * 4.0, ny * continent_scale * 4.0, nz * continent_scale * 4.0) * 0.125
				)

				# Mountains - higher frequency, larger amplitude
				var mountain_scale := 4.0
				var mountain_noise_val := (
					mountain_noise.noise(nx * mountain_scale, ny * mountain_scale, nz * mountain_scale) * 0.6 +
					mountain_noise.noise(nx * mountain_scale * 2.0, ny * mountain_scale * 2.0, nz * mountain_scale * 2.0) * 0.3
				)

				# Only add mountains where continents exist
				var mountain_factor := maxf(0.0, continent_noise) * 1.5
				density += continent_noise * planet_radius * 0.15
				density += mountain_noise_val * mountain_factor * planet_radius * 0.25

				# Caves - 3D noise for organic cave systems
				var cave_scale := 6.0
				var cave_noise1 := cave_noise.noise(nx * cave_scale, ny * cave_scale, nz * cave_scale)
				var cave_noise2 := cave_noise.noise(nx * cave_scale + 100.0, ny * cave_scale + 100.0, nz * cave_scale + 100.0)

				# Create caves where both noise values are within a threshold
				var cave_threshold := 0.15
				if abs(cave_noise1) < cave_threshold and abs(cave_noise2) < cave_threshold:
					density -= planet_radius * 0.3

				# River valleys - use noise to create flow patterns
				var river_scale := 3.0
				var river_noise_val := river_noise.noise(nx * river_scale, ny * river_scale, nz * river_scale)

				# Create rivers in low-lying areas
				if continent_noise > -0.1 and continent_noise < 0.3 and abs(river_noise_val) < 0.1:
					var river_depth := planet_radius * 0.08
					density -= river_depth

				# Store density value
				set_voxel(x, y, z, density)

	# Add water layer
	add_water()

func add_water() -> void:
	var water_radius := planet_radius * (0.85 + water_level)

	for x in range(voxel_resolution):
		for y in range(voxel_resolution):
			for z in range(voxel_resolution):
				var world_pos := voxel_to_world(x, y, z)
				var distance_from_center := world_pos.length()

				var current_density := get_voxel(x, y, z)

				# If below water level and empty space, fill with water
				if distance_from_center < water_radius and current_density < 0.0:
					set_voxel(x, y, z, -10.0)

func update_meshes() -> void:
	# Generate terrain mesh
	var terrain_data := generate_terrain_mesh()
	if terrain_data.vertices.size() > 0:
		var terrain_mesh := create_mesh_from_data(terrain_data.vertices, terrain_data.colors)
		terrain_mesh_instance.mesh = terrain_mesh

		# Create material
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.roughness = 0.8
		material.metallic = 0.2
		terrain_mesh_instance.set_surface_override_material(0, material)

	# Generate water mesh
	var water_data := generate_water_mesh()
	if water_data.vertices.size() > 0:
		var water_mesh := create_mesh_from_data(water_data.vertices, water_data.colors)
		water_mesh_instance.mesh = water_mesh

		# Create water material
		var water_material := StandardMaterial3D.new()
		water_material.albedo_color = Color(0.0, 0.4, 0.9, 0.7)
		water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		water_material.roughness = 0.1
		water_material.metallic = 0.3
		water_mesh_instance.set_surface_override_material(0, water_material)

func generate_terrain_mesh() -> Dictionary:
	var vertices: PackedVector3Array = []
	var colors: PackedColorArray = []
	var isolevel := 0.0

	for x in range(voxel_resolution - 1):
		for y in range(voxel_resolution - 1):
			for z in range(voxel_resolution - 1):
				var cube_points: Array[Vector3] = [
					voxel_to_world(x, y, z),
					voxel_to_world(x + 1, y, z),
					voxel_to_world(x + 1, y, z + 1),
					voxel_to_world(x, y, z + 1),
					voxel_to_world(x, y + 1, z),
					voxel_to_world(x + 1, y + 1, z),
					voxel_to_world(x + 1, y + 1, z + 1),
					voxel_to_world(x, y + 1, z + 1)
				]

				var cube_values: Array[float] = [
					get_voxel(x, y, z),
					get_voxel(x + 1, y, z),
					get_voxel(x + 1, y, z + 1),
					get_voxel(x, y, z + 1),
					get_voxel(x, y + 1, z),
					get_voxel(x + 1, y + 1, z),
					get_voxel(x + 1, y + 1, z + 1),
					get_voxel(x, y + 1, z + 1)
				]

				var triangles := marching_cubes.polygonise(cube_points, cube_values, isolevel)

				for vert in triangles:
					vertices.append(vert)

					# Color based on height
					var height := vert.length()
					var normalized_height := (height - planet_radius * 0.7) / (planet_radius * 0.3)

					# Check if this is water (negative density)
					var is_water := false
					for val in cube_values:
						if val < 0.0 and val > -50.0:
							is_water = true
							break

					var color: Color
					if is_water:
						color = Color(0.1, 0.3, 0.8)
					elif normalized_height > 0.7:
						color = Color(0.95, 0.95, 1.0)  # Snow
					elif normalized_height > 0.5:
						color = Color(0.5, 0.5, 0.5)  # Rocky mountains
					elif normalized_height > 0.2:
						color = Color(0.2, 0.6, 0.2)  # Grass
					elif normalized_height > 0.0:
						color = Color(0.76, 0.7, 0.5)  # Beach/dirt
					else:
						color = Color(0.3, 0.4, 0.3)  # Ocean floor

					colors.append(color)

	return {"vertices": vertices, "colors": colors}

func generate_water_mesh() -> Dictionary:
	var vertices: PackedVector3Array = []
	var colors: PackedColorArray = []
	var isolevel := -5.0

	for x in range(voxel_resolution - 1):
		for y in range(voxel_resolution - 1):
			for z in range(voxel_resolution - 1):
				var cube_points: Array[Vector3] = [
					voxel_to_world(x, y, z),
					voxel_to_world(x + 1, y, z),
					voxel_to_world(x + 1, y, z + 1),
					voxel_to_world(x, y, z + 1),
					voxel_to_world(x, y + 1, z),
					voxel_to_world(x + 1, y + 1, z),
					voxel_to_world(x + 1, y + 1, z + 1),
					voxel_to_world(x, y + 1, z + 1)
				]

				var cube_values: Array[float] = [
					maxf(-20.0, get_voxel(x, y, z)),
					maxf(-20.0, get_voxel(x + 1, y, z)),
					maxf(-20.0, get_voxel(x + 1, y, z + 1)),
					maxf(-20.0, get_voxel(x, y, z + 1)),
					maxf(-20.0, get_voxel(x, y + 1, z)),
					maxf(-20.0, get_voxel(x + 1, y + 1, z)),
					maxf(-20.0, get_voxel(x + 1, y + 1, z + 1)),
					maxf(-20.0, get_voxel(x, y + 1, z + 1))
				]

				# Only process if any voxel is water
				var has_water := false
				for val in cube_values:
					if val < 0.0:
						has_water = true
						break

				if has_water:
					var triangles := marching_cubes.polygonise(cube_points, cube_values, isolevel)

					for vert in triangles:
						vertices.append(vert)
						colors.append(Color(0.0, 0.4, 0.9, 0.7))

	return {"vertices": vertices, "colors": colors}

func create_mesh_from_data(vertices: PackedVector3Array, colors: PackedColorArray) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	# Generate normals
	var st := SurfaceTool.new()
	st.create_from(mesh, 0)
	st.generate_normals()
	return st.commit()

func raycast_voxel(origin: Vector3, direction: Vector3, max_distance: float = 100.0) -> Dictionary:
	var step := voxel_size * 0.5
	var dir := direction.normalized()

	for dist in range(0, int(max_distance / step)):
		var point := origin + dir * (float(dist) * step)
		var voxel_pos := world_to_voxel(point)

		var density := get_voxel(voxel_pos.x, voxel_pos.y, voxel_pos.z)

		if density > 0.0:
			return {
				"hit": true,
				"voxel_pos": voxel_pos,
				"world_pos": point,
				"distance": float(dist) * step
			}

	return {"hit": false}

func modify_terrain(voxel_pos: Vector3i, radius: int, add_terrain: bool = false) -> void:
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			for dz in range(-radius, radius + 1):
				var dist := sqrt(float(dx * dx + dy * dy + dz * dz))
				if dist <= float(radius):
					var x := voxel_pos.x + dx
					var y := voxel_pos.y + dy
					var z := voxel_pos.z + dz

					var current_density := get_voxel(x, y, z)

					if add_terrain:
						set_voxel(x, y, z, current_density + 10.0)
					else:
						set_voxel(x, y, z, current_density - 10.0)

	update_meshes()

func regenerate() -> void:
	print("Regenerating terrain...")
	generate_terrain()
	update_meshes()
	print("Regeneration complete!")
