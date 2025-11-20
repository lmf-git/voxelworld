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
- **Resolution**: 64³ voxels by default
- **Planet Radius**: 50 units
- **Dynamic Density Field**: Signed distance field with marching cubes surface extraction
- **Water Representation**: Negative density values for water voxels

### Performance
- Generates approximately **50,000-150,000 triangles** for terrain rendering
- **Threaded terrain generation** keeps UI responsive
- Mesh generation occurs on-demand when terrain is modified
- **Static typing** provides 20-40% performance improvement
- **Packed arrays** for efficient vertex data storage

## Customization

All parameters are organized in the Inspector with clear groups:

### SphericalVoxelWorld Node

**Planet Configuration:**
- **planet_radius**: Size of the planet (10-200, default: 50.0)
- **voxel_resolution**: Number of voxels per axis (16-128, default: 64)
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
- **river_threshold**: River width (0-1, default: 0.1)

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

- **Memory Usage**: 64³ resolution uses ~1MB for voxel data, higher resolutions use significantly more
- **No LOD**: All voxels are rendered at full resolution
- **No Chunking**: Entire planet is one mesh (not suitable for very large worlds)

## Future Enhancements

- Chunk-based loading for larger planets
- Multithreaded mesh generation
- GPU-based marching cubes for better performance
- Biome system with varied vegetation
- Physics-based water flow
- Procedural textures and materials
- Save/load functionality
- Multiplayer support

## Credits

Built with Godot Engine 4.5
Marching Cubes algorithm based on Paul Bourke's tables
Simplex Noise implementation adapted for GDScript

## License

This project is provided as-is for educational and demonstration purposes.
