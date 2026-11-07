class_name RemotePlayer
extends Node3D

## 森林里别人的替身：不参与物理、不读输入，只按快照插值着走。
## 用和玩家一样的蘑菇外观（MushroomMesh.use_look），头顶挂一个名字牌。

var account := ""
var _mesh: MushroomMesh
var _label: Label3D
var _target := Vector3.ZERO
var _yaw := 0.0
var _look := ""


func setup(name_text: String, body_id: String, skin_id: String) -> void:
	account = name_text
	_mesh = MushroomMesh.new()
	_mesh.name = "MushroomMesh"
	add_child(_mesh)
	_mesh.use_look(body_id, skin_id)
	_look = "%s|%s" % [body_id, skin_id]

	_label = NameTag.attach(self, name_text, _mesh.top() + 0.55)


## 一份快照：位置、朝向、体型和皮肤（换了才重建外观）
func apply(state: Dictionary, delta: float, instant := false) -> void:
	_target = Vector3(float(state.get("x", 0.0)), float(state.get("y", 0.0)), float(state.get("z", 0.0)))
	_yaw = float(state.get("yaw", 0.0))
	var look := "%s|%s" % [str(state.get("body", "")), str(state.get("skin", ""))]
	if look != _look:
		_look = look
		_mesh.use_look(str(state.get("body", BodyCatalog.DEFAULT_ID)), str(state.get("skin", "")))
	if instant:
		global_position = _target
	else:
		# 指数插值：掉一两包也不会瞬移，停下来就不会抖
		var weight := clampf(delta * Config.NET_GHOST_LERP, 0.0, 1.0)
		global_position = global_position.lerp(_target, weight)
	rotation.y = lerp_angle(rotation.y, _yaw, clampf(delta * Config.NET_GHOST_LERP, 0.0, 1.0))


## 走起来像在走：位置变了就把帽檐上下颠一颠（省钱版走路动画）
func bob(delta: float, moving: bool) -> void:
	if _mesh == null:
		return
	var rest := _mesh.position.y
	if moving:
		_mesh.position.y = rest + sin(Time.get_ticks_msec() * 0.012) * 0.04
	else:
		_mesh.position.y = lerpf(rest, 0.0, clampf(delta * 8.0, 0.0, 1.0))
