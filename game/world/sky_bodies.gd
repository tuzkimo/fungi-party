class_name SkyBodies
extends Node3D

## 天上的太阳和月亮：挂在跟随相机的远平面上，脸永远正对玩家。
## 全部 unshaded + 自发光——否则太阳会给自己打光，出现一块暗面。

const SUN_COLOR := Color(1.0, 0.86, 0.30)
const SUN_FACE := Color(0.16, 0.10, 0.06)
const MOON_COLOR := Color(0.94, 0.93, 0.82)
const MOON_FACE := Color(0.20, 0.18, 0.16)
const CAP_COLOR := Color(0.62, 0.74, 0.92)
const GLOW_COLOR := Color(1.0, 0.85, 0.35, 0.18)

@export var daynight_path: NodePath

var _sun: Node3D
var _moon: Node3D
var _daynight: DayNight


func _ready() -> void:
	_daynight = get_node_or_null(daynight_path) as DayNight
	_sun = Node3D.new()
	_sun.name = "Sun"
	add_child(_sun)
	_build_sun()

	_moon = Node3D.new()
	_moon.name = "Moon"
	add_child(_moon)
	_build_moon()


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or _daynight == null:
		return
	var cam_pos := camera.global_position
	var t := _daynight.time_of_day

	var sun_dir := DayNight.sun_dir(t)
	_sun.global_position = cam_pos + sun_dir * Config.SUN_DISTANCE
	_sun.visible = DayNight.body_visible(sun_dir)
	if _sun.visible:
		_face(_sun, cam_pos)

	var moon_dir := DayNight.moon_dir(t)
	_moon.global_position = cam_pos + moon_dir * Config.SUN_DISTANCE
	_moon.visible = DayNight.body_visible(moon_dir)
	if _moon.visible:
		_face(_moon, cam_pos)


## 脸永远正对玩家。天体到头顶时方向与 UP 平行，look_at 会退化，换一个 up 垫上。
func _face(body: Node3D, cam_pos: Vector3) -> void:
	var dir := (cam_pos - body.global_position).normalized()
	body.look_at(cam_pos, Vector3.UP if absf(dir.y) < 0.95 else Vector3.BACK)


func _build_sun() -> void:
	var body := SphereMesh.new()
	body.radius = Config.SUN_RADIUS
	body.height = Config.SUN_RADIUS * 2.0
	body.radial_segments = 24
	body.rings = 12
	_sun.add_child(_part("Body", body, _glow(SUN_COLOR, 1.0), Vector3.ZERO, Vector3.ONE))

	var glow := SphereMesh.new()
	glow.radius = Config.SUN_RADIUS * 1.25
	glow.height = Config.SUN_RADIUS * 2.5
	glow.radial_segments = 24
	glow.rings = 12
	_sun.add_child(_part("Glow", glow, _glow(GLOW_COLOR, GLOW_COLOR.a), Vector3.ZERO, Vector3.ONE))

	# 墨镜：两片压扁的镜片 + 镜桥 + 两条镜腿，贴着脸放在 -Z 一侧
	var lens := CylinderMesh.new()
	lens.top_radius = 1.0
	lens.bottom_radius = 1.0
	lens.height = 0.5
	lens.radial_segments = 16
	for side in [-1.0, 1.0]:
		_sun.add_child(_part(
			"Lens", lens, _glow(SUN_FACE, 1.0),
			Vector3(side * 1.3, 0.9, -4.35), Vector3(1.0, 1.0, 1.0), Vector3(PI / 2.0, 0.0, 0.0)
		))
	var bridge := BoxMesh.new()
	bridge.size = Vector3(0.9, 0.22, 0.3)
	_sun.add_child(_part("Bridge", bridge, _glow(SUN_FACE, 1.0), Vector3(0.0, 0.9, -4.3), Vector3.ONE))
	var arm := BoxMesh.new()
	arm.size = Vector3(0.28, 0.18, 1.6)
	for side in [-1.0, 1.0]:
		_sun.add_child(_part(
			"Arm", arm, _glow(SUN_FACE, 1.0),
			Vector3(side * 2.7, 0.9, -3.4), Vector3.ONE, Vector3(0.0, side * 0.5, 0.0)
		))

	# 微微上扬的嘴：三段小方块拼一条弧
	var mouth := BoxMesh.new()
	mouth.size = Vector3(0.9, 0.22, 0.3)
	_sun.add_child(_part("MouthMid", mouth, _glow(SUN_FACE, 1.0), Vector3(0.0, -1.5, -4.2), Vector3.ONE))
	for side in [-1.0, 1.0]:
		_sun.add_child(_part(
			"MouthSide", mouth, _glow(SUN_FACE, 1.0),
			Vector3(side * 0.85, -1.2, -4.1), Vector3(1.0, 1.0, 1.0), Vector3(0.0, 0.0, side * 0.35)
		))


func _build_moon() -> void:
	var body := SphereMesh.new()
	body.radius = Config.MOON_RADIUS
	body.height = Config.MOON_RADIUS * 2.0
	body.radial_segments = 24
	body.rings = 12
	_moon.add_child(_part("Body", body, _glow(MOON_COLOR, 1.0), Vector3.ZERO, Vector3.ONE))

	# 睡帽：圆锥斜扣在头顶，帽尖一个小绒球
	var cap := CylinderMesh.new()
	cap.top_radius = 0.0
	cap.bottom_radius = 1.5
	cap.height = 2.1
	cap.radial_segments = 16
	_moon.add_child(_part(
		"Cap", cap, _glow(CAP_COLOR, 1.0), Vector3(0.5, 3.5, 0.0), Vector3.ONE, Vector3(0.0, 0.0, -0.4)
	))
	var pom := SphereMesh.new()
	pom.radius = 0.42
	pom.height = 0.84
	pom.radial_segments = 12
	pom.rings = 6
	_moon.add_child(_part("Pom", pom, _glow(Color(0.98, 0.98, 0.94), 1.0), Vector3(1.3, 4.4, 0.0), Vector3.ONE))

	# 两条闭着的眼睛：细扁条各斜一点
	var eye := BoxMesh.new()
	eye.size = Vector3(1.0, 0.16, 0.3)
	for side in [-1.0, 1.0]:
		_moon.add_child(_part(
			"Eye", eye, _glow(MOON_FACE, 1.0),
			Vector3(side * 1.05, 0.5, -3.05), Vector3.ONE, Vector3(0.0, 0.0, side * 0.25)
		))


func _part(
	part_name: String, mesh: Mesh, material: Material, pos: Vector3,
	scl: Vector3, rot: Vector3 = Vector3.ZERO
) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = part_name
	node.mesh = mesh
	node.material_override = material
	node.position = pos
	node.scale = scl
	node.rotation = rot
	return node


## 不受光、自发光的材质：天体不该有自己的暗面。
func _glow(color: Color, alpha: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color.r, color.g, color.b, alpha)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.6
	if alpha < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material
