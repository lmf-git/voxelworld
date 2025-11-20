import * as THREE from 'three';
import { SimplexNoise } from './SimplexNoise.js';
import { MarchingCubes } from './MarchingCubes.js';

export class SphericalVoxelWorld {
    constructor(planetRadius = 50, voxelResolution = 64) {
        this.planetRadius = planetRadius;
        this.voxelResolution = voxelResolution;
        this.voxelSize = (planetRadius * 2) / voxelResolution;

        // Voxel data structure
        this.voxels = new Float32Array(voxelResolution * voxelResolution * voxelResolution);

        // Noise generators
        this.terrainNoise = new SimplexNoise(12345);
        this.caveNoise = new SimplexNoise(67890);
        this.mountainNoise = new SimplexNoise(11111);
        this.riverNoise = new SimplexNoise(22222);

        // Marching cubes
        this.marchingCubes = new MarchingCubes();

        // Terrain types
        this.VOXEL_AIR = 0;
        this.VOXEL_STONE = 1;
        this.VOXEL_WATER = 2;
        this.VOXEL_DIRT = 3;

        // Water level (relative to planet radius)
        this.waterLevel = 0.02;

        this.generateTerrain();
    }

    getVoxelIndex(x, y, z) {
        if (x < 0 || x >= this.voxelResolution ||
            y < 0 || y >= this.voxelResolution ||
            z < 0 || z >= this.voxelResolution) {
            return -1;
        }
        return x + y * this.voxelResolution + z * this.voxelResolution * this.voxelResolution;
    }

    getVoxel(x, y, z) {
        const idx = this.getVoxelIndex(x, y, z);
        return idx >= 0 ? this.voxels[idx] : 0;
    }

    setVoxel(x, y, z, value) {
        const idx = this.getVoxelIndex(x, y, z);
        if (idx >= 0) {
            this.voxels[idx] = value;
        }
    }

    worldToVoxel(worldPos) {
        const offset = this.planetRadius;
        return {
            x: Math.floor((worldPos.x + offset) / this.voxelSize),
            y: Math.floor((worldPos.y + offset) / this.voxelSize),
            z: Math.floor((worldPos.z + offset) / this.voxelSize)
        };
    }

    voxelToWorld(vx, vy, vz) {
        const offset = this.planetRadius;
        return {
            x: vx * this.voxelSize - offset,
            y: vy * this.voxelSize - offset,
            z: vz * this.voxelSize - offset
        };
    }

    generateTerrain() {
        const center = this.voxelResolution / 2;

        for (let x = 0; x < this.voxelResolution; x++) {
            for (let y = 0; y < this.voxelResolution; y++) {
                for (let z = 0; z < this.voxelResolution; z++) {
                    const worldPos = this.voxelToWorld(x, y, z);
                    const distanceFromCenter = Math.sqrt(
                        worldPos.x * worldPos.x +
                        worldPos.y * worldPos.y +
                        worldPos.z * worldPos.z
                    );

                    // Normalize position for noise sampling
                    const nx = worldPos.x / this.planetRadius;
                    const ny = worldPos.y / this.planetRadius;
                    const nz = worldPos.z / this.planetRadius;

                    // Base spherical shape
                    const baseRadius = this.planetRadius * 0.85;
                    let density = baseRadius - distanceFromCenter;

                    // Add continents with multiple octaves of noise
                    const continentScale = 2.0;
                    const continentNoise =
                        this.terrainNoise.noise(nx * continentScale, ny * continentScale, nz * continentScale) * 0.5 +
                        this.terrainNoise.noise(nx * continentScale * 2, ny * continentScale * 2, nz * continentScale * 2) * 0.25 +
                        this.terrainNoise.noise(nx * continentScale * 4, ny * continentScale * 4, nz * continentScale * 4) * 0.125;

                    // Mountains - higher frequency, larger amplitude
                    const mountainScale = 4.0;
                    const mountainNoise =
                        this.mountainNoise.noise(nx * mountainScale, ny * mountainScale, nz * mountainScale) * 0.6 +
                        this.mountainNoise.noise(nx * mountainScale * 2, ny * mountainScale * 2, nz * mountainScale * 2) * 0.3;

                    // Only add mountains where continents exist
                    const mountainFactor = Math.max(0, continentNoise) * 1.5;
                    density += continentNoise * this.planetRadius * 0.15;
                    density += mountainNoise * mountainFactor * this.planetRadius * 0.25;

                    // Caves - 3D noise for organic cave systems
                    const caveScale = 6.0;
                    const caveNoise1 = this.caveNoise.noise(nx * caveScale, ny * caveScale, nz * caveScale);
                    const caveNoise2 = this.caveNoise.noise(nx * caveScale + 100, ny * caveScale + 100, nz * caveScale + 100);

                    // Create caves where both noise values are within a threshold
                    const caveThreshold = 0.15;
                    if (Math.abs(caveNoise1) < caveThreshold && Math.abs(caveNoise2) < caveThreshold) {
                        density -= this.planetRadius * 0.3; // Carve out caves
                    }

                    // River valleys - use noise to create flow patterns
                    const riverScale = 3.0;
                    const riverNoise = this.riverNoise.noise(nx * riverScale, ny * riverScale, nz * riverScale);

                    // Create rivers in low-lying areas
                    if (continentNoise > -0.1 && continentNoise < 0.3 && Math.abs(riverNoise) < 0.1) {
                        const riverDepth = this.planetRadius * 0.08;
                        density -= riverDepth;
                    }

                    // Store density value
                    this.setVoxel(x, y, z, density);
                }
            }
        }

        // Add water layer
        this.addWater();
    }

