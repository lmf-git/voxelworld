extends Control

## UI controller for the voxel world
## Uses signals for communication instead of direct node references

#region Node References
@onready var _stats_label: Label = %StatsLabel
@onready var _controls_label: Label = %ControlsLabel
@onready var _regenerate_button: Button = %RegenerateButton
@onready var _add_terrain_button: Button = %AddTerrainButton
@onready var _remove_terrain_button: Button = %RemoveTerrainButton
@onready var _progress_bar: ProgressBar = %ProgressBar if has_node("%ProgressBar") else null
#endregion

#region Private Variables
var _voxel_world: SphericalVoxelWorld
var _camera: Camera3D
var _terrain_triangles: int = 0
var _water_triangles: int = 0
var _is_generating: bool = false
#endregion

#region Constants
const CONTROLS_TEXT: String = """Controls:
WASD - Move
Mouse - Look
Click - Destroy Terrain
Shift+Click - Add Terrain
Space - Up | Ctrl - Down
Shift (hold) - Speed Boost
ESC - Toggle Mouse Capture
"""

const STATS_FORMAT: String = "Terrain Triangles: %d
Water Triangles: %d
Position: (%.1f, %.1f, %.1f)
FPS: %d%s"
#endregion

#region Lifecycle Methods
func _ready() -> void:
	_initialize_ui()
	_connect_signals()
	_setup_controls_text()

func _process(_delta: float) -> void:
	if not _is_generating:
		_update_stats()
#endregion

#region Initialization
func _initialize_ui() -> void:
	# Find voxel world and camera in scene tree
	_voxel_world = _find_node_by_type(get_tree().root, "SphericalVoxelWorld") as SphericalVoxelWorld
	_camera = _find_node_by_type(get_tree().root, "Camera3D") as Camera3D

	if not _voxel_world:
		push_error("UI: SphericalVoxelWorld not found in scene tree")
	if not _camera:
		push_error("UI: Camera3D not found in scene tree")

	# Hide progress bar initially
	if _progress_bar:
		_progress_bar.visible = false

func _connect_signals() -> void:
	# Connect button signals
	if _regenerate_button:
		_regenerate_button.pressed.connect(_on_regenerate_pressed)
	if _add_terrain_button:
		_add_terrain_button.pressed.connect(_on_add_terrain_pressed)
	if _remove_terrain_button:
		_remove_terrain_button.pressed.connect(_on_remove_terrain_pressed)

	# Connect voxel world signals
	if _voxel_world:
		_voxel_world.terrain_generation_started.connect(_on_terrain_generation_started)
		_voxel_world.terrain_generation_progress.connect(_on_terrain_generation_progress)
		_voxel_world.terrain_generation_completed.connect(_on_terrain_generation_completed)
		_voxel_world.mesh_update_completed.connect(_on_mesh_update_completed)

func _setup_controls_text() -> void:
	if _controls_label:
		_controls_label.text = CONTROLS_TEXT
#endregion

#region Node Finding
func _find_node_by_type(node: Node, type_name: String) -> Node:
	if node.get_class() == type_name or (node.get_script() and node.get_script().get_global_name() == type_name):
		return node

	for child in node.get_children():
		var result: Node = _find_node_by_type(child, type_name)
		if result:
			return result

	return null
#endregion

#region UI Updates
func _update_stats() -> void:
	if not _stats_label or not _camera:
		return

	var cam_pos: Vector3 = _camera.global_position
	var generation_status: String = " [GENERATING...]" if _is_generating else ""

	_stats_label.text = STATS_FORMAT % [
		_terrain_triangles,
		_water_triangles,
		cam_pos.x,
		cam_pos.y,
		cam_pos.z,
		Engine.get_frames_per_second(),
		generation_status
	]
#endregion

#region Signal Handlers - Buttons
func _on_regenerate_pressed() -> void:
	if _voxel_world and not _is_generating:
		_voxel_world.regenerate()

func _on_add_terrain_pressed() -> void:
	if not _camera or not _voxel_world or _is_generating:
		return

	var player_camera: Node = _camera as Node
	if player_camera.has_method("modify_terrain_at_center"):
		player_camera.modify_terrain_at_center(true)

func _on_remove_terrain_pressed() -> void:
	if not _camera or not _voxel_world or _is_generating:
		return

	var player_camera: Node = _camera as Node
	if player_camera.has_method("modify_terrain_at_center"):
		player_camera.modify_terrain_at_center(false)
#endregion

#region Signal Handlers - Voxel World
func _on_terrain_generation_started() -> void:
	_is_generating = true
	if _progress_bar:
		_progress_bar.visible = true
		_progress_bar.value = 0.0

	# Disable buttons during generation
	if _regenerate_button:
		_regenerate_button.disabled = true
	if _add_terrain_button:
		_add_terrain_button.disabled = true
	if _remove_terrain_button:
		_remove_terrain_button.disabled = true

func _on_terrain_generation_progress(progress: float) -> void:
	if _progress_bar:
		_progress_bar.value = progress * 100.0

func _on_terrain_generation_completed() -> void:
	_is_generating = false
	if _progress_bar:
		_progress_bar.visible = false

	# Re-enable buttons
	if _regenerate_button:
		_regenerate_button.disabled = false
	if _add_terrain_button:
		_add_terrain_button.disabled = false
	if _remove_terrain_button:
		_remove_terrain_button.disabled = false

func _on_mesh_update_completed(terrain_triangles: int, water_triangles: int) -> void:
	_terrain_triangles = terrain_triangles
	_water_triangles = water_triangles
#endregion
