extends SceneTree

## 看一眼藏点摆得对不对（不进登录、不连服务器）：从高处拍一张全景，再拍两张近景。
## 用法：godot --path . --script res://tools/shot_hide_spots.gd
## 输出：shots/hide_spots.png（全景）、shots/hide_log.png（断木）、shots/hide_cave.png（石洞）

const FRAMES := 30

var _stage := 0
var _waited := 0
var _camera: Camera3D


func _initialize() -> void:
	var forest: Node3D = load("res://game/world/forest.tscn").instantiate()
	root.add_child(forest)
	_camera = Camera3D.new()
	_camera.fov = 70.0
	root.add_child(_camera)
	_camera.current = true


func _process(_delta: float) -> bool:
	if _stage == 0 and _waited == 0:
		_look(Vector3(0.0, 55.0, 74.0), Vector3(0.0, 0.0, 0.0))
	_camera.current = true
	_waited += 1
	if _waited < FRAMES:
		return false
	_waited = 0
	match _stage:
		0:
			_shoot("res://shots/hide_spots.png")
			_look(Vector3(29.0, 3.0, 12.0), Vector3(26.0, 1.0, 6.0))
		1:
			_shoot("res://shots/hide_log.png")
			_look(Vector3(33.0, 3.0, 24.0), Vector3(30.0, 1.0, 18.0))
		2:
			_shoot("res://shots/hide_cave.png")
			_look(Vector3(20.0, 3.4, 19.0), Vector3(17.0, 1.2, 14.0))
		3:
			_shoot("res://shots/hide_stone.png")
			return true
	_stage += 1
	return false


func _look(from: Vector3, at: Vector3) -> void:
	_camera.look_at_from_position(from, at, Vector3.UP)
	# 森林里那台 CamRig 也有一台相机，谁最后 current 谁说了算：每帧抢回来
	_camera.current = true


func _shoot(path: String) -> void:
	root.get_texture().get_image().save_png(path)
	print("saved %s" % path)
