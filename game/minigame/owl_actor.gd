class_name OwlActor
extends Node3D

## 座位上的一个蘑菇：外形直接复用玩家那套 MushroomMesh（和角色一致、能穿皮肤）。
## 它们背对镜头、面向树上的猫头鹰：抬头就是张嘴，不另画嘴（尖帽上再摆一张嘴会跑到头顶上）。
## 状态由外部每帧喂（score / open / out）。

const BODY_SCALE := 0.8
## 闭嘴时的姿态
const LEAN_LOOK := 0.0
## 张嘴时头往后一仰（对背对镜头的蘑菇来说就是把盖顶翻给玩家看）；别仰太狠，像要栽倒
const LEAN_OPEN := 0.28
const LEAN_OUT := -0.30
const LEAN_SPEED := 14.0
const POP_SECONDS := 0.18
const POP_SCALE := 0.16
const OUT_FADE := 0.45

var _pivot: Node3D
var _body: MushroomMesh
var _cap_color := Color.WHITE
var _out := false
var _score := -1
var _pop := 0.0


## yaw：朝向猫头鹰（由外部按座位方位算好传进来）。
func setup(cap_color: Color, yaw: float) -> void:
	_cap_color = cap_color

	# 头这一层：整只蘑菇一起转、一起仰；SkinCatalog 换色重建也只重建 _body
	_pivot = Node3D.new()
	_pivot.name = "Head"
	_pivot.rotation.y = yaw
	add_child(_pivot)

	_body = MushroomMesh.new()
	_body.name = "Body"
	_body.tint_cap = cap_color
	_body.scale = Vector3.ONE * BODY_SCALE
	_pivot.add_child(_body)


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

	var lean := LEAN_OUT if out else (LEAN_OPEN if open else LEAN_LOOK)
	rotation.x = lerpf(rotation.x, lean, minf(1.0, delta * LEAN_SPEED))

	_pop = maxf(0.0, _pop - delta)
	var bump := 0.08 if open and not out else 0.0
	_body.scale = Vector3.ONE * BODY_SCALE * (1.0 + POP_SCALE * _pop / POP_SECONDS + bump)


## 落点：菌盖尖的正上方（每帧问，跟着仰头动）。
func mouth_point() -> Vector3:
	var tip := _body.body_height - 0.05 + _body.cap_height
	return _pivot.to_global(Vector3(0.0, tip * BODY_SCALE + 0.10, 0.0))
