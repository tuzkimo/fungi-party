class_name MushroomMesh
extends Node3D

## 程序化生成蘑菇角色的全部外观。所有尺寸按「脚底 y=0」排布。
## 外观只在这里改；角色逻辑不引用这里的任何节点。

## 帽子剖面的「尖度」：1 是圆锥、2 是正球面。取中间偏尖 = 圆角三角。
const CAP_SHARPNESS := 1.45
## 帽子绕一圈的分段数。32 段配圆角三角够圆了，再多就是浪费。
const CAP_SEGMENTS := 28
const CAP_PROFILE_STEPS := 24
## 零件转向：剑是往外斜挑的，正竖直会整根埋进帽子。
const SWORD_TILT := -45.0

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


## 帽子底面（y=0 那个平面的世界高度）。
func cap_base() -> float:
	return body_height - 0.05 - cap_height


## y_norm 0 是帽子底、1 是顶尖。返回该高度处帽子的水平半径。
func cap_radius_at(y_norm: float) -> float:
	var y := clampf(y_norm, 0.0, 1.0)
	var shape := pow(maxf(0.0, 1.0 - pow(y, CAP_SHARPNESS)), 1.0 / CAP_SHARPNESS)
	return shape * cap_radius


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

	var cap_mesh := _revolve_cap()
	var cap_scale := Vector3(1.0, 1.0 - cap_squash, 1.0)
	var cap_pos := Vector3(0.0, cap_base(), 0.0)
	var cap_node := _add_part("Cap", cap_mesh, mat_cap, cap_pos, cap_scale)
	cap_node.rotation_degrees.z = cap_tilt
	var cap_outline := _add_part("CapOutline", cap_mesh, mat_outline, cap_pos, cap_scale)
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

	_build_spots()

	var dot_mesh := SphereMesh.new()
	dot_mesh.radius = 1.0
	dot_mesh.height = 2.0
	dot_mesh.radial_segments = 12
	dot_mesh.rings = 6
	# 脸贴在帽子正面上：z 由那个高度上的帽子半径反算，帽子轮廓改了这个跟着走
	for side in [-1.0, 1.0]:
		var eye_x: float = 0.14 * float(side)
		var eye_y_norm := 0.41
		var eye_ring := cap_radius_at(eye_y_norm)
		_add_part(
			"EyeL" if side < 0.0 else "EyeR",
			dot_mesh,
			mat_dark,
			Vector3(
				eye_x,
				cap_base() + eye_y_norm * cap_height * 2.0,
				sqrt(maxf(0.0, eye_ring * eye_ring - eye_x * eye_x)) * 0.97,
			),
			Vector3(0.055, 0.055, 0.03),
		)
	var mouth_y_norm := 0.23
	_add_part(
		"Mouth", dot_mesh, mat_dark,
		Vector3(0.0, cap_base() + mouth_y_norm * cap_height * 2.0, cap_radius_at(mouth_y_norm) * 0.97),
		Vector3(0.13, 0.022, 0.02),
	)

	_add_part("Belly", dot_mesh, mat_white, Vector3(0.0, 0.62, 0.41), Vector3(0.16, 0.24, 0.06))

	var mark_mesh := BoxMesh.new()
	mark_mesh.size = Vector3(0.14, 0.022, 0.022)
	for side in [-1.0, 1.0]:
		var mark := _add_part("BellyCross", mark_mesh, mat_dark, Vector3(0.0, 0.30, 0.44), Vector3.ONE)
		mark.rotation_degrees.z = 45.0 * side

	for part in parts:
		_add_accessory(part)


## 帽子是绕 Y 轴转一圈的旋转体，剖面用超椭圆：尖度 1 是圆锥、2 是球。
func _revolve_cap() -> ArrayMesh:
	var profile := PackedVector2Array()
	profile.append(Vector2(0.0, 0.0))
	for i in CAP_PROFILE_STEPS:
		var y := float(i) / float(CAP_PROFILE_STEPS - 1)
		profile.append(Vector2(cap_radius_at(y) / cap_radius, y))

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in CAP_SEGMENTS:
		var a0 := TAU * float(i) / float(CAP_SEGMENTS)
		var a1 := TAU * float(i + 1) / float(CAP_SEGMENTS)
		var c0 := cos(a0)
		var s0 := sin(a0)
		var c1 := cos(a1)
		var s1 := sin(a1)
		for j in profile.size() - 1:
			var p0 := profile[j]
			var p1 := profile[j + 1]
			var r0 := p0.x * cap_radius
			var r1 := p1.x * cap_radius
			var y0 := p0.y * cap_height * 2.0
			var y1 := p1.y * cap_height * 2.0
			# 这个绕序法线朝外；反过来就整颗里朝外（test_cap_normals_point_out 钉住）
			_quad(st, Vector3(c1 * r0, y0, s1 * r0), Vector3(c1 * r1, y1, s1 * r1),
				Vector3(c0 * r1, y1, s0 * r1), Vector3(c0 * r0, y0, s0 * r0))
	st.generate_normals()
	return st.commit()


static func _quad(st: SurfaceTool, v00: Vector3, v01: Vector3, v11: Vector3, v10: Vector3) -> void:
	st.add_vertex(v00)
	st.add_vertex(v01)
	st.add_vertex(v11)
	st.add_vertex(v00)
	st.add_vertex(v11)
	st.add_vertex(v10)


func _build_spots() -> void:
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
		var y_norm := 0.18 + 0.7 * float((i * 37) % 100) / 100.0
		# 贴着帽子表面放：半径取那个高度上的帽子半径，稍微往里坐一点
		var ring := cap_radius_at(y_norm) * 0.93
		var spot_pos := Vector3(
			cos(angle) * ring,
			cap_base() + y_norm * cap_height * 2.0,
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
func _add_accessory(part: String) -> void:
	var mat_dark := _solid(Color(0.10, 0.07, 0.07))
	var mat_steel := _solid(Color(0.88, 0.90, 0.96))
	var mat_hide := _solid(tint_cap.darkened(0.2))
	var outline := _outline()
	match part:
		"sword":
			# 剑搁在右手边往斜上方挑：帽子底下半径 0.9，竖直放会整根埋进去
			var tilt := Vector3(0.0, 0.0, SWORD_TILT)
			var axis := Vector2(sin(deg_to_rad(-SWORD_TILT)), cos(deg_to_rad(-SWORD_TILT)))
			var guard_pos := Vector2(0.87, 0.60)

			# 剑身：四棱锥，底宽顶尖收成一点；压扁 z 做出刃口
			var blade := CylinderMesh.new()
			blade.top_radius = 0.0
			blade.bottom_radius = 0.085
			blade.height = 0.60
			blade.radial_segments = 4
			var blade_pos := guard_pos + axis * (0.05 + 0.30)
			for mat in [mat_steel, outline]:
				var node := _add_part(
					"SwordBlade" if mat == mat_steel else "SwordBladeOutline",
					blade, mat,
					Vector3(blade_pos.x, blade_pos.y, 0.06),
					Vector3(1.0, 1.0, 0.45),
				)
				node.rotation_degrees = tilt

			# 护手：比剑身宽一截才看得出是剑
			var guard := BoxMesh.new()
			guard.size = Vector3(0.34, 0.055, 0.085)
			var guard_node := _add_part(
				"SwordGuard", guard, mat_steel,
				Vector3(guard_pos.x, guard_pos.y, 0.06), Vector3.ONE,
			)
			guard_node.rotation_degrees = tilt

			# 柄和剑首
			var grip := CylinderMesh.new()
			grip.top_radius = 0.032
			grip.bottom_radius = 0.032
			grip.height = 0.18
			grip.radial_segments = 8
			var grip_pos := guard_pos - axis * 0.12
			var grip_node := _add_part(
				"SwordGrip", grip, mat_dark,
				Vector3(grip_pos.x, grip_pos.y, 0.06), Vector3.ONE,
			)
			grip_node.rotation_degrees = tilt

			var pommel := SphereMesh.new()
			pommel.radius = 1.0
			pommel.radial_segments = 10
			pommel.rings = 6
			var pommel_pos := guard_pos - axis * 0.23
			_add_part(
				"SwordPommel", pommel, mat_steel,
				Vector3(pommel_pos.x, pommel_pos.y, 0.06),
				Vector3.ONE * 0.055,
			)
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
			var dome_pos := Vector3(0.0, body_height - 0.05 + cap_height * 0.7, 0.0)
			_add_part("HelmetDome", dome, mat_dark, dome_pos, Vector3(1.0, 0.55, 1.0))
			var horn := CylinderMesh.new()
			horn.top_radius = 0.02
			horn.bottom_radius = 0.09
			horn.height = 0.34
			horn.radial_segments = 10
			for side in [-1.0, 1.0]:
				var node := _add_part(
					"HelmetHorn", horn, mat_steel,
					Vector3(0.22 * side, body_height + 0.30, 0.0), Vector3.ONE,
				)
				node.rotation_degrees.z = -35.0 * side
		"crown":
			var gold := _solid(Color(0.98, 0.82, 0.30))
			var band := CylinderMesh.new()
			band.top_radius = 0.26
			band.bottom_radius = 0.22
			band.height = 0.12
			band.radial_segments = 16
			var band_y := body_height + 0.42
			_add_part("CrownBand", band, gold, Vector3(0.0, band_y, 0.0), Vector3.ONE)
			var tooth := BoxMesh.new()
			tooth.size = Vector3(0.07, 0.13, 0.06)
			for i in 5:
				var a := TAU * float(i) / 5.0
				var node := _add_part(
					"CrownTooth%d" % i, tooth, gold,
					Vector3(cos(a) * 0.23, band_y + 0.11, sin(a) * 0.23), Vector3.ONE,
				)
				node.rotation_degrees.y = rad_to_deg(a)
		"bloom":
			var petal := SphereMesh.new()
			petal.radius = 1.0
			petal.radial_segments = 12
			petal.rings = 6
			var tip := Vector3(0.0, body_height + 0.48, 0.0)
			_add_part("BloomPetal", petal, _solid(Color(0.99, 0.72, 0.80)), tip, Vector3(0.16, 0.06, 0.16))
			_add_part("BloomCore", petal, _solid(Color(0.98, 0.86, 0.36)), tip, Vector3(0.06, 0.05, 0.06))
		"wide_brim":
			var brim := SphereMesh.new()
			brim.radius = 1.0
			brim.radial_segments = 24
			brim.rings = 12
			var brim_scale := Vector3(cap_radius * 1.18, 0.06, cap_radius * 1.18)
			var brim_pos := Vector3(0.0, cap_base() + 0.06, 0.0)
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
