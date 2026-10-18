class_name BombRing
extends Node3D

## 森林里的蘑菇圈：一圈石头 + 中间小火堆。只回答「玩家在不在圈里」，
## BombPanel 每帧来问（场景往返后旧引用会失效，所以不缓存）。写法与 StartGate 一致。

const STONE_COUNT := 10
const STONE_RING := 2.4
const STONE_MIN := 0.22
const STONE_MAX := 0.38
const STONE_COLOR := Color(0.28, 0.27, 0.30)
const LOG_COLOR := Color(0.20, 0.14, 0.10)
const FLAME_COLOR := Color(1.0, 0.58, 0.20)
const FIRE_HEIGHT := 0.45

var player_inside := false

var _area: Area3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("bomb_ring")
	_rng.seed = 1018
	_build_stones()
	_build_fire()

	_area = Area3D.new()
	_area.name = "Trigger"
	_area.position = Vector3(0.0, 1.0, 0.0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.2, 2.0, 3.2)
	shape.shape = box
	_area.add_child(shape)
	add_child(_area)


func _physics_process(_delta: float) -> void:
	player_inside = false
	for body in _area.get_overlapping_bodies():
		if body is Player:
			player_inside = true
			break


func _build_stones() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = STONE_COUNT
	for i in STONE_COUNT:
		var angle := TAU * float(i) / float(STONE_COUNT) + _rng.randf_range(-0.1, 0.1)
		var radius := STONE_RING + _rng.randf_range(-0.14, 0.14)
		var size := _rng.randf_range(STONE_MIN, STONE_MAX)
		var basis := Basis.IDENTITY.scaled(Vector3(size, size * 0.8, size))
		basis = basis.rotated(Vector3.UP, _rng.randf_range(0.0, TAU))
		multi.set_instance_transform(
			i, Transform3D(basis, Vector3(cos(angle) * radius, size * 0.6, sin(angle) * radius))
		)
	var stones := MultiMeshInstance3D.new()
	stones.name = "Stones"
	stones.multimesh = multi
	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = STONE_COLOR
	stone_mat.roughness = 0.9
	stones.material_override = stone_mat
	add_child(stones)


func _build_fire() -> void:
	var log_mesh := CylinderMesh.new()
	log_mesh.top_radius = 0.06
	log_mesh.bottom_radius = 0.08
	log_mesh.height = 0.6
	log_mesh.radial_segments = 8
	var log_mat := StandardMaterial3D.new()
	log_mat.albedo_color = LOG_COLOR
	log_mat.roughness = 0.95
	for i in 3:
		var log := MeshInstance3D.new()
		log.name = "Log%d" % i
		log.mesh = log_mesh
		log.material_override = log_mat
		log.rotation_degrees = Vector3(78.0, 60.0 * float(i), 0.0)
		log.position = Vector3(0.0, 0.1, 0.0)
		add_child(log)

	var flame := MeshInstance3D.new()
	flame.name = "Flame"
	var flame_mesh := SphereMesh.new()
	flame_mesh.radius = 0.24
	flame_mesh.height = 0.58
	flame_mesh.radial_segments = 12
	flame_mesh.rings = 6
	flame.mesh = flame_mesh
	var flame_mat := StandardMaterial3D.new()
	flame_mat.albedo_color = FLAME_COLOR
	flame_mat.emission_enabled = true
	flame_mat.emission = FLAME_COLOR
	flame_mat.emission_energy_multiplier = 1.4
	flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame.material_override = flame_mat
	flame.position = Vector3(0.0, FIRE_HEIGHT, 0.0)
	add_child(flame)

	var light := OmniLight3D.new()
	light.name = "FireLight"
	light.light_color = FLAME_COLOR
	light.light_energy = 1.2
	light.omni_range = 4.0
	light.position = Vector3(0.0, FIRE_HEIGHT + 0.4, 0.0)
	add_child(light)
