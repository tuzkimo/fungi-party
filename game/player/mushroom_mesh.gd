class_name MushroomMesh
extends Node3D

## 程序化生成蘑菇角色的全部外观。所有尺寸按「脚底 y=0」排布。
## 外观只在这里改；角色逻辑不引用这里的任何节点。

@export var cap_radius := 0.9
@export var cap_height := 0.55
@export var spot_count := 7
@export var body_height := 1.4
@export var tint_cap := Color(0.90, 0.22, 0.20)
@export var tint_body := Color(0.96, 0.78, 0.62)
@export var spot_shape := 0
@export var spot_color := Color(0.99, 0.97, 0.94)
@export var spot_glow := 0.0
@export var parts: Array[String] = []
@export var cap_tilt := 0.0
@export var cap_squash := 0.0

const OUTLINE_GROW := 0.018

static var _default_skin: MushroomSkin


## 默认外观的唯一来源是 MushroomSkin 的字段初值，不在这里另抄一份。
static func default_skin() -> MushroomSkin:
	if _default_skin == null:
		_default_skin = MushroomSkin.new()
	return _default_skin


## 只搬字段，不重建；调用方改完自己的覆盖再 build() 一次。
func use_skin(skin: MushroomSkin) -> void:
	var s := skin if skin != null else default_skin()
	tint_cap = s.tint_cap
	tint_body = s.tint_body
	spot_count = s.spot_count
	spot_shape = s.spot_shape
	spot_color = s.spot_color
	spot_glow = s.spot_glow
	parts = s.parts.duplicate()
	cap_tilt = s.cap_tilt
	cap_squash = s.cap_squash


func _ready() -> void:
	build()


func build() -> void:
	for child in get_children():
		remove_child(child)
		child.free()

	var mat_cap := _solid(tint_cap)
	var mat_body := _solid(tint_body)
	var mat_white := _solid(Color(0.99, 0.97, 0.94))
	var mat_dark := _solid(Color(0.10, 0.07, 0.07))
	var mat_outline := _outline()

	var body_y := body_height * 0.5
	var cap_y := body_height - 0.05

	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.45
	body_mesh.height = body_height
	body_mesh.radial_segments = 16
	body_mesh.rings = 8
	_add_part("Body", body_mesh, mat_body, Vector3(0.0, body_y, 0.0), Vector3.ONE)

	var cap_mesh := SphereMesh.new()
	cap_mesh.radius = cap_radius
	cap_mesh.height = cap_radius * 2.0
	cap_mesh.radial_segments = 32
	cap_mesh.rings = 16
	var cap_scale := Vector3(1.0, cap_height / cap_radius * (1.0 - cap_squash), 1.0)
	var cap_node := _add_part("Cap", cap_mesh, mat_cap, Vector3(0.0, cap_y, 0.0), cap_scale)
	cap_node.rotation_degrees.z = cap_tilt
	var cap_outline := _add_part("CapOutline", cap_mesh, mat_outline, Vector3(0.0, cap_y, 0.0), cap_scale)
	cap_outline.rotation_degrees.z = cap_tilt
	_add_part("BodyOutline", body_mesh, mat_outline, Vector3(0.0, body_y, 0.0), Vector3.ONE)

	var hand_mesh := SphereMesh.new()
	hand_mesh.radius = 1.0
	hand_mesh.height = 2.0
	hand_mesh.radial_segments = 12
	hand_mesh.rings = 6
	for side in [-1.0, 1.0]:
		var hand_pos := Vector3(0.56 * side, 0.62, 0.02)
		var hand_scale := Vector3(0.30, 0.13, 0.42)
		var label := "HandL" if side < 0.0 else "HandR"
		_add_part(label, hand_mesh, mat_body, hand_pos, hand_scale)
		_add_part(label + "Outline", hand_mesh, mat_outline, hand_pos, hand_scale)

	_build_spots(cap_y)

	var dot_mesh := SphereMesh.new()
	dot_mesh.radius = 1.0
	dot_mesh.height = 2.0
	dot_mesh.radial_segments = 12
	dot_mesh.rings = 6
	for side in [-1.0, 1.0]:
		_add_part(
			"EyeL" if side < 0.0 else "EyeR",
			dot_mesh,
			mat_dark,
			Vector3(0.14 * side, cap_y - 0.10, 0.855),
			Vector3(0.055, 0.055, 0.03),
		)
	_add_part("Mouth", dot_mesh, mat_dark, Vector3(0.0, cap_y - 0.30, 0.78), Vector3(0.13, 0.022, 0.02))

	_add_part("Belly", dot_mesh, mat_white, Vector3(0.0, 0.62, 0.41), Vector3(0.16, 0.24, 0.06))

	var mark_mesh := BoxMesh.new()
	mark_mesh.size = Vector3(0.14, 0.022, 0.022)
	for side in [-1.0, 1.0]:
		var mark := _add_part("BellyCross", mark_mesh, mat_dark, Vector3(0.0, 0.30, 0.44), Vector3.ONE)
		mark.rotation_degrees.z = 45.0 * side

	for part in parts:
		_add_accessory(part, cap_y)


