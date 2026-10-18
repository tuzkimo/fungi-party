extends Node3D

## 赛跑编排：按种子建赛道、摆玩家、喂输入、跟相机。
## 自包含单场景：节点间直接引用。每局新种子（RaceField.new(randi())），绝不写死。

const COUNTDOWN_SECONDS := 3.0
const START_FLASH := 0.5
const CAMERA_HEIGHT := 3.5
const CAMERA_BACK := 7.0

var _field := RaceField.new(randi())
var _player: RacePlayer
var _camera: Camera3D
var _touch: TouchControls
var _elapsed := 0.0
var _countdown := COUNTDOWN_SECONDS
var _touch_jump := false


func _ready() -> void:
	Controls.ensure()
	_camera = $Camera3D

	var course := RaceCourse.new()
	course.name = "Course"
	add_child(course)
	course.build(_field)

	_player = RacePlayer.new()
	_player.name = "Player"
	add_child(_player)
	_follow_player()

	var layout := PackedStringArray()
	for group in _field.groups:
		layout.append("%.1f/%d" % [group.z, group.kind])
	print("赛道布局：%s" % " ".join(layout))


func _physics_process(delta: float) -> void:
	if _countdown > 0.0:
		_countdown -= delta
		return
	_elapsed += delta
	_feed()
	if _player.finished and _player.finish_time <= 0.0:
		_player.finish_time = _elapsed
	_follow_player()


func _feed() -> void:
	var move := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var jump := Input.is_action_just_pressed("jump")
	var dash := Input.is_action_just_pressed("run")
	_find_touch()
	if _touch != null:
		if _touch.move_input.length() > 0.05:
			move = _touch.move_input
		if _touch.jump_pressed and not _touch_jump:
			jump = true
		_touch_jump = _touch.jump_pressed
	_player.feed(move, jump, dash)


func _find_touch() -> void:
	if _touch == null:
		_touch = get_tree().get_first_node_in_group("touch_controls") as TouchControls


## 镜头锁死朝前：只平移，不转、不抖。
func _follow_player() -> void:
	_camera.position = Vector3(_player.position.x, CAMERA_HEIGHT, _player.position.z + CAMERA_BACK)
