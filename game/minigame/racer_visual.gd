class_name RacerVisual
extends Node3D

## 跑者的样子：小一号蘑菇 + 头顶一个色块（自己那一格不给色块，用真实体型和皮肤）。
## 只读 RaceRacer 的字段摆位和挤压，不改规则。

const BODY_SCALE := 0.85
const MARK_COLOR_MIX := 0.45
const MARK_HEIGHT := 1.55
const MARK_SIZE := 0.22
## 联机快照只有 20 Hz：直接贴上会一顿一顿，向目标追一小步（本机 60 Hz 时这点滞后看不出来）
const FOLLOW := 18.0

var _visual: MushroomMesh
var _mark: MeshInstance3D


## seat >= 0：这台机器上的玩家，用自己的体型 + 皮肤，头上不顶色块。
func setup(color: Color, seat := -1) -> void:
	_visual = MushroomMesh.new()
	_visual.name = "MushroomMesh"
	if seat >= 0:
		_visual.use_party_look(seat)
	else:
		_visual.tint_cap = color
	add_child(_visual)
	if seat >= 0:
		return

	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * MARK_SIZE
	_mark = MeshInstance3D.new()
	_mark.name = "Mark"
	_mark.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color.lerp(Color.WHITE, MARK_COLOR_MIX)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mark.material_override = material
	_mark.position.y = MARK_HEIGHT
	add_child(_mark)


## 摆位/挤压来自模型；转向留给子类（真人会朝摇杆方向偏一点）。
func apply(racer: RaceRacer, delta: float) -> void:
	var target := Vector3(racer.x, racer.y, racer.z)
	position = target if delta <= 0.0 else position.lerp(target, minf(1.0, FOLLOW * delta))
	var squash := Vector3.ONE
	if racer.freeze > 0.0:
		squash = Vector3(1.18, 0.78, 1.18)
	elif racer.dash_left > 0.0:
		squash = Vector3(0.88, 1.18, 0.88)
	_visual.scale = Vector3.ONE * BODY_SCALE * squash
	if _mark != null:
		_mark.position.y = MARK_HEIGHT * squash.y