    addWater() {
        const waterRadius = this.planetRadius * (0.85 + this.waterLevel);

        for (let x = 0; x < this.voxelResolution; x++) {
            for (let y = 0; y < this.voxelResolution; y++) {
                for (let z = 0; z < this.voxelResolution; z++) {
                    const worldPos = this.voxelToWorld(x, y, z);
                    const distanceFromCenter = Math.sqrt(
                        worldPos.x * worldPos.x +
                        worldPos.y * worldPos.y +
                        worldPos.z * worldPos.z
                    );

                    const currentDensity = this.getVoxel(x, y, z);

                    // If below water level and empty space, fill with water
                    if (distanceFromCenter < waterRadius && currentDensity < 0) {
                        // Mark as water (negative value to distinguish from terrain)
                        this.setVoxel(x, y, z, -10);
                    }
                }
            }
        }
    }

    generateMesh() {
        const vertices = [];
        const colors = [];
        const isolevel = 0;

        // Generate mesh using marching cubes
        for (let x = 0; x < this.voxelResolution - 1; x++) {
            for (let y = 0; y < this.voxelResolution - 1; y++) {
                for (let z = 0; z < this.voxelResolution - 1; z++) {
                    const cube = {
                        p: [
                            this.voxelToWorld(x, y, z),
                            this.voxelToWorld(x + 1, y, z),
                            this.voxelToWorld(x + 1, y, z + 1),
                            this.voxelToWorld(x, y, z + 1),
                            this.voxelToWorld(x, y + 1, z),
                            this.voxelToWorld(x + 1, y + 1, z),
                            this.voxelToWorld(x + 1, y + 1, z + 1),
                            this.voxelToWorld(x, y + 1, z + 1)
                        ],
                        val: [
                            this.getVoxel(x, y, z),
                            this.getVoxel(x + 1, y, z),
                            this.getVoxel(x + 1, y, z + 1),
                            this.getVoxel(x, y, z + 1),
                            this.getVoxel(x, y + 1, z),
                            this.getVoxel(x + 1, y + 1, z),
                            this.getVoxel(x + 1, y + 1, z + 1),
                            this.getVoxel(x, y + 1, z + 1)
                        ]
                    };

                    const triangles = this.marchingCubes.polygonise(cube, isolevel);

                    for (let i = 0; i < triangles.length; i++) {
                        const vert = triangles[i];
                        vertices.push(vert.x, vert.y, vert.z);

                        // Color based on height and type
                        const height = Math.sqrt(vert.x * vert.x + vert.y * vert.y + vert.z * vert.z);
                        const normalizedHeight = (height - this.planetRadius * 0.7) / (this.planetRadius * 0.3);

                        // Check if this is water (negative density)
                        const isWater = cube.val.some(v => v < 0 && v > -50);

                        if (isWater) {
                            // Water - blue
                            colors.push(0.1, 0.3, 0.8);
                        } else if (normalizedHeight > 0.7) {
                            // Snow on peaks
                            colors.push(0.95, 0.95, 1.0);
                        } else if (normalizedHeight > 0.5) {
                            // Rocky mountains
                            colors.push(0.5, 0.5, 0.5);
                        } else if (normalizedHeight > 0.2) {
                            // Grass
                            colors.push(0.2, 0.6, 0.2);
                        } else if (normalizedHeight > 0) {
                            // Beach/dirt
                            colors.push(0.76, 0.7, 0.5);
                        } else {
                            // Ocean floor
                            colors.push(0.3, 0.4, 0.3);
                        }
                    }
                }
            }
        }

        const geometry = new THREE.BufferGeometry();
        geometry.setAttribute('position', new THREE.Float32BufferAttribute(vertices, 3));
        geometry.setAttribute('color', new THREE.Float32BufferAttribute(colors, 3));
        geometry.computeVertexNormals();

        return geometry;
    }