func _build_spots(cap_y: float) -> void:
	if spot_count <= 0:
		return
	var mat_spot := _solid_glow(spot_color, spot_glow)

	var round_mesh := SphereMesh.new()
	round_mesh.radius = 1.0
	round_mesh.height = 2.0
	round_mesh.radial_segments = 12
	round_mesh.rings = 6

	var star_mesh := BoxMesh.new()
	star_mesh.size = Vector3(0.24, 0.05, 0.05)

	for i in spot_count:
		var angle := TAU * float(i) / float(spot_count) + 0.4
		var spread := 0.22 + 0.6 * float((i * 37) % 100) / 100.0
		var ring := cap_radius * sin(acos(spread)) * 0.92
		var spot_pos := Vector3(
			cos(angle) * ring,
			cap_y + cap_height * spread * 0.98,
			sin(angle) * ring,
		)
		var spot_scale := Vector3.ONE * (0.10 + 0.03 * float(i % 3))
		spot_scale.y *= 0.45
		match spot_shape:
			MushroomSkin.SpotShape.STAR:
				# 两道交叉的短棒凑成星，比球便宜也更像星星
				for quarter in [0.0, 90.0]:
					var bar := _add_part("Spot%d" % i, star_mesh, mat_spot, spot_pos, Vector3.ONE)
					bar.rotation_degrees = Vector3(0.0, rad_to_deg(angle) + quarter, 0.0)
			MushroomSkin.SpotShape.BLOB:
				_add_part("Spot%d" % i, round_mesh, mat_spot, spot_pos, spot_scale * Vector3(1.6, 0.5, 1.0))
			_:
				_add_part("Spot%d" % i, round_mesh, mat_spot, spot_pos, spot_scale)


