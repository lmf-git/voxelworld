extends Camera3D

## First-person camera controller with terrain modification

#region Exported Properties
@export_group("Movement")
@export_range(1.0, 100.0, 0.5) var move_speed: float = 30.0
@export_range(1.0, 10.0, 0.5) var sprint_multiplier: float = 3.0
@export_range(0.0001, 0.01, 0.0001) var mouse_sensitivity: float = 0.002

@export_group("Terrain Interaction")
@export_range(1, 10, 1) var terrain_modification_radius: int = 2
@export_range(10.0, 500.0, 10.0) var raycast_distance: float = 150.0
#endregion

#region Private Variables
var _camera_rotation: Vector2 = Vector2.ZERO
var _velocity: Vector3 = Vector3.ZERO
var _voxel_world: SphericalVoxelWorld
#endregion

#region Constants
const ROTATION_CLAMP_MIN: float = -PI / 2.0
const ROTATION_CLAMP_MAX: float = PI / 2.0
const VELOCITY_DAMPING: float = 0.9
const VELOCITY_LERP_WEIGHT: float = 0.3
#endregion

#region Lifecycle Methods
func _ready() -> void:
	_initialize_camera()
	_connect_to_voxel_world()

func _input(event: InputEvent) -> void:
	_handle_mouse_input(event)
	_handle_keyboard_input(event)
	_handle_terrain_modification(event)

func _process(delta: float) -> void:
	_update_rotation()
	_update_movement(delta)
#endregion

#region Initialization
func _initialize_camera() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Position camera outside the planet
	global_position = Vector3(100, 50, 100)
	look_at(Vector3.ZERO)
	_camera_rotation.y = rotation.y
	_camera_rotation.x = rotation.x

func _connect_to_voxel_world() -> void:
	_voxel_world = get_parent() as SphericalVoxelWorld
	if not _voxel_world:
		push_error("PlayerCamera must be a child of SphericalVoxelWorld")
#endregion

#region Input Handling
func _handle_mouse_input(event: InputEvent) -> void:
	if not (event is InputEventMouseMotion):
		return

	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		_camera_rotation.y -= motion.relative.x * mouse_sensitivity
		_camera_rotation.x -= motion.relative.y * mouse_sensitivity
		_camera_rotation.x = clamp(_camera_rotation.x, ROTATION_CLAMP_MIN, ROTATION_CLAMP_MAX)

func _handle_keyboard_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return

	var key_event: InputEventKey = event as InputEventKey
	if key_event.keycode == KEY_ESCAPE and key_event.pressed:
		_toggle_mouse_capture()

func _handle_terrain_modification(event: InputEvent) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return

	if not (event is InputEventMouseButton):
		return

	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
		_modify_terrain(mouse_event.shift_pressed)

func _toggle_mouse_capture() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
#endregion

#region Camera Control
func _update_rotation() -> void:
	rotation.y = _camera_rotation.y
	rotation.x = _camera_rotation.x

func _update_movement(delta: float) -> void:
	var input_dir: Vector3 = _get_movement_input()

	if input_dir.length() > 0.0:
		input_dir = input_dir.normalized()
		_velocity = _velocity.lerp(input_dir * move_speed, VELOCITY_LERP_WEIGHT)
	else:
		_velocity *= VELOCITY_DAMPING

	var speed_multiplier: float = sprint_multiplier if Input.is_action_pressed("speed_boost") else 1.0
	global_position += _velocity * speed_multiplier * delta

func _get_movement_input() -> Vector3:
	var input_dir: Vector3 = Vector3.ZERO

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

	return input_dir
#endregion

#region Terrain Modification
func _modify_terrain(add_terrain: bool) -> void:
	if not _voxel_world:
		return

	var ray_origin: Vector3 = global_position
	var ray_direction: Vector3 = -transform.basis.z

	var result: Dictionary = _voxel_world.raycast_voxel(ray_origin, ray_direction, raycast_distance)

	if result.hit:
		_voxel_world.modify_terrain(result.voxel_pos, terrain_modification_radius, add_terrain)

## Public API for UI buttons to trigger modifications
func modify_terrain_at_center(add_terrain: bool) -> void:
	_modify_terrain(add_terrain)
#endregion
