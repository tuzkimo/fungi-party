class_name OwlActor
extends Node3D

## 座位上的一个蘑菇：外形直接复用玩家那套 MushroomMesh（和角色一致、能穿皮肤），
## 额外挂一张会张大的嘴。状态由外部每帧喂（score / open / out）。
## 常态就微微仰头（看树上的猫头鹰），张嘴时头往后一扬、嘴撑成一个大粉洞。

const BODY_SCALE := 0.8
## 嘴在 MushroomMesh 里的位置（未缩放）：跟角色自带的嘴线同一个高度
const MOUTH_LOCAL := Vector3(0.0, 1.05, 0.80)
## 张嘴 = 一圈浅粉的嘴唇 + 中间深红的口腔：只有粉色会看成「嘴巴凸出来」，得看见洞
const LIP_COLOR := Color(0.97, 0.62, 0.67)
const INNER_COLOR := Color(0.42, 0.12, 0.16)
## 常态仰头：0 是平视，负数让菌盖往后仰
const LEAN_LOOK := -0.12
const LEAN_OPEN := -0.34
const LEAN_OUT := 0.34
const LEAN_SPEED := 14.0
const MOUTH_GROW := 10.0
const POP_SECONDS := 0.18
const POP_SCALE := 0.16
const OUT_FADE := 0.45

var _pivot: Node3D
var _body: MushroomMesh
var _lip: MeshInstance3D
var _inner: MeshInstance3D
var _cap_color := Color.WHITE
var _out := false
var _score := -1
var _pop := 0.0
var _mouth := 0.0


## yaw：朝猫头鹰转一点（转满就会背对镜头，所以由外部夹好再传进来）。
func setup(cap_color: Color, is_player: bool, yaw: float) -> void:
	_cap_color = cap_color

	# 头这一层：菌盖和嘴一起转、一起仰，MushroomMesh 自己重建时不会连嘴一起清掉
	_pivot = Node3D.new()
	_pivot.name = "Head"
	_pivot.rotation.y = yaw
	add_child(_pivot)

	_body = MushroomMesh.new()
	_body.name = "Body"
	_body.tint_cap = cap_color
	_body.scale = Vector3.ONE * BODY_SCALE
	_pivot.add_child(_body)

	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 14
	sphere.rings = 7
	_lip = _part("Lip", sphere, _solid(LIP_COLOR), 0.0)
	# 口腔要比嘴唇往前探一点，否则小一码的暗红球整颗躲在粉色球里面，看不见
	_inner = _part("Inner", sphere, _solid(INNER_COLOR), 0.05)
	_lip.visible = false
	_inner.visible = false

	if is_player:
		# 玩家那一朵脚下多一圈浅黄光圈，四个人里一眼找到自己
		var ring := CylinderMesh.new()
		ring.top_radius = 0.72
		ring.bottom_radius = 0.72
		ring.height = 0.02
		ring.radial_segments = 20
		var node := MeshInstance3D.new()
		node.name = "Ring"
		node.mesh = ring
		node.position = Vector3(0.0, 0.011, 0.0)
		node.material_override = _solid(Color(0.98, 0.92, 0.55))
		add_child(node)


## 穿戴了皮肤时，座位上的自己也换色换斑点（教室那套做法）。
func apply_skin(skin: MushroomSkin) -> void:
	_cap_color = skin.tint_cap
	_body.tint_cap = skin.tint_cap
	_body.tint_body = skin.tint_body
	_body.spot_count = skin.spot_count
	_body.build()


func apply(score: int, open: bool, out: bool, delta: float) -> void:
	if _score >= 0 and score > _score:
		_pop = POP_SECONDS
	_score = score

	if out != _out:
		_out = out
		_body.tint_cap = _cap_color.darkened(OUT_FADE) if out else _cap_color
		_body.build()

	_mouth = move_toward(_mouth, 1.0 if open and not out else 0.0, delta * MOUTH_GROW)
	var shown := _mouth > 0.05
	_lip.visible = shown
	_inner.visible = shown
	if shown:
		# 张嘴是两段式的：嘴唇先撑开，口腔跟着；0.65~1.05 之间弹一下，夸张但不到撕裂
		var grow := 0.55 + 0.5 * _mouth
		_lip.scale = Vector3(0.26, 0.25, 0.10) * grow
		_inner.scale = Vector3(0.20, 0.20, 0.09) * grow

	var lean := LEAN_OUT if out else (LEAN_OPEN if open else LEAN_LOOK)
	rotation.x = lerpf(rotation.x, lean, minf(1.0, delta * LEAN_SPEED))

	_pop = maxf(0.0, _pop - delta)
	_body.scale = Vector3.ONE * BODY_SCALE * (1.0 + POP_SCALE * _pop / POP_SECONDS + 0.05 * _mouth)


## 落点：张嘴时口腔正前方一点（每帧问，跟着仰头动）。
func mouth_point() -> Vector3:
	return _pivot.to_global(MOUTH_LOCAL * BODY_SCALE + Vector3(0.0, 0.0, 0.06))


func _part(node_name: String, mesh: Mesh, mat: Material, forward: float) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.material_override = mat
	node.position = MOUTH_LOCAL * BODY_SCALE + Vector3(0.0, 0.0, 0.02 + forward)
	_pivot.add_child(node)
	return node


func _solid(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	return mat