## 零件白名单。名字不在表里只告警，不崩 —— 存档里的旧皮肤可能带已经删掉的名字。
func _add_accessory(part: String, cap_y: float) -> void:
	var mat_dark := _solid(Color(0.10, 0.07, 0.07))
	var mat_light := _solid(Color(0.86, 0.88, 0.94))
	var mat_hide := _solid(tint_cap.darkened(0.2))
	var outline := _outline()
	match part:
		"sword":
			# 拎在右手边、往外套一点。帽子半径 0.9，剑必须整根在外面才看得见
			var blade := BoxMesh.new()
			blade.size = Vector3(0.05, 0.85, 0.11)
			var blade_node := _add_part("SwordBlade", blade, mat_light, Vector3(0.93, 1.02, 0.06), Vector3.ONE)
			blade_node.rotation_degrees.z = -28.0
			var blade_outline := _add_part("SwordBladeOutline", blade, outline, Vector3(0.93, 1.02, 0.06), Vector3.ONE)
			blade_outline.rotation_degrees.z = -28.0
			var guard := BoxMesh.new()
			guard.size = Vector3(0.30, 0.05, 0.07)
			var guard_node := _add_part("SwordGuard", guard, mat_light, Vector3(0.735, 0.635, 0.06), Vector3.ONE)
			guard_node.rotation_degrees.z = -28.0
			var hilt := BoxMesh.new()
			hilt.size = Vector3(0.06, 0.22, 0.06)
			var hilt_node := _add_part("SwordHilt", hilt, mat_dark, Vector3(0.70, 0.52, 0.06), Vector3.ONE)
			hilt_node.rotation_degrees.z = -28.0
		"cape":
			var cape := CylinderMesh.new()
			cape.top_radius = 0.40
			cape.bottom_radius = 0.66
			cape.height = 1.05
			cape.radial_segments = 16
			_add_part("Cape", cape, mat_hide, Vector3(0.0, 1.0, -0.18), Vector3.ONE)
			_add_part("CapeOutline", cape, outline, Vector3(0.0, 1.0, -0.18), Vector3.ONE)
		"horned_helmet":
			var dome := SphereMesh.new()
			dome.radius = 0.34
			dome.radial_segments = 20
			dome.rings = 10
			var dome_pos := Vector3(0.0, cap_y + cap_height * 0.85, 0.0)
			_add_part("HelmetDome", dome, mat_dark, dome_pos, Vector3(1.0, 0.55, 1.0))
			var horn := CylinderMesh.new()
			horn.top_radius = 0.02
			horn.bottom_radius = 0.09
			horn.height = 0.34
			horn.radial_segments = 10
			for side in [-1.0, 1.0]:
				var node := _add_part("HelmetHorn", horn, mat_light, Vector3(0.22 * side, cap_y + 0.60, 0.0), Vector3.ONE)
				node.rotation_degrees.z = -35.0 * side
		"crown":
			var gold := _solid(Color(0.98, 0.82, 0.30))
			var band := CylinderMesh.new()
			band.top_radius = 0.30
			band.bottom_radius = 0.26
			band.height = 0.12
			band.radial_segments = 16
			var band_y := cap_y + cap_height * 0.92
			_add_part("CrownBand", band, gold, Vector3(0.0, band_y, 0.0), Vector3.ONE)
			var tooth := BoxMesh.new()
			tooth.size = Vector3(0.07, 0.13, 0.06)
			for i in 5:
				var a := TAU * float(i) / 5.0
				var node := _add_part(
					"CrownTooth%d" % i, tooth, gold,
					Vector3(cos(a) * 0.27, band_y + 0.11, sin(a) * 0.27), Vector3.ONE,
				)
				node.rotation_degrees.y = rad_to_deg(a)
		"bloom":
			var petal := SphereMesh.new()
			petal.radius = 1.0
			petal.radial_segments = 12
			petal.rings = 6
			var tip := Vector3(0.0, cap_y + cap_height * 0.98, 0.0)
			_add_part("BloomPetal", petal, _solid(Color(0.99, 0.72, 0.80)), tip, Vector3(0.16, 0.06, 0.16))
			_add_part("BloomCore", petal, _solid(Color(0.98, 0.86, 0.36)), tip, Vector3(0.06, 0.05, 0.06))
		"wide_brim":
			var brim := SphereMesh.new()
			brim.radius = 1.0
			brim.radial_segments = 24
			brim.rings = 12
			var brim_scale := Vector3(cap_radius * 1.18, 0.06, cap_radius * 1.18)
			var brim_pos := Vector3(0.0, cap_y - cap_height * 0.12, 0.0)
			_add_part("Brim", brim, _solid(tint_cap.darkened(0.1)), brim_pos, brim_scale)
			_add_part("BrimOutline", brim, outline, brim_pos, brim_scale)
		_:
			push_warning("未知零件：%s" % part)


func _add_part(part_name: String, mesh: Mesh, material: Material, pos: Vector3, scl: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = part_name
	node.mesh = mesh
	node.material_override = material
	node.position = pos
	node.scale = scl
	add_child(node)
	return node


func _solid(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	return mat


func _solid_glow(color: Color, energy: float) -> StandardMaterial3D:
	var mat := _solid(color)
	if energy > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = energy
	return mat


func _outline() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.09, 0.06, 0.06)
	mat.cull_mode = BaseMaterial3D.CULL_FRONT
	mat.grow = true
	mat.grow_amount = OUTLINE_GROW
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat
