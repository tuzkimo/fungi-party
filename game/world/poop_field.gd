class_name PoopField
extends Node3D

## 森林里扔粑粑的 3D 表现：屎壳郎推着粪球、飞着的粑粑。纯表现，一个判定都不做。
## 全部按服务器的 SESSION 快照画，位置插值 —— 20 Hz 快照直接贴上会一顿一顿
## （和 RacerVisual.FOLLOW 同一个道理）。

## 每 tick 天上最多几发：够看清，也不至于每帧建节点
const MAX_SHOTS := 8

var _net: NetClient = null
var _beetles: Array[Node3D] = []
var _shots: Array[Node3D] = []

var _body_mesh: SphereMesh
var _ball_mesh: SphereMesh
var _shot_mesh: SphereMesh
var _leg_mesh: BoxMesh
var _body_mat: StandardMaterial3D
var _ball_mat: StandardMaterial3D
var _shot_mat: StandardMaterial3D


func _ready() -> void:
	# 几何和材质各建一份共用：别每帧 new
	_body_mesh = _sphere(0.26, 0.30)
	_ball_mesh = _sphere(0.16, 0.16)
	_shot_mesh = _sphere(0.18, 0.18)
	_leg_mesh = BoxMesh.new()
	_leg_mesh.size = Vector3(0.05, 0.05, 0.30)
	_body_mat = _material(Color(0.12, 0.10, 0.09))
	_ball_mat = _material(Color(0.20, 0.14, 0.07))
	_shot_mat = _material(Color(0.32, 0.22, 0.10))


func _process(delta: float) -> void:
	if _net == null:
		_net = NetClient.of(get_tree())
		if _net == null:
			return
	if not _net.in_room("poop"):
		_clear()
		return
	var game: Dictionary = _net.session.get("game", {})
	_sync_beetles(game.get("beetles", []), delta)
	_sync_shots(game.get("shots", []), delta)


func _sync_beetles(states: Array, delta: float) -> void:
	while _beetles.size() < states.size():
		_beetles.append(_new_beetle(_beetles.size()))
	for i in range(_beetles.size() - 1, states.size() - 1, -1):
		_beetles[i].queue_free()
		_beetles.remove_at(i)
	for i in states.size():
		var b: Dictionary = states[i]
		var node := _beetles[i]
		var target := Vector3(float(b.get("x", 0.0)), 0.0, float(b.get("z", 0.0)))
		node.position = node.position.lerp(target, minf(1.0, Config.NET_GHOST_LERP * delta))
		node.rotation.y = float(b.get("yaw", 0.0))
		var ball := node.get_node_or_null("Ball") as Node3D
		if ball != null:
			ball.visible = bool(b.get("ball", false))


func _sync_shots(states: Array, delta: float) -> void:
	var wanted := mini(states.size(), MAX_SHOTS)
	for i in wanted:
		if i >= _shots.size():
			var shot := _mesh_node(_shot_mesh, _shot_mat, "Shot%d" % i)
			shot.position = Vector3(float(states[i]["x"]), float(states[i]["y"]), float(states[i]["z"]))
			_shots.append(shot)
		else:
			var node := _shots[i]
			var target := Vector3(float(states[i]["x"]), float(states[i]["y"]), float(states[i]["z"]))
			# 粑粑是直线飞的，插值只抹平 20 Hz 的台阶
			node.position = node.position.lerp(target, minf(1.0, Config.NET_GHOST_LERP * delta))
	for i in range(_shots.size() - 1, wanted - 1, -1):
		_shots[i].queue_free()
		_shots.remove_at(i)


func _clear() -> void:
	for node in _beetles:
		node.queue_free()
	_beetles.clear()
	for node in _shots:
		node.queue_free()
	_shots.clear()


## 一只屎壳郎：压扁的球 + 两根触角 + 身前那个粪球（本地 -Z，和 PoopRound.ball_at 同一套约定）
func _new_beetle(index: int) -> Node3D:
	var node := Node3D.new()
	node.name = "Beetle%d" % index
	add_child(node)
	var body := _mesh_node(_body_mesh, _body_mat, "Body")
	body.position = Vector3(0.0, 0.2, 0.0)
	node.add_child(body)
	for side in [-1.0, 1.0]:
		var leg := _mesh_node(_leg_mesh, _body_mat, "Antenna")
		leg.position = Vector3(0.10 * side, 0.24, -0.24)
		leg.rotation = Vector3(0.5, 0.3 * side, 0.0)
		node.add_child(leg)
	var ball := _mesh_node(_ball_mesh, _ball_mat, "Ball")
	ball.position = Vector3(0.0, 0.16, -Config.POOP_BALL_AHEAD)
	node.add_child(ball)
	return node


func _mesh_node(mesh: Mesh, material: StandardMaterial3D, node_name: String) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	return instance


static func _sphere(radius: float, height: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	# 默认 64×32 段太贵，一颗小球的轮廓十几段就看不出棱角
	mesh.radial_segments = 16
	mesh.rings = 8
	mesh.radius = radius
	mesh.height = height
	return mesh


static func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material
