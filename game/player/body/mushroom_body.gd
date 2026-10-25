class_name MushroomBody
extends RefCounted

## 一个体型的程序化几何。MushroomMesh 是门面，这里只管「长什么样」。
## 子类只实现 _build_body()（身体、四肢这类体型专属的东西）；
## 帽子旋转体、脸、腮红、斑点、零件、材质、轮廓全部在这里共用一份。
##
## 尺寸的唯一来源是 host（MushroomMesh）上的 body_height / cap_radius /
## cap_height / cap_sharpness：use_body() 把这里的默认值抄过去，之后调用方还能覆盖。

## 零件坐标当初是按这只红帽手调的（帽半径 0.70、帽高 0.46、帽底 0.89）。
## 换体型时按比例换算，别直接改下面 _add_accessory 里的数字。
const PARTS_BASE_CAP_RADIUS := 0.70
const PARTS_BASE_CAP_HEIGHT := 0.46
const PARTS_BASE_CAP_BASE := 0.89
## 帽子绕一圈的分段数。32 段配圆角三角够圆了，再多就是浪费。
const CAP_SEGMENTS := 28
const CAP_PROFILE_STEPS := 24
## 嘴由多少个重叠小球拼成一条线。
const MOUTH_DOTS := 5
## 脸占的扇形：这个角度范围内的正面不摆斑点，否则会盖住眼睛。
const FACE_HALF_ANGLE := 0.75
## 零件转向：剑是往外斜挑的，正竖直会整根埋进帽子。
const SWORD_TILT := -45.0
## 披风：背后一片弧面，不是整圈。
const CAPE_ARC := 1.15

var host: MushroomMesh


## 体型的默认尺寸。use_body() 调它：换体型时身高帽径要跟着换，但配色不动——
## NPC 都是「先 tint_cap = 颜色 再 add_child」，在这里抹一次就全变红蘑菇了。
func apply_defaults(_to: MushroomMesh) -> void:
	pass


## 体型的默认配色/斑点/零件（= 没穿皮肤时长什么样）。只有 use_skin(null) 调它。
func apply_look_defaults(to: MushroomMesh) -> void:
	var s := MushroomMesh.default_skin()
	to.tint_cap = s.tint_cap
	to.tint_body = s.tint_body
	to.spot_count = s.spot_count
	to.spot_shape = s.spot_shape
	to.spot_color = s.spot_color
	to.spot_glow = s.spot_glow
	to.parts = s.parts.duplicate()
	to.cap_tilt = s.cap_tilt
	to.cap_squash = s.cap_squash


## 嘴的翘度：0 是平的（红蘑菇那条线），>0 是「u」字突。占比是 cap_height。
func _mouth_lift() -> float:
	return 0.0


## 嘴用多少个小球拼。平的 5 个就成一条线；带笑的话弯起来要更密才不断。
func _mouth_dots() -> int:
	return MOUTH_DOTS


## 脸在帽子上的宽度占比（眼距的一半 = 这个 × cap_radius）。红帽是 0.20。
func _face_span() -> float:
	return 0.20


## 零件的整体平移，默认不挪。哪个体型的零件看着悬空就覆盖它，别散回每个零件里。
func _accessory_offset() -> Vector3:
	return Vector3.ZERO


func build() -> void:
	var pivot := _build_cap_pivot()
	_build_body(pivot)

	var cap_mesh := _revolve_cap()
	_add_part("Cap", cap_mesh, _solid(host.tint_cap), Vector3.ZERO, Vector3.ONE, pivot)
	_add_part("CapOutline", cap_mesh, _outline(), Vector3.ZERO, Vector3.ONE, pivot)

	_build_face(pivot)
	_build_cheeks(pivot)
	_build_spots(pivot)

	for part in host.parts:
		_add_accessory(part, pivot)


## 子类唯一必须实现的东西：身体几何（含它自己的轮廓）。pivot 是帽子那一层，
## 要跟帽子一起倾斜/压扁的小件（比如菌褶）挂到它下面。
func _build_body(_pivot: Node3D) -> void:
	pass


