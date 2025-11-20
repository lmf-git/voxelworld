# Spherical Voxel World - Godot 4.5

A real-time 3D spherical planet generator with volumetric voxel terrain, featuring destructible environments, procedurally generated mountains, caves, rivers, and oceans.

## Features

- **Spherical Planet**: Fully volumetric spherical world using voxel-based terrain
- **Procedural Generation**: Multi-octave 3D simplex noise for realistic terrain
- **Mountains**: Elevated terrain with snow-capped peaks
- **Caves**: Organic 3D cave systems throughout the planet
- **Water System**: Oceans, rivers, and dynamic water rendering
- **Destructible Terrain**: Real-time terrain modification with raycasting
- **Marching Cubes**: Smooth voxel mesh generation using the marching cubes algorithm

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
- Mesh generation occurs on-demand when terrain is modified
- Single-threaded generation (takes a few seconds on startup)

## Customization

You can adjust these parameters in the Main.tscn scene:

### SphericalVoxelWorld Node
- **planet_radius**: Size of the planet (default: 50.0)
- **voxel_resolution**: Number of voxels per axis (default: 64, higher = more detail but slower)
- **water_level**: Height of ocean surface relative to planet radius (default: 0.02)

### PlayerCamera Node
- **move_speed**: Base movement speed (default: 30.0)
- **sprint_multiplier**: Speed boost when holding Shift (default: 3.0)
- **mouse_sensitivity**: Look sensitivity (default: 0.002)
- **terrain_modification_radius**: Size of terrain edits in voxels (default: 2)

## Known Limitations

- **Generation Time**: Initial terrain generation takes 3-10 seconds depending on CPU
- **Single Thread**: Mesh generation is not yet multithreaded
- **Memory Usage**: 64³ resolution uses ~1MB for voxel data, higher resolutions use significantly more
- **No LOD**: All voxels are rendered at full resolution

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
