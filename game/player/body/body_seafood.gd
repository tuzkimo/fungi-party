class_name BodySeafood
extends MushroomBody

## 海鲜菇：一根细长得离谱的浅色杆、一顶小扁帽、四根黑棍手脚、脸颊两坨腮红。
## 比例取自 refs/海鲜菇角色设计图.png（图高按 2.1 米算）。

const STALK_BOTTOM := 0.22
const STALK_BOTTOM_RADIUS := 0.175
const STALK_TOP_RADIUS := 0.215
const STALK_SEGMENTS := 28
const LIMB_COLOR := Color(0.14, 0.12, 0.11)
const CHEEK_COLOR := Color(0.957, 0.788, 0.843)
## 杆上的环纹：必须比轮廓（外扩 OUTLINE_GROW）还粗一圈，否则被黑边盖住。
const RING_GLOW := 0.024
const RINGS := [0.70, 1.20]


func apply_defaults(to: MushroomMesh) -> void:
	super.apply_defaults(to)
	to.body_height = 1.90     # 脚底到帽底；帽尖 = 1.90 - 0.05 + 0.25 = 2.10
	to.cap_radius = 0.44
	to.cap_height = 0.25
	to.cap_sharpness = 1.75   # 比红帽更扁的圆顶
	# 设计图上的颜色：浅棕帽、更浅的杆，帽上本来没斑点
	to.tint_cap = Color(0.855, 0.675, 0.549)
	to.tint_body = Color(0.945, 0.878, 0.831)
	to.spot_count = 0


## 小帽子上脸要挤紧一点，不然两只眼就到帽沿外面去了。
func _face_span() -> float:
	return 0.25


## 设计图是个「u」字笑，不是一条线。弯起来要更多小球才不断。
func _mouth_lift() -> float:
	return 0.15


func _mouth_dots() -> int:
	return 11


func _build_body(pivot: Node3D) -> void:
	var mat_body := _solid(host.tint_body)
	var outline := _outline()

	# 杆：顶粗底细、两端圆润，顶上一截藏在帽子里
	var stalk := lathe(_stalk_profile(), STALK_SEGMENTS)
	_add_part("Stalk", stalk, mat_body, Vector3.ZERO, Vector3.ONE)
	_add_part("StalkOutline", stalk, outline, Vector3.ZERO, Vector3.ONE)

	# 菌褶：帽底那片比帽色深一号的圆盘，让帽子和杆的接缝有层次
	var gills := CylinderMesh.new()
	gills.top_radius = host.cap_radius * 0.88
	gills.bottom_radius = host.cap_radius * 0.88
	gills.height = 0.025
	gills.radial_segments = STALK_SEGMENTS
	_add_part(
		"Gills", gills, _solid(host.tint_cap.darkened(0.22)),
		Vector3(0.0, -0.012, 0.0), Vector3.ONE, pivot,
	)

	# 杆上两道极淡的环纹，暗示海鲜菇的丛生纹理
	var mat_ring := _solid(host.tint_body.darkened(0.035))
	for y in RINGS:
		var ring := CylinderMesh.new()
		ring.top_radius = _stalk_radius_at(float(y)) + RING_GLOW
		ring.bottom_radius = ring.top_radius
		ring.height = 0.022
		ring.radial_segments = STALK_SEGMENTS
		_add_part("StalkRing", ring, mat_ring, Vector3(0.0, float(y), 0.0), Vector3.ONE)

	var mat_limb := _solid(LIMB_COLOR)
	# 胳膊：从帽沿下面往外下垂
	for side in [-1.0, 1.0]:
		_stick(
			"ArmL" if side < 0.0 else "ArmR",
			Vector3(0.20 * side, 1.56, 0.0),
			Vector3(0.55 * side, 1.30, 0.0),
			0.036, mat_limb,
		)
	# 腿：从杆底外撇，脚刚好踩到 y=0（杆在 0.22 结束，所以腿的下半段是看得见的）
	for side in [-1.0, 1.0]:
		_stick(
			"LegL" if side < 0.0 else "LegR",
			Vector3(0.045 * side, 0.34, 0.0),
			Vector3(0.21 * side, 0.02, 0.0),
			0.042, mat_limb,
		)


## 腮红贴在帽面上，眼睛外侧偏下。
func _build_cheeks(pivot: Node3D) -> void:
	var k := host.cap_radius
	var dot := _sphere(10, 5)
	var y_norm := 0.34
	var ring := cap_radius_at(y_norm)
	var x := 0.47 * k
	var z := sqrt(maxf(0.0, ring * ring - x * x)) * 0.96
	for side in [-1.0, 1.0]:
		_add_part(
			"CheekL" if side < 0.0 else "CheekR",
			dot, _solid(CHEEK_COLOR),
			Vector3(x * side, y_norm * host.cap_height * 2.0, z),
			Vector3(0.052, 0.030, 0.02),
			pivot,
		)


## 杆的剖面：(半径, 高度)，从底部的圆头一路收到顶。
func _stalk_profile() -> PackedVector2Array:
	var h := host.body_height
	var b := STALK_BOTTOM
	var lo := STALK_BOTTOM_RADIUS
	var hi := STALK_TOP_RADIUS
	var profile := PackedVector2Array([
		Vector2(0.0, b),
		Vector2(lo * 0.55, b + 0.004),
		Vector2(lo * 0.84, b + 0.018),
		Vector2(lo * 0.96, b + 0.05),
		Vector2(lo, b + 0.11),
	])
	# 中间一段缓慢变粗：设计图上杆是上粗下细
	for i in 6:
		var t := float(i) / 5.0
		var y := lerpf(b + 0.25, h - 0.30, t)
		profile.append(Vector2(lerpf(lo, hi, t * 0.85), y))
	profile.append(Vector2(hi, h - 0.16))
	profile.append(Vector2(hi * 0.92, h - 0.05))
	profile.append(Vector2(hi * 0.55, h))
	profile.append(Vector2(0.0, h))
	return profile


func _stalk_radius_at(y: float) -> float:
	var span := host.body_height - STALK_BOTTOM - 0.11
	return lerpf(STALK_BOTTOM_RADIUS, STALK_TOP_RADIUS, clampf((y - STALK_BOTTOM - 0.11) / span, 0.0, 1.0))


## 两点之间一根黑棍（胶囊，带圆头）。
func _stick(node_name: String, from: Vector3, to: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = from.distance_to(to)
	mesh.radial_segments = 12
	mesh.rings = 4
	var dir := to - from
	var node := _add_part(node_name, mesh, material, (from + to) * 0.5, Vector3.ONE)
	# 胶囊天生沿 +Y：绕 Z 转成 dir 的方向（四肢都在 XY 平面上，只用 z 轴）
	node.rotation_degrees.z = rad_to_deg(atan2(-dir.x, dir.y))
	return node
