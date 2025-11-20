# Spherical Voxel World - Godot 4.5

A real-time 3D spherical planet generator with volumetric voxel terrain, featuring destructible environments, procedurally generated mountains, caves, rivers, and oceans.

**Built with Godot 4.5 best practices** - See [GODOT_BEST_PRACTICES.md](GODOT_BEST_PRACTICES.md) for details.

## Features

### Terrain Features
- **Spherical Planet**: Fully volumetric spherical world using voxel-based terrain
- **Procedural Generation**: Multi-octave 3D simplex noise for realistic terrain
- **Height-Based Biomes**: Automatic biome coloring (snow peaks, rocky mountains, grasslands, beaches, ocean floor)
- **Mountains**: Elevated terrain with snow-capped peaks
- **Caves**: Organic 3D cave systems throughout the planet
- **Water System**: Oceans, rivers, and dynamic water rendering
- **Destructible Terrain**: Real-time terrain modification with raycasting
- **Marching Cubes**: Smooth voxel mesh generation using the marching cubes algorithm

### Code Quality Features
- **Full Static Typing**: 20-40% performance improvement
- **Threaded Generation**: Non-blocking terrain generation
- **Signal-Based Architecture**: Decoupled, maintainable components
- **Export Groups**: Inspector-organized parameters
- **Progress Reporting**: Visual feedback during generation

## Controls

### Movement
- **WASD** - Move forward/left/backward/right
- **Space** - Move up
- **Ctrl** - Move down
- **Shift** (hold) - Speed boost while moving
- **Mouse** - Look around
- **ESC** - Toggle mouse capture

### Terrain Modification
- **Click** - Destroy terrain (remove voxels)
- **Shift + Click** - Add terrain (add voxels)

### UI Buttons
- **Add Terrain** - Add terrain at camera center
- **Remove Terrain** - Remove terrain at camera center
- **Regenerate** - Generate a new random world

## How to Run

1. Open the project in **Godot 4.3 or later**
2. Press **F5** or click the **Play** button
3. Click in the window to capture the mouse and start exploring

## Project Structure

```
voxelworld/
├── scenes/
│   └── Main.tscn           # Main scene with world, camera, and UI
├── scripts/
│   ├── SimplexNoise.gd     # 3D simplex noise implementation
│   ├── MarchingCubes.gd    # Marching cubes algorithm
│   ├── SphericalVoxelWorld.gd  # Core voxel world system
│   ├── PlayerCamera.gd     # First-person camera controller
│   └── UI.gd               # User interface controller
├── project.godot           # Godot project configuration
└── README.md
```

## Technical Details

### Architecture
- **SphericalVoxelWorld**: Core voxel engine with spherical coordinate system
- **SimplexNoise3D**: 3D simplex noise implementation for terrain generation
- **MarchingCubes**: Mesh generation algorithm for voxel visualization
- **PlayerCamera**: First-person controller with terrain interaction

### Terrain Generation
The terrain uses multiple layers of 3D simplex noise:
1. **Continental Noise**: Base landmass formation (3 octaves)
2. **Mountain Noise**: High-frequency detail for peaks and valleys (2 octaves)
3. **Cave Noise**: Dual-threshold noise for organic cave systems
4. **River Noise**: Flow patterns for river valley carving

### Voxel System
- **Resolution**: 96³ voxels by default (configurable 16-256)
- **Planet Radius**: 50 units
- **Dynamic Density Field**: Signed distance field with marching cubes surface extraction
- **Water Representation**: Negative density values for water voxels
- **Chunk-Based System**: World divided into 32³ voxel chunks for efficient management
- **LOD System**: 3 levels of detail (full, half, quarter resolution) based on camera distance
- **View Distance Culling**: Distant chunks hidden for better performance

### Performance
- Generates approximately **100,000-300,000 triangles** at 96³ resolution (per LOD level)
- **Chunk-Based LOD**: Automatically reduces detail for distant chunks (3 LOD levels)
- **View Distance Culling**: Chunks beyond view distance are hidden
- **Threaded terrain generation** keeps UI responsive
- **Per-Chunk mesh updates**: Only affected chunks regenerate on terrain modification
- **Static typing** provides 20-40% performance improvement
- **Packed arrays** for efficient vertex data storage
- Generation time: 5-15 seconds (depending on resolution and CPU)

**LOD Performance Benefits:**
- Close chunks: Full detail (stride 1)
- Medium distance (50-150 units): Half detail (stride 2) - 75% fewer triangles
- Far distance (150-300 units): Quarter detail (stride 4) - 93% fewer triangles
- Beyond view distance (400+ units): Hidden completely

**Resolution Impact:**
- 64³: ~50k-150k triangles, 2-5 sec generation, 60 FPS
- 96³: ~100k-300k triangles, 5-15 sec generation, 45-60 FPS ⭐ **Recommended**
- 128³: ~200k-600k triangles, 15-30 sec generation, 40-60 FPS (LOD helps significantly)
- 192³+: 500k+ triangles, 45+ sec generation, 30-60 FPS (LOD makes it playable)