## 腮红一类的脸部件，默认没有。
func _build_cheeks(_pivot: Node3D) -> void:
	pass


func cap_base() -> float:
	return host.body_height - 0.05 - host.cap_height


## y_norm 0 是帽子底、1 是顶尖。返回该高度处帽子的水平半径。
func cap_radius_at(y_norm: float) -> float:
	var y := clampf(y_norm, 0.0, 1.0)
	var sharp := host.cap_sharpness
	var shape := pow(maxf(0.0, 1.0 - pow(y, sharp)), 1.0 / sharp)
	return shape * host.cap_radius


## 帽子 + 长在帽子上的一切共用这个 pivot：倾斜和压扁各自变换的话，
## 蔫菇的眼珠和斑点会飘到空气里。
func _build_cap_pivot() -> Node3D:
	var pivot := Node3D.new()
	pivot.name = "CapPivot"
	pivot.position = Vector3(0.0, cap_base(), 0.0)
	pivot.rotation_degrees.z = host.cap_tilt
	pivot.scale = Vector3(1.0, 1.0 - host.cap_squash, 1.0)
	host.add_child(pivot)
	return pivot


## 帽子是绕 Y 轴转一圈的旋转体，剖面用超椭圆：尖度 1 是圆锥、2 是球。
func _revolve_cap() -> ArrayMesh:
	var profile := PackedVector2Array()
	profile.append(Vector2(0.0, 0.0))
	for i in CAP_PROFILE_STEPS:
		var y := float(i) / float(CAP_PROFILE_STEPS - 1)
		profile.append(Vector2(cap_radius_at(y), y * host.cap_height * 2.0))
	return lathe(profile, CAP_SEGMENTS)


