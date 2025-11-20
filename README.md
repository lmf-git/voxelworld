# Spherical Voxel World

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
- **Shift** - Speed boost (hold while moving)
- **Mouse** - Look around (click to enable pointer lock)

### Terrain Modification
- **Click** - Destroy terrain (remove voxels)
- **Shift + Click** - Add terrain (add voxels)

### UI Buttons
- **Add Terrain** - Add terrain at camera center
- **Remove Terrain** - Remove terrain at camera center
- **Regenerate** - Generate a new random world

## Running the Project

### Development Mode
```bash
npm run dev
```

Then open your browser to the URL shown in the terminal (usually `http://localhost:5173`).

### Build for Production
```bash
npm run build
npm run preview
```

## Technical Details

### Architecture
- **SphericalVoxelWorld**: Core voxel engine with spherical coordinate system
- **SimplexNoise**: 3D simplex noise implementation for terrain generation
- **MarchingCubes**: Mesh generation algorithm for voxel visualization
- **Three.js**: 3D rendering engine

### Terrain Generation
The terrain uses multiple layers of 3D simplex noise:
1. **Continental Noise**: Base landmass formation
2. **Mountain Noise**: High-frequency detail for peaks and valleys
3. **Cave Noise**: Dual-threshold noise for organic cave systems
4. **River Noise**: Flow patterns for river valley carving

### Voxel System
- Resolution: 64³ voxels by default
- Planet radius: 50 units
- Dynamic density field with marching cubes surface extraction
- Negative density values represent water

## Performance

The system generates approximately 50,000-150,000 triangles for terrain rendering, depending on terrain complexity. Mesh generation occurs on-demand when terrain is modified.

## Future Enhancements

- Chunk-based loading for larger planets
- Biome system with varied vegetation
- Physics-based water flow
- Multiplayer support
- Procedural textures
- GPU-based marching cubes for better performance