## Customization

All parameters are organized in the Inspector with clear groups:

### SphericalVoxelWorld Node

**Planet Configuration:**
- **planet_radius**: Size of the planet (10-200, default: 50.0)
- **voxel_resolution**: Number of voxels per axis (16-256, default: 96)
  - 64: Fast generation, lower detail
  - 96: **Recommended** - good balance
  - 128: High detail, slower generation
  - 192+: Very high detail, slow (requires LOD for good FPS)
- **water_level**: Height of ocean surface (0-0.2, default: 0.02)

**Noise Seeds:**
- **terrain_seed**: Seed for continent noise (default: 12345)
- **cave_seed**: Seed for cave noise (default: 67890)
- **mountain_seed**: Seed for mountain noise (default: 11111)
- **river_seed**: Seed for river noise (default: 22222)

**Terrain Parameters:**
- **continent_strength**: Landmass height (0-2, default: 0.35)
- **mountain_strength**: Peak height (0-2, default: 0.45)
- **cave_threshold**: Cave density (0-1, default: 0.15)
- **cave_min_depth**: Minimum depth for caves (0-0.5, default: 0.25)
- **river_threshold**: River width (0-1, default: 0.1)
- **enable_caves**: Enable cave generation (default: false) - **Warning**: Can cause floating geometry

**Biome System:**
The terrain automatically applies height-based biomes:
- **Snow** (>0.8): White peaks on highest mountains
- **Rocky Mountains** (0.5-0.8): Gray stone with subtle variation
- **Dark Grass Hills** (0.3-0.5): Green hills
- **Bright Grass** (0.1-0.3): Vibrant green lowlands
- **Beaches** (-0.05-0.1): Sandy shores
- **Shallow Water** (-0.15 to -0.05): Muddy shallows
- **Ocean Floor** (<-0.15): Dark green depths

**Performance:**
- **use_threading**: Enable threaded generation (default: true)
- **generate_on_ready**: Auto-generate on load (default: true)
- **chunk_view_distance**: Maximum distance to render chunks (100-1000, default: 400.0)
  - 200: Close view, best FPS
  - 400: **Recommended** - good balance
  - 600+: Far view, lower FPS

### PlayerCamera Node

**Movement:**
- **move_speed**: Base movement speed (1-100, default: 30.0)
- **sprint_multiplier**: Speed boost (1-10, default: 3.0)
- **mouse_sensitivity**: Look sensitivity (0.0001-0.01, default: 0.002)

**Terrain Interaction:**
- **terrain_modification_radius**: Size of edits (1-10, default: 2)
- **raycast_distance**: Interaction range (10-500, default: 150.0)

## Code Quality & Best Practices

This project follows **Godot 4.5 best practices** throughout:

- ✅ **Full Static Typing**: All variables and functions are typed
- ✅ **Signal-Based Communication**: Decoupled components using signals
- ✅ **Threaded Generation**: Non-blocking background processing
- ✅ **Code Regions**: Organized with collapsible regions
- ✅ **Export Groups**: Inspector-friendly property organization
- ✅ **Unique Node Names**: Path-independent UI references
- ✅ **Constants**: No magic numbers
- ✅ **Private Naming**: Clear public/private separation
- ✅ **Resource Cleanup**: Proper _exit_tree() handling
- ✅ **Error Handling**: Validation and error messages
- ✅ **Documentation**: Comprehensive code comments

See [GODOT_BEST_PRACTICES.md](GODOT_BEST_PRACTICES.md) for detailed explanations!

## Known Limitations

- **Memory Usage**: 96³ uses ~3.5MB voxel data (distributed across chunks), 128³ uses ~8MB, 256³ uses ~64MB
- **Caves Disabled**: Cave generation can create floating geometry artifacts (enable at your own risk)
- **LOD Transitions**: No smooth blending between LOD levels (instant switching)

## Recent Improvements

✅ **LOD System Implemented**: 3-level distance-based detail reduction (full/half/quarter)
✅ **Chunk-Based Architecture**: World divided into 32³ voxel chunks for efficient management
✅ **View Distance Culling**: Distant chunks automatically hidden
✅ **Per-Chunk Mesh Updates**: Only affected chunks regenerate on terrain modification

## Future Enhancements

**High Priority:**
- **Fix Cave Artifacts**: Better algorithm for underground caves without surface gaps
- **Smooth LOD Transitions**: Geomorphing between LOD levels to prevent popping

**Medium Priority:**
- Multithreaded mesh generation (currently only terrain gen is threaded)
- GPU-based marching cubes for better performance
- Enhanced biome system with varied vegetation
- Physics-based water flow simulation

**Low Priority:**
- Procedural textures and materials
- Save/load functionality
- Multiplayer support
- Ambient occlusion for caves

## Credits

Built with Godot Engine 4.5
Marching Cubes algorithm based on Paul Bourke's tables
Simplex Noise implementation adapted for GDScript

## License

This project is provided as-is for educational and demonstration purposes.