## 剖面一律是 (半径, 高度) 的一串点，绕 Y 轴转一圈。帽子、海鲜菇的杆都用它。
func lathe(profile: PackedVector2Array, segments: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in segments:
		var a0 := TAU * float(i) / float(segments)
		var a1 := TAU * float(i + 1) / float(segments)
		var c0 := cos(a0)
		var s0 := sin(a0)
		var c1 := cos(a1)
		var s1 := sin(a1)
		for j in profile.size() - 1:
			var p0 := profile[j]
			var p1 := profile[j + 1]
			# 这个绕序法线朝外；反过来就整颗里朝外（test_cap_normals_point_out 钉住）
			_quad(st, Vector3(c1 * p0.x, p0.y, s1 * p0.x), Vector3(c1 * p1.x, p1.y, s1 * p1.x),
				Vector3(c0 * p1.x, p1.y, s0 * p1.x), Vector3(c0 * p0.x, p0.y, s0 * p0.x))
	st.generate_normals()
	return st.commit()


static func _quad(st: SurfaceTool, v00: Vector3, v01: Vector3, v11: Vector3, v10: Vector3) -> void:
	st.add_vertex(v00)
	st.add_vertex(v01)
	st.add_vertex(v11)
	st.add_vertex(v00)
	st.add_vertex(v11)
	st.add_vertex(v10)


## 眼和嘴贴在帽子正面上：z 由那个高度上的帽子半径反算，帽子轮廓改了这个跟着走。
## 坐标都在 pivot 本地系里：y=0 是帽底，y=cap_height*2 是帽尖。
func _build_face(pivot: Node3D) -> void:
	var dot := _sphere(12, 6)
	var mat_dark := _solid(Color(0.10, 0.07, 0.07))
	var k := host.cap_radius
	var eye_x := _face_span() * k
	var eye_y_norm := 0.41
	var eye_ring := cap_radius_at(eye_y_norm)
	for side in [-1.0, 1.0]:
		var x: float = eye_x * float(side)
		_add_part(
			"EyeL" if side < 0.0 else "EyeR",
			dot,
			mat_dark,
			Vector3(
				x,
				eye_y_norm * host.cap_height * 2.0,
				sqrt(maxf(0.0, eye_ring * eye_ring - x * x)) * 0.97,
			),
			Vector3(0.0786, 0.0786, 0.043) * k,
			pivot,
		)
	# 嘴是帽面上的一段线。单个扁球放在曲面上会被切成两截，所以沿 x 排一串重叠的小球
	var mouth_y_norm := 0.23
	var mouth_half := 0.1429 * k
	var mouth_y := mouth_y_norm * host.cap_height * 2.0
	var count := _mouth_dots()
	for i in count:
		var mx := mouth_half * (-1.0 + 2.0 * float(i) / float(count - 1))
		# 嘴角抬起来就是笑：中间的点最低，两头的点按平方抬。
		# z 必须用抬完之后的高度重算，否则嘴角会从帽面上睟起来。
		var y := mouth_y + _mouth_lift() * host.cap_height * pow(absf(mx) / mouth_half, 2.0)
		var ring := cap_radius_at(y / (host.cap_height * 2.0))
		_add_part(
			"Mouth%d" % i, dot, mat_dark,
			Vector3(mx, y, sqrt(maxf(0.0, ring * ring - mx * mx)) * 0.97),
			Vector3(0.0714, 0.0257, 0.0286) * k,
			pivot,
		)


func _build_spots(cap_pivot: Node3D) -> void:
	if host.spot_count <= 0:
		return
	var mat_spot := _solid_glow(host.spot_color, host.spot_glow)
	var k := host.cap_radius / PARTS_BASE_CAP_RADIUS

	var round_mesh := _sphere(12, 6)

	var star_mesh := BoxMesh.new()
	star_mesh.size = Vector3(0.24, 0.05, 0.05)

	for i in host.spot_count:
		var angle := TAU * float(i) / float(host.spot_count) + 0.4
		# 正脸那块留白：转到后脑勺去，斑点总数不变
		var facing := wrapf(angle - PI * 0.5, -PI, PI)
		var y_norm := 0.18 + 0.7 * float((i * 37) % 100) / 100.0
		if absf(facing) < FACE_HALF_ANGLE and y_norm > 0.12 and y_norm < 0.52:
			angle += PI
		# 贴着帽子表面放：半径取那个高度上的帽子半径，稍微往里坐一点
		var ring := cap_radius_at(y_norm) * 0.93
		var spot_pos := Vector3(
			cos(angle) * ring,
			y_norm * host.cap_height * 2.0,
			sin(angle) * ring,
		)
		var spot_scale := Vector3.ONE * (0.10 + 0.03 * float(i % 3)) * k
		spot_scale.y *= 0.45
		match host.spot_shape:
			MushroomSkin.SpotShape.STAR:
				# 两道交叉的短棒凑成星，比球便宜也更像星星
				for quarter in [0.0, 90.0]:
					var bar := _add_part("Spot%d" % i, star_mesh, mat_spot, spot_pos, Vector3.ONE * k, cap_pivot)
					bar.rotation_degrees = Vector3(0.0, rad_to_deg(angle) + quarter, 0.0)
			MushroomSkin.SpotShape.BLOB:
				_add_part("Spot%d" % i, round_mesh, mat_spot, spot_pos, spot_scale * Vector3(1.6, 0.5, 1.0), cap_pivot)
			_:
				_add_part("Spot%d" % i, round_mesh, mat_spot, spot_pos, spot_scale, cap_pivot)


## 横向一律 ×(cap_radius/0.70)；帽上的纵向跟 cap_height；披风从帽底挂到腰。
## 红蘑菇代进去正好退化成原来的绝对值，所以它一个像素都不变。
func _add_accessory(part: String, cap_pivot: Node3D) -> void:
	var k := host.cap_radius / PARTS_BASE_CAP_RADIUS
	var mat_dark := _solid(Color(0.10, 0.07, 0.07))
	var mat_steel := _solid(Color(0.88, 0.90, 0.96))
	var offset := _accessory_offset()
	match part:
		"sword":
			# 剑握在右手上往斜上方挑：锚点由体型给（红蘑菇是手边、海鲜菇是棍子的末端）
			var tilt := Vector3(0.0, 0.0, SWORD_TILT)
			var axis := Vector2(sin(deg_to_rad(-SWORD_TILT)), cos(deg_to_rad(-SWORD_TILT)))
			var anchor := _sword_anchor()
			var guard_pos := Vector2(anchor.x, anchor.y)

			# 剑身：四棱锥，底宽顶尖收成一点；压扁 z 做出刃口
			var blade := CylinderMesh.new()
			blade.top_radius = 0.0
			blade.bottom_radius = 0.085 * k
			blade.height = 0.60 * k
			blade.radial_segments = 4
			var blade_pos := guard_pos + axis * (0.04 + 0.30) * k
			for mat in [mat_steel, _outline()]:
				var node := _add_part(
					"SwordBlade" if mat == mat_steel else "SwordBladeOutline",
					blade, mat, _sword(blade_pos, anchor) + offset,
					Vector3(1.0, 1.0, 0.45),
				)
				node.rotation_degrees = tilt

			# 护手：比剑身宽一截才看得出是剑
			var guard := BoxMesh.new()
			guard.size = Vector3(0.34, 0.055, 0.085) * k
			var guard_node := _add_part(
				"SwordGuard", guard, mat_steel, _sword(guard_pos, anchor) + offset, Vector3.ONE,
			)
			guard_node.rotation_degrees = tilt

			# 柄和剑首
			var grip := CylinderMesh.new()
			grip.top_radius = 0.032 * k
			grip.bottom_radius = 0.032 * k
			grip.height = 0.18 * k
			grip.radial_segments = 8
			var grip_pos := guard_pos - axis * 0.10 * k
			var grip_node := _add_part(
				"SwordGrip", grip, mat_dark, _sword(grip_pos, anchor) + offset, Vector3.ONE,
			)
			grip_node.rotation_degrees = tilt

			var pommel := _sphere(10, 6)
			var pommel_pos := guard_pos - axis * 0.19 * k
			_add_part(
				"SwordPommel", pommel, mat_steel, _sword(pommel_pos, anchor) + offset,
				Vector3.ONE * 0.055 * k,
			)
		"cape":
			# 披风只是背后一片弧面。绕成整圈就从后面看像条裙子
			var cape := _cape_mesh(k)
			var mat_cape := _solid(host.tint_cap.darkened(0.25))
			mat_cape.cull_mode = BaseMaterial3D.CULL_DISABLED
			_add_part("Cape", cape, mat_cape, offset, Vector3.ONE)
		"horned_helmet":
			var dome := _sphere(20, 10)
			var dome_pos := Vector3(0.0, host.cap_height * 2.0 - host.cap_height * 0.30, 0.0)
			_add_part("HelmetDome", dome, mat_dark, dome_pos + offset, Vector3(0.34 * k, 0.187 * k, 0.34 * k), cap_pivot)
			var horn := CylinderMesh.new()
			horn.top_radius = 0.02 * k
			horn.bottom_radius = 0.09 * k
			horn.height = 0.34 * k
			horn.radial_segments = 10
			for side in [-1.0, 1.0]:
				var node := _add_part(
					"HelmetHorn", horn, mat_steel,
					Vector3(0.24 * k * side, host.cap_height * 2.0 - host.cap_height * 0.10, 0.0) + offset,
					Vector3.ONE,
					cap_pivot,
				)
				node.rotation_degrees.z = -35.0 * side
		"crown":
			var gold := _solid(Color(0.98, 0.82, 0.30))
			var band := CylinderMesh.new()
			band.top_radius = 0.26 * k
			band.bottom_radius = 0.22 * k
			band.height = 0.12 * k
			band.radial_segments = 16
			var band_y := host.cap_height * 2.0 - 0.03 * k
			_add_part("CrownBand", band, gold, Vector3(0.0, band_y, 0.0) + offset, Vector3.ONE, cap_pivot)
			var tooth := BoxMesh.new()
			tooth.size = Vector3(0.07, 0.13, 0.06) * k
			for i in 5:
				var a := TAU * float(i) / 5.0
				var node := _add_part(
					"CrownTooth%d" % i, tooth, gold,
					Vector3(cos(a) * 0.23 * k, band_y + 0.11 * k, sin(a) * 0.23 * k) + offset,
					Vector3.ONE,
					cap_pivot,
				)
				node.rotation_degrees.y = rad_to_deg(a)
		"bloom":
			var petal := _sphere(12, 6)
			var tip := Vector3(0.0, host.cap_height * 2.0 + 0.02 * k, 0.0) + offset
			_add_part("BloomPetal", petal, _solid(Color(0.99, 0.72, 0.80)), tip, Vector3(0.16, 0.06, 0.16) * k, cap_pivot)
			_add_part("BloomCore", petal, _solid(Color(0.98, 0.86, 0.36)), tip, Vector3(0.06, 0.05, 0.06) * k, cap_pivot)
		"wide_brim":
			var brim := _sphere(24, 12)
			var brim_scale := Vector3(host.cap_radius * 1.18, 0.06 * k, host.cap_radius * 1.18)
			var brim_pos := Vector3(0.0, 0.06 * k, 0.0) + offset
			_add_part("Brim", brim, _solid(host.tint_cap.darkened(0.1)), brim_pos, brim_scale, cap_pivot)
			_add_part("BrimOutline", brim, _outline(), brim_pos, brim_scale, cap_pivot)
		_:
			push_warning("未知零件：%s" % part)


## 剑挂在右手上（不跟帽子倾斜）。锚点由体型给世界坐标，剑身沿轴长出去。
func _sword(p: Vector2, anchor: Vector3) -> Vector3:
	return Vector3(p.x, p.y, anchor.z)


## 剑的把手位置（世界坐标）。默认是红蘑菇手边那点，子类按自己的手改。
func _sword_anchor() -> Vector3:
	return Vector3(0.76, 0.82, 0.06)


## 背后一片弧面：从帽底挂下来，横向跟帽子走、纵向跟身体走。
func _cape_mesh(k: float) -> ArrayMesh:
	const STEPS := 12
	var top_r := 0.50 * k
	var bottom_r := 0.68 * k
	var top_y := cap_base() + host.cap_height * 0.9
	var bottom_y := host.body_height * 0.243
	# 红蘑菇：0.50/0.68、1.304/0.34 —— 和手调时的数值一致
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in STEPS:
		var a0 := -PI * 0.5 - CAPE_ARC + 2.0 * CAPE_ARC * float(i) / float(STEPS)
		var a1 := -PI * 0.5 - CAPE_ARC + 2.0 * CAPE_ARC * float(i + 1) / float(STEPS)
		_quad(st,
			Vector3(cos(a0) * bottom_r, bottom_y, sin(a0) * bottom_r),
			Vector3(cos(a0) * top_r, top_y, sin(a0) * top_r),
			Vector3(cos(a1) * top_r, top_y, sin(a1) * top_r),
			Vector3(cos(a1) * bottom_r, bottom_y, sin(a1) * bottom_r))
	st.generate_normals()
	return st.commit()


func _sphere(segments: int, rings: int) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = segments
	mesh.rings = rings
	return mesh


func _add_part(
	part_name: String,
	mesh: Mesh,
	material: Material,
	pos: Vector3,
	scl: Vector3,
	parent: Node3D = null,
) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = part_name
	node.mesh = mesh
	node.material_override = material
	node.position = pos
	node.scale = scl
	(parent if parent != null else host).add_child(node)
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
	mat.grow_amount = MushroomMesh.OUTLINE_GROW
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat
