class_name CamRig
extends Node3D

## 第三人称跟随相机：自己一条射线往后拉，撞到东西就缩短，最短 CAM_MIN_LENGTH。
## 不用 SpringArm3D —— 它会自己摆子节点位置，和最短距离夹取打架，且行为不可测。

@export var target_path: NodePath
@export var follow_height := 1.6
@export var sensitivity := 0.006
@export var requested_length := 4.0
@export var collision_mask := 1

const PITCH_MIN := -1.2217305   # -70°
const PITCH_MAX := 0.3839724    # +22°：抬头能看见天

var _pitch := -0.3141593        # -18°
var _yaw := 0.0

@onready var _camera: Camera3D = $Camera3D

var _touch: TouchControls = null


func _ready() -> void:
	# 相机是 Player 的子节点，不脱钩就会跟着角色转身一起甩。
	top_level = true


func _find_touch() -> void:
	if _touch == null:
		_touch = get_tree().get_first_node_in_group("touch_controls") as TouchControls


static func orbit(current: Vector3, drag: Vector2, sens: float, pitch_min: float, pitch_max: float) -> Vector3:
	var pitch := clampf(current.x - drag.y * sens, pitch_min, pitch_max)
	var yaw := wrapf(current.y - drag.x * sens, -PI, PI)
	return Vector3(pitch, yaw, 0.0)


static func clamp_arm_length(length: float, min_length: float) -> float:
	return maxf(length, min_length)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_action_pressed("orbit"):
		_apply_drag(event.relative)
	elif event is InputEventScreenDrag:
		_find_touch()
		# 按手指判，不按位置判：拇指推出摇杆圈外时不该顺手转视角。
		if _touch != null and _touch.is_stick_finger(event.index):
			return
		_apply_drag(event.relative)


func _apply_drag(drag: Vector2) -> void:
	var next := CamRig.orbit(Vector3(_pitch, _yaw, 0.0), drag, sensitivity, PITCH_MIN, PITCH_MAX)
	_pitch = next.x
	_yaw = next.y


func _physics_process(_delta: float) -> void:
	var target := get_node_or_null(target_path) as Node3D
	if target != null:
		global_position = target.global_position + Vector3.UP * follow_height
	rotation = Vector3(_pitch, _yaw, 0.0)

	var distance := requested_length
	var space := get_world_3d().direct_space_state
	if space != null and target != null:
		var from := global_position
		var to := from + global_transform.basis.z * requested_length
		var query := PhysicsRayQueryParameters3D.create(from, to, collision_mask)
		query.exclude = [target.get_rid()]
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			distance = from.distance_to(hit.position) - 0.15
	_camera.position = Vector3(0.0, 0.0, CamRig.clamp_arm_length(distance, Config.CAM_MIN_LENGTH))
