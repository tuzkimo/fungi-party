class_name BombArena
extends Node3D

## 蘑菇圈场地：地面圆盘 + 一圈石头（MultiMesh）+ 中间篝火。只管画，不管规则。

const GROUND_RADIUS := 9.0
const GROUND_COLOR := Color(0.24, 0.21, 0.17)
const STONE_COUNT := 12
const STONE_RING := 3.7
const STONE_MIN := 0.30
const STONE_MAX := 0.52
const STONE_COLOR := Color(0.36, 0.35, 0.38)
const LOG_COLOR := Color(0.20, 0.14, 0.10)
const FLAME_COLOR := Color(1.0, 0.55, 0.18)
const FIRE_HEIGHT := 0.55
const SKY_TOP := Color(0.05, 0.06, 0.10)
const SKY_BOTTOM := Color(0.16, 0.13, 0.12)

var _rng := RandomNumberGenerator.new()


func build() -> void:
	_rng.seed = 20261018
	_build_environment()
	_build_ground()
	_build_stones()
	_build_fire()


## 每轮点燃时炸弹从这里飞出来。
func fire_position() -> Vector3:
	return Vector3(0.0, FIRE_HEIGHT, 0.0)


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = SKY_TOP
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = SKY_BOTTOM.lightened(0.35)
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	# 远处用雾挡掉，不做大的森林
	env.fog_enabled = true
	env.fog_light_color = SKY_BOTTOM
	env.fog_density = 0.055
	var node := WorldEnvironment.new()
	node.name = "Environment"
	node.environment = env
	add_child(node)

	# 手机小屏要看得清颜色，给一盏很弱的顶光把形体拉出来
	var moon := DirectionalLight3D.new()
	moon.name = "Moon"
	moon.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	moon.light_energy = 0.6
	moon.light_color = Color(0.72, 0.78, 0.95)
	add_child(moon)


func _build_ground() -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = GROUND_RADIUS
	mesh.bottom_radius = GROUND_RADIUS
	mesh.height = 0.2
	mesh.radial_segments = 32
	mesh.rings = 1
	var disc := MeshInstance3D.new()
	disc.name = "Ground"
	disc.mesh = mesh
	disc.position = Vector3(0.0, -0.1, 0.0)
	disc.material_override = _solid(GROUND_COLOR, 0.95)
	add_child(disc)


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
		var angle := TAU * float(i) / float(STONE_COUNT) + _rng.randf_range(-0.08, 0.08)
		var radius := STONE_RING + _rng.randf_range(-0.16, 0.16)
		var size := _rng.randf_range(STONE_MIN, STONE_MAX)
		var basis := Basis.IDENTITY.scaled(Vector3(size, size * 0.85, size))
		basis = basis.rotated(Vector3.UP, _rng.randf_range(0.0, TAU))
		var pos := Vector3(cos(angle) * radius, size * 0.7, sin(angle) * radius)
		multi.set_instance_transform(i, Transform3D(basis, pos))
	var stones := MultiMeshInstance3D.new()
	stones.name = "Stones"
	stones.multimesh = multi
	stones.material_override = _solid(STONE_COLOR, 0.9)
	add_child(stones)


func _build_fire() -> void:
	var log_mesh := CylinderMesh.new()
	log_mesh.top_radius = 0.09
	log_mesh.bottom_radius = 0.11
	log_mesh.height = 0.9
	log_mesh.radial_segments = 8
	var log_mat := _solid(LOG_COLOR, 0.95)
	for i in 3:
		var log := MeshInstance3D.new()
		log.name = "Log%d" % i
		log.mesh = log_mesh
		log.material_override = log_mat
		log.rotation_degrees = Vector3(78.0, 60.0 * float(i), 0.0)
		log.position = Vector3(0.0, 0.14, 0.0)
		add_child(log)

	var flame := MeshInstance3D.new()
	flame.name = "Flame"
	var flame_mesh := SphereMesh.new()
	flame_mesh.radius = 0.42
	flame_mesh.height = 0.84
	flame_mesh.radial_segments = 12
	flame_mesh.rings = 6
	flame.mesh = flame_mesh
	var flame_mat := StandardMaterial3D.new()
	flame_mat.albedo_color = FLAME_COLOR
	flame_mat.emission_enabled = true
	flame_mat.emission = FLAME_COLOR
	flame_mat.emission_energy_multiplier = 1.6
	flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame.material_override = flame_mat
	flame.position = fire_position()
	flame.scale = Vector3(1.0, 1.2, 1.0)
	add_child(flame)

	var light := OmniLight3D.new()
	light.name = "FireLight"
	light.light_color = FLAME_COLOR
	light.light_energy = 1.8
	light.omni_range = 6.0
	light.position = fire_position() + Vector3(0.0, 0.5, 0.0)
	add_child(light)


func _solid(color: Color, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	return mat