    generateWaterMesh() {
        const vertices = [];
        const colors = [];
        const isolevel = -5; // Water threshold

        for (let x = 0; x < this.voxelResolution - 1; x++) {
            for (let y = 0; y < this.voxelResolution - 1; y++) {
                for (let z = 0; z < this.voxelResolution - 1; z++) {
                    const cube = {
                        p: [
                            this.voxelToWorld(x, y, z),
                            this.voxelToWorld(x + 1, y, z),
                            this.voxelToWorld(x + 1, y, z + 1),
                            this.voxelToWorld(x, y, z + 1),
                            this.voxelToWorld(x, y + 1, z),
                            this.voxelToWorld(x + 1, y + 1, z),
                            this.voxelToWorld(x + 1, y + 1, z + 1),
                            this.voxelToWorld(x, y + 1, z + 1)
                        ],
                        val: [
                            Math.max(-20, this.getVoxel(x, y, z)),
                            Math.max(-20, this.getVoxel(x + 1, y, z)),
                            Math.max(-20, this.getVoxel(x + 1, y, z + 1)),
                            Math.max(-20, this.getVoxel(x, y, z + 1)),
                            Math.max(-20, this.getVoxel(x, y + 1, z)),
                            Math.max(-20, this.getVoxel(x + 1, y + 1, z)),
                            Math.max(-20, this.getVoxel(x + 1, y + 1, z + 1)),
                            Math.max(-20, this.getVoxel(x, y + 1, z + 1))
                        ]
                    };

                    // Only process if any voxel is water
                    if (cube.val.some(v => v < 0)) {
                        const triangles = this.marchingCubes.polygonise(cube, isolevel);

                        for (let i = 0; i < triangles.length; i++) {
                            const vert = triangles[i];
                            vertices.push(vert.x, vert.y, vert.z);
                            colors.push(0.0, 0.4, 0.9, 0.7); // Blue water with alpha
                        }
                    }
                }
            }
        }

        if (vertices.length === 0) return null;

        const geometry = new THREE.BufferGeometry();
        geometry.setAttribute('position', new THREE.Float32BufferAttribute(vertices, 3));

        return geometry;
    }

    raycastVoxel(origin, direction, maxDistance = 100) {
        const step = this.voxelSize * 0.5;
        const dir = direction.clone().normalize();

        for (let dist = 0; dist < maxDistance; dist += step) {
            const point = origin.clone().add(dir.clone().multiplyScalar(dist));
            const voxelPos = this.worldToVoxel(point);

            const density = this.getVoxel(voxelPos.x, voxelPos.y, voxelPos.z);

            if (density > 0) {
                return {
                    hit: true,
                    voxelPos: voxelPos,
                    worldPos: point,
                    distance: dist
                };
            }
        }

        return { hit: false };
    }

    modifyTerrain(voxelPos, radius, addTerrain = false) {
        const r = Math.ceil(radius);

        for (let dx = -r; dx <= r; dx++) {
            for (let dy = -r; dy <= r; dy++) {
                for (let dz = -r; dz <= r; dz++) {
                    const dist = Math.sqrt(dx * dx + dy * dy + dz * dz);
                    if (dist <= radius) {
                        const x = voxelPos.x + dx;
                        const y = voxelPos.y + dy;
                        const z = voxelPos.z + dz;

                        const currentDensity = this.getVoxel(x, y, z);

                        if (addTerrain) {
                            this.setVoxel(x, y, z, currentDensity + 10);
                        } else {
                            this.setVoxel(x, y, z, currentDensity - 10);
                        }
                    }
                }
            }
        }
    }
}
