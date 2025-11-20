class_name SimplexNoise3D
extends RefCounted

## 3D Simplex Noise implementation for terrain generation

var grad3: Array[Vector3] = [
	Vector3(1, 1, 0), Vector3(-1, 1, 0), Vector3(1, -1, 0), Vector3(-1, -1, 0),
	Vector3(1, 0, 1), Vector3(-1, 0, 1), Vector3(1, 0, -1), Vector3(-1, 0, -1),
	Vector3(0, 1, 1), Vector3(0, -1, 1), Vector3(0, 1, -1), Vector3(0, -1, -1)
]

var p: Array[int] = []
var perm: Array[int] = []

func _init(seed_value: int = 0) -> void:
	if seed_value == 0:
		seed_value = randi()

	# Initialize permutation table
	p.resize(256)
	for i in range(256):
		p[i] = int(_seeded_random(seed_value + i) * 256)

	# Extend permutation table
	perm.resize(512)
	for i in range(512):
		perm[i] = p[i & 255]

func _seeded_random(s: float) -> float:
	var x = sin(s) * 10000.0
	return x - floor(x)

func _dot(g: Vector3, x: float, y: float, z: float) -> float:
	return g.x * x + g.y * y + g.z * z

func noise(xin: float, yin: float, zin: float) -> float:
	var n0: float
	var n1: float
	var n2: float
	var n3: float

	# Skewing and unskewing factors
	const F3: float = 1.0 / 3.0
	var s: float = (xin + yin + zin) * F3
	var i: int = int(floor(xin + s))
	var j: int = int(floor(yin + s))
	var k: int = int(floor(zin + s))

	const G3: float = 1.0 / 6.0
	var t: float = float(i + j + k) * G3
	var X0: float = float(i) - t
	var Y0: float = float(j) - t
	var Z0: float = float(k) - t
	var x0: float = xin - X0
	var y0: float = yin - Y0
	var z0: float = zin - Z0

	# Determine which simplex we are in
	var i1: int
	var j1: int
	var k1: int
	var i2: int
	var j2: int
	var k2: int

	if x0 >= y0:
		if y0 >= z0:
			i1 = 1; j1 = 0; k1 = 0; i2 = 1; j2 = 1; k2 = 0
		elif x0 >= z0:
			i1 = 1; j1 = 0; k1 = 0; i2 = 1; j2 = 0; k2 = 1
		else:
			i1 = 0; j1 = 0; k1 = 1; i2 = 1; j2 = 0; k2 = 1
	else:
		if y0 < z0:
			i1 = 0; j1 = 0; k1 = 1; i2 = 0; j2 = 1; k2 = 1
		elif x0 < z0:
			i1 = 0; j1 = 1; k1 = 0; i2 = 0; j2 = 1; k2 = 1
		else:
			i1 = 0; j1 = 1; k1 = 0; i2 = 1; j2 = 1; k2 = 0

	var x1: float = x0 - float(i1) + G3
	var y1: float = y0 - float(j1) + G3
	var z1: float = z0 - float(k1) + G3
	var x2: float = x0 - float(i2) + 2.0 * G3
	var y2: float = y0 - float(j2) + 2.0 * G3
	var z2: float = z0 - float(k2) + 2.0 * G3
	var x3: float = x0 - 1.0 + 3.0 * G3
	var y3: float = y0 - 1.0 + 3.0 * G3
	var z3: float = z0 - 1.0 + 3.0 * G3

	var ii: int = i & 255
	var jj: int = j & 255
	var kk: int = k & 255
	var gi0: int = perm[ii + perm[jj + perm[kk]]] % 12
	var gi1: int = perm[ii + i1 + perm[jj + j1 + perm[kk + k1]]] % 12
	var gi2: int = perm[ii + i2 + perm[jj + j2 + perm[kk + k2]]] % 12
	var gi3: int = perm[ii + 1 + perm[jj + 1 + perm[kk + 1]]] % 12

	var t0: float = 0.6 - x0 * x0 - y0 * y0 - z0 * z0
	if t0 < 0.0:
		n0 = 0.0
	else:
		t0 *= t0
		n0 = t0 * t0 * _dot(grad3[gi0], x0, y0, z0)

	var t1: float = 0.6 - x1 * x1 - y1 * y1 - z1 * z1
	if t1 < 0.0:
		n1 = 0.0
	else:
		t1 *= t1
		n1 = t1 * t1 * _dot(grad3[gi1], x1, y1, z1)

	var t2: float = 0.6 - x2 * x2 - y2 * y2 - z2 * z2
	if t2 < 0.0:
		n2 = 0.0
	else:
		t2 *= t2
		n2 = t2 * t2 * _dot(grad3[gi2], x2, y2, z2)

	var t3: float = 0.6 - x3 * x3 - y3 * y3 - z3 * z3
	if t3 < 0.0:
		n3 = 0.0
	else:
		t3 *= t3
		n3 = t3 * t3 * _dot(grad3[gi3], x3, y3, z3)

	return 32.0 * (n0 + n1 + n2 + n3)
