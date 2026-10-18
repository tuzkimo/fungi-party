class_name RacerVisual
extends Node3D

## 人机的样子：小一号蘑菇 + 头顶一个色块。读 RaceRacer 的状态摆位和挤压。

const BODY_SCALE := 0.85
const MARK_COLOR_MIX := 0.45
const MARK_HEIGHT := 1.55
const MARK_SIZE := 0.22

var _visual: MushroomMesh
var _mark: MeshInstance3D


func setup(color: Color) -> void:
	_visual = MushroomMesh.new()
	_visual.name = "MushroomMesh"
	_visual.tint_cap = color
	add_child(_visual)

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


func apply(racer: RaceRacer) -> void:
	position = Vector3(racer.x, 0.0, racer.z)
	var squash := Vector3.ONE
	if racer.freeze > 0.0:
		squash = Vector3(1.18, 0.78, 1.18)
	elif racer.dash_left > 0.0:
		squash = Vector3(0.88, 1.18, 0.88)
	_visual.scale = Vector3.ONE * BODY_SCALE * squash
	_mark.position.y = MARK_HEIGHT * squash.y
