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
## 相机离地的最小高度：抬头到顶时相机会被甩到地面以下，靠抬高支点补回来
const CAM_MIN_HEIGHT := 0.9

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


## 拉远射线要无视所有玩家自己：同屏双人时跟在身后那个会把镜头顶到脸上。
static func exclude_players(target: Node) -> Array:
	var rids: Array = []
	var tree := target.get_tree()
	if tree == null:
		return rids
	for node in tree.get_nodes_in_group("player"):
		var body := node as CollisionObject3D
		if body != null:
			rids.append(body.get_rid())
	return rids


## 支点该抬多高：抬头时相机沿 -Y 甩出去 arm_length * sin(pitch)，
## 补到相机至少还有 min_height 离地。低头时不动（sin 为负）。
static func pivot_lift(follow_height: float, pitch: float, arm_length: float, min_height: float) -> float:
	return maxf(follow_height, sin(pitch) * arm_length + min_height)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_action_pressed("orbit"):
		_apply_drag(event.relative)
	elif event is InputEventScreenDrag:
		_find_touch()
		# 按手指判，不按位置判：拇指推出摇杆圈外时不该顺手转视角。
		# 任何控件（摇杆或动作键）上的手指都算，双人时二号位的摇杆也能转歪一号位的镜头。
		if _touch != null and _touch.is_control_finger(event.index):
			return
		_apply_drag(event.relative)


func _apply_drag(drag: Vector2) -> void:
	var next := CamRig.orbit(Vector3(_pitch, _yaw, 0.0), drag, sensitivity, PITCH_MIN, PITCH_MAX)
	_pitch = next.x
	_yaw = next.y


func _physics_process(_delta: float) -> void:
	var target := get_node_or_null(target_path) as Node3D
	if target != null:
		var lift := CamRig.pivot_lift(follow_height, _pitch, requested_length, CAM_MIN_HEIGHT)
		global_position = target.global_position + Vector3.UP * lift
	rotation = Vector3(_pitch, _yaw, 0.0)

	var distance := requested_length
	var space := get_world_3d().direct_space_state
	if space != null and target != null:
		var from := global_position
		var to := from + global_transform.basis.z * requested_length
		var query := PhysicsRayQueryParameters3D.create(from, to, collision_mask)
		query.exclude = CamRig.exclude_players(target)
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			distance = from.distance_to(hit.position) - 0.15
	_camera.position = Vector3(0.0, 0.0, CamRig.clamp_arm_length(distance, Config.CAM_MIN_LENGTH))
