extends Camera3D

## First-person camera controller with terrain modification

@export var move_speed: float = 30.0
@export var sprint_multiplier: float = 3.0
@export var mouse_sensitivity: float = 0.002
@export var terrain_modification_radius: int = 2

var camera_rotation := Vector2.ZERO
var velocity := Vector3.ZERO
var voxel_world: SphericalVoxelWorld

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	voxel_world = get_parent() as SphericalVoxelWorld

	# Position camera outside the planet
	global_position = Vector3(100, 50, 100)
	look_at(Vector3.ZERO)
	camera_rotation.y = rotation.y
	camera_rotation.x = rotation.x

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_rotation.y -= event.relative.x * mouse_sensitivity
		camera_rotation.x -= event.relative.y * mouse_sensitivity
		camera_rotation.x = clamp(camera_rotation.x, -PI / 2.0, PI / 2.0)

	# Toggle mouse capture
	if event is InputEventKey:
		if event.keycode == KEY_ESCAPE and event.pressed:
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			else:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Terrain modification
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				var add_terrain := event.shift_pressed
				handle_terrain_modification(add_terrain)

func _process(delta: float) -> void:
	# Apply rotation
	rotation.y = camera_rotation.y
	rotation.x = camera_rotation.x

	# Calculate movement
	var input_dir := Vector3.ZERO

	if Input.is_action_pressed("move_forward"):
		input_dir -= transform.basis.z
	if Input.is_action_pressed("move_back"):
		input_dir += transform.basis.z
	if Input.is_action_pressed("move_left"):
		input_dir -= transform.basis.x
	if Input.is_action_pressed("move_right"):
		input_dir += transform.basis.x
	if Input.is_action_pressed("move_up"):
		input_dir += Vector3.UP
	if Input.is_action_pressed("move_down"):
		input_dir -= Vector3.UP

	if input_dir.length() > 0.0:
		input_dir = input_dir.normalized()
		velocity = velocity.lerp(input_dir * move_speed, 0.3)
	else:
		velocity *= 0.9

	# Speed boost
	var speed_multiplier := sprint_multiplier if Input.is_action_pressed("speed_boost") else 1.0

	# Apply movement
	global_position += velocity * speed_multiplier * delta

func handle_terrain_modification(add_terrain: bool) -> void:
	if not voxel_world:
		return

	# Raycast from camera
	var ray_origin := global_position
	var ray_direction := -transform.basis.z

	var result := voxel_world.raycast_voxel(ray_origin, ray_direction, 150.0)

	if result.hit:
		print("Adding terrain" if add_terrain else "Removing terrain", " at ", result.voxel_pos)
		voxel_world.modify_terrain(result.voxel_pos, terrain_modification_radius, add_terrain)
