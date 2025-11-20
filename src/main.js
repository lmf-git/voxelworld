import * as THREE from 'three';
import { SphericalVoxelWorld } from './SphericalVoxelWorld.js';

class VoxelWorldApp {
    constructor() {
        this.scene = new THREE.Scene();
        this.camera = new THREE.PerspectiveCamera(75, window.innerWidth / window.innerHeight, 0.1, 1000);
        this.renderer = new THREE.WebGLRenderer({ antialias: true });

        this.renderer.setSize(window.innerWidth, window.innerHeight);
        document.body.appendChild(this.renderer.domElement);

        // Camera setup
        this.camera.position.set(100, 50, 100);
        this.camera.lookAt(0, 0, 0);

        // Camera controls
        this.cameraRotation = { x: 0, y: 0 };
        this.cameraVelocity = new THREE.Vector3();
        this.moveSpeed = 0.5;
        this.keys = {};

        // Mouse controls
        this.isPointerLocked = false;
        this.mouseButtons = {};

        // Raycaster for terrain interaction
        this.raycaster = new THREE.Raycaster();

        // Scene setup
        this.setupScene();
        this.setupControls();
        this.setupUI();

        // Create voxel world
        console.log('Generating voxel world...');
        this.voxelWorld = new SphericalVoxelWorld(50, 64);
        console.log('Generating mesh...');
        this.updateMeshes();
        console.log('World generated!');

        // Animation loop
        this.lastTime = performance.now();
        this.animate();
    }

    setupScene() {
        // Lighting
        const ambientLight = new THREE.AmbientLight(0xffffff, 0.6);
        this.scene.add(ambientLight);

        const directionalLight1 = new THREE.DirectionalLight(0xffffff, 0.8);
        directionalLight1.position.set(100, 100, 50);
        this.scene.add(directionalLight1);

        const directionalLight2 = new THREE.DirectionalLight(0xffffff, 0.3);
        directionalLight2.position.set(-100, -50, -50);
        this.scene.add(directionalLight2);

        // Background
        this.scene.background = new THREE.Color(0x000011);

        // Stars
        this.createStars();
    }

    createStars() {
        const starsGeometry = new THREE.BufferGeometry();
        const starPositions = [];

        for (let i = 0; i < 3000; i++) {
            const theta = Math.random() * Math.PI * 2;
            const phi = Math.acos(Math.random() * 2 - 1);
            const r = 300 + Math.random() * 200;

            starPositions.push(
                r * Math.sin(phi) * Math.cos(theta),
                r * Math.sin(phi) * Math.sin(theta),
                r * Math.cos(phi)
            );
        }

        starsGeometry.setAttribute('position', new THREE.Float32BufferAttribute(starPositions, 3));
        const starsMaterial = new THREE.PointsMaterial({ color: 0xffffff, size: 0.5 });
        const stars = new THREE.Points(starsGeometry, starsMaterial);
        this.scene.add(stars);
    }

    setupControls() {
        // Keyboard
        window.addEventListener('keydown', (e) => {
            this.keys[e.code] = true;
        });

        window.addEventListener('keyup', (e) => {
            this.keys[e.code] = false;
        });

        // Mouse
        this.renderer.domElement.addEventListener('click', () => {
            this.renderer.domElement.requestPointerLock();
        });

        document.addEventListener('pointerlockchange', () => {
            this.isPointerLocked = document.pointerLockElement === this.renderer.domElement;
        });

        document.addEventListener('mousemove', (e) => {
            if (this.isPointerLocked) {
                this.cameraRotation.y -= e.movementX * 0.002;
                this.cameraRotation.x -= e.movementY * 0.002;
                this.cameraRotation.x = Math.max(-Math.PI / 2, Math.min(Math.PI / 2, this.cameraRotation.x));
            }
        });

        // Mouse buttons
        window.addEventListener('mousedown', (e) => {
            if (this.isPointerLocked) {
                this.mouseButtons[e.button] = true;
                this.handleTerrainModification(e.shiftKey);
            }
        });

        window.addEventListener('mouseup', (e) => {
            this.mouseButtons[e.button] = false;
        });

        // Window resize
        window.addEventListener('resize', () => {
            this.camera.aspect = window.innerWidth / window.innerHeight;
            this.camera.updateProjectionMatrix();
            this.renderer.setSize(window.innerWidth, window.innerHeight);
        });
    }

    setupUI() {
        document.getElementById('regenerate').addEventListener('click', () => {
            this.regenerateWorld();
        });

        document.getElementById('addTerrain').addEventListener('click', () => {
            this.handleTerrainModification(true);
        });

        document.getElementById('removeTerrain').addEventListener('click', () => {
            this.handleTerrainModification(false);
        });
    }

