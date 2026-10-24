class_name OwlActor
extends Node3D

## 座位上的一个蘑菇：外形直接复用玩家那套 MushroomMesh（和角色一致、能穿皮肤）。
## 它们背对镜头、面向树上的猫头鹰，所以嘴开在头顶、朝天——从背后看就是「仰头张大嘴」。
## 状态由外部每帧喂（score / open / out）。

const BODY_SCALE := 0.8
## 嘴的位置（蘑菇坐标，未缩放）：菌盖顶上，正对着天上掉东西的方向
## 菌盖顶在 mesh 坐标里是 y≈1.90（中心 1.35 + 半高 0.55），取 1.82 让嘴刚好嵌在顶面
const MOUTH_LOCAL := Vector3(0.0, 1.82, -0.05)
## 张嘴 = 一圈浅粉的嘴唇 + 中间深红的口腔，得看见洞才叫张嘴
const LIP_COLOR := Color(0.97, 0.62, 0.67)
const INNER_COLOR := Color(0.42, 0.12, 0.16)
## 仰头：正数让菌盖顶朝镜头翻过来，头顶的嘴也就露出来了
const LEAN_LOOK := 0.0
## 张嘴时头往后一仰（对背对镜头的蘑菇来说就是把盖顶翻给玩家看）；别仰太狠，像要栽倒
const LEAN_OPEN := 0.28
const LEAN_OUT := -0.30
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


## yaw：朝向猫头鹰（由外部按座位方位算好传进来）。
func setup(cap_color: Color, yaw: float) -> void:
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
	sphere.radial_segments = 16
	sphere.rings = 8
	_lip = _part("Lip", sphere, _solid(LIP_COLOR), Vector3(0.0, 0.0, 0.0))
	# 口腔比嘴唇再高一点、小一码：暗红的那颗躲在粉球里的话，头顶只是一个粉疙瘩
	_inner = _part("Inner", sphere, _solid(INNER_COLOR), Vector3(0.0, 0.04, 0.0))
	_lip.visible = false
	_inner.visible = false


## 穿戴了皮肤时，座位上的自己也换色换斑点（教室那套做法）。
func apply_skin(skin: MushroomSkin) -> void:
	_cap_color = skin.tint_cap
	_body.use_skin(skin)
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
		var grow := 0.5 + 0.55 * _mouth
		_lip.scale = Vector3(0.34, 0.14, 0.34) * grow
		_inner.scale = Vector3(0.27, 0.12, 0.27) * grow

	var lean := LEAN_OUT if out else (LEAN_OPEN if open else LEAN_LOOK)
	rotation.x = lerpf(rotation.x, lean, minf(1.0, delta * LEAN_SPEED))

	_pop = maxf(0.0, _pop - delta)
	_body.scale = Vector3.ONE * BODY_SCALE * (1.0 + POP_SCALE * _pop / POP_SECONDS + 0.08 * _mouth)


## 落点：头顶那张嘴的正上方（每帧问，跟着仰头动）。
func mouth_point() -> Vector3:
	return _pivot.to_global(MOUTH_LOCAL * BODY_SCALE + Vector3(0.0, 0.10, 0.0))


func _part(node_name: String, mesh: Mesh, mat: Material, offset: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.material_override = mat
	node.position = MOUTH_LOCAL * BODY_SCALE + offset
	_pivot.add_child(node)
	return node


func _solid(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	return mat