    handleTerrainModification(addTerrain = false) {
        // Raycast from camera
        this.raycaster.setFromCamera({ x: 0, y: 0 }, this.camera);

        const result = this.voxelWorld.raycastVoxel(
            this.camera.position,
            this.raycaster.ray.direction,
            150
        );

        if (result.hit) {
            console.log(addTerrain ? 'Adding terrain' : 'Removing terrain', result.voxelPos);
            this.voxelWorld.modifyTerrain(result.voxelPos, 2, addTerrain);
            this.updateMeshes();
        }
    }

    updateMeshes() {
        // Remove old meshes
        if (this.terrainMesh) {
            this.scene.remove(this.terrainMesh);
            this.terrainMesh.geometry.dispose();
            this.terrainMesh.material.dispose();
        }

        if (this.waterMesh) {
            this.scene.remove(this.waterMesh);
            this.waterMesh.geometry.dispose();
            this.waterMesh.material.dispose();
        }

        // Generate new meshes
        const terrainGeometry = this.voxelWorld.generateMesh();
        const terrainMaterial = new THREE.MeshStandardMaterial({
            vertexColors: true,
            flatShading: false,
            roughness: 0.8,
            metalness: 0.2
        });

        this.terrainMesh = new THREE.Mesh(terrainGeometry, terrainMaterial);
        this.scene.add(this.terrainMesh);

        // Water mesh
        const waterGeometry = this.voxelWorld.generateWaterMesh();
        if (waterGeometry) {
            const waterMaterial = new THREE.MeshStandardMaterial({
                color: 0x1166ff,
                transparent: true,
                opacity: 0.7,
                roughness: 0.1,
                metalness: 0.3
            });

            this.waterMesh = new THREE.Mesh(waterGeometry, waterMaterial);
            this.scene.add(this.waterMesh);
        }

        // Update stats
        this.updateStats();
    }

    regenerateWorld() {
        console.log('Regenerating world...');
        this.voxelWorld.generateTerrain();
        this.updateMeshes();
        console.log('World regenerated!');
    }

    updateStats() {
        const triangles = this.terrainMesh.geometry.attributes.position.count / 3;
        const waterTriangles = this.waterMesh ? this.waterMesh.geometry.attributes.position.count / 3 : 0;

        document.getElementById('stats').innerHTML = `
            <div>Terrain Triangles: ${triangles.toLocaleString()}</div>
            <div>Water Triangles: ${waterTriangles.toLocaleString()}</div>
            <div>Position: (${this.camera.position.x.toFixed(1)}, ${this.camera.position.y.toFixed(1)}, ${this.camera.position.z.toFixed(1)})</div>
        `;
    }

    updateCamera(deltaTime) {
        // Calculate movement direction
        const forward = new THREE.Vector3(0, 0, -1);
        const right = new THREE.Vector3(1, 0, 0);
        const up = new THREE.Vector3(0, 1, 0);

        // Apply camera rotation to directions
        forward.applyQuaternion(this.camera.quaternion);
        right.applyQuaternion(this.camera.quaternion);

        // Movement input
        const movement = new THREE.Vector3();

        if (this.keys['KeyW']) movement.add(forward);
        if (this.keys['KeyS']) movement.sub(forward);
        if (this.keys['KeyD']) movement.add(right);
        if (this.keys['KeyA']) movement.sub(right);
        if (this.keys['Space']) movement.add(up);
        if (this.keys['ControlLeft'] || this.keys['ControlRight']) movement.sub(up);

        if (movement.length() > 0) {
            movement.normalize();
            this.cameraVelocity.lerp(movement.multiplyScalar(this.moveSpeed), 0.3);
        } else {
            this.cameraVelocity.multiplyScalar(0.9);
        }

        // Speed boost
        const speedMultiplier = this.keys['ShiftLeft'] || this.keys['ShiftRight'] ? 3 : 1;

        // Apply movement
        this.camera.position.add(this.cameraVelocity.clone().multiplyScalar(speedMultiplier * deltaTime * 60));

        // Apply rotation
        this.camera.quaternion.setFromEuler(new THREE.Euler(this.cameraRotation.x, this.cameraRotation.y, 0, 'YXZ'));
    }

    animate() {
        requestAnimationFrame(() => this.animate());

        const currentTime = performance.now();
        const deltaTime = (currentTime - this.lastTime) / 1000;
        this.lastTime = currentTime;

        this.updateCamera(deltaTime);

        // Slowly rotate the planet if idle
        if (!this.isPointerLocked && this.terrainMesh) {
            this.terrainMesh.rotation.y += 0.001;
            if (this.waterMesh) {
                this.waterMesh.rotation.y += 0.001;
            }
        }

        this.renderer.render(this.scene, this.camera);

        // Update stats occasionally
        if (Math.random() < 0.01) {
            this.updateStats();
        }
    }
}

// Initialize the application
new VoxelWorldApp();
