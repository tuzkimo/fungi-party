class_name PoopField
extends Node3D

## 森林里扔粑粑的 3D 表现：屎壳郎推着粪球、飞着的粑粑、被打中那位身上溅开的色块。
## 纯表现，一个判定都不做。
## 全部按服务器的 SESSION 快照画，位置插值 —— 20 Hz 快照直接贴上会一顿一顿
## （和 RacerVisual.FOLLOW 同一个道理）。
## 命中只能从 `hits[]` 涨了看出来：快照里没有命中点，所以色块贴在**人身上**、不贴在地上（见设计文档）。

## 每 tick 天上最多几发：够看清，也不至于每帧建节点
const MAX_SHOTS := 8
## 色块大小：太小就淹没在皮肤自己的斑点里，看着像脏了一块
const SPLAT_SIZE := 0.17

var _net: NetClient = null
var _beetles: Array[Node3D] = []
var _shots: Array[Node3D] = []
## 溅在人身上的色块（一局最多 `POOP_HITS * POOP_SPLATS` 块）
var _splats: Array[Node3D] = []
## 上次看到的累计命中数：涨了就说明这一拍有人挨了
var _hits: Array = []
var _rng := RandomNumberGenerator.new()
var _sfx: Sfx

var _body_mesh: SphereMesh
var _ball_mesh: SphereMesh
var _shot_mesh: SphereMesh
var _leg_mesh: BoxMesh
var _trail_mesh: SphereMesh
var _splat_mesh: SphereMesh
var _body_mat: StandardMaterial3D
var _ball_mat: StandardMaterial3D
var _shot_mat: StandardMaterial3D
var _splat_mat: StandardMaterial3D


func _ready() -> void:
	# 几何和材质各建一份共用：别每帧 new
	_body_mesh = _sphere(0.26, 0.30)
	_ball_mesh = _sphere(0.16, 0.16)
	_shot_mesh = _sphere(0.18, 0.18)
	_trail_mesh = _sphere(0.13, 0.13)
	_splat_mesh = _sphere(SPLAT_SIZE, SPLAT_SIZE)
	_leg_mesh = BoxMesh.new()
	_leg_mesh.size = Vector3(0.05, 0.05, 0.30)
	_body_mat = _material(Color(0.12, 0.10, 0.09))
	_ball_mat = _material(Color(0.20, 0.14, 0.07))
	_shot_mat = _material(Color(0.32, 0.22, 0.10))
	_splat_mat = _material(Color(0.45, 0.30, 0.14))
	_rng.seed = 23
	_sfx = Sfx.new()
	_sfx.name = "Sfx"
	add_child(_sfx)


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
	_watch_hits(game.get("hits", []))


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
		var state: Dictionary = states[i]
		var target := Vector3(float(state.get("x", 0.0)), float(state.get("y", 0.0)), float(state.get("z", 0.0)))
		var flight := Vector3(
			float(state.get("dx", 0.0)), float(state.get("dy", 0.0)), float(state.get("dz", 0.0))
		)
		if i >= _shots.size():
			var shot := _new_shot(i)
			shot.position = target
			_shots.append(shot)
		else:
			var node := _shots[i]
			# 粑粑是直线飞的，插值只抹平 20 Hz 的台阶
			node.position = node.position.lerp(target, minf(1.0, Config.NET_GHOST_LERP * delta))
		_face_flight(_shots[i], flight)
		var body := _shots[i].get_node_or_null("Body") as Node3D
		if body != null:
			body.rotate_x(Config.POOP_SPIN * delta)
	for i in range(_shots.size() - 1, wanted - 1, -1):
		_shots[i].queue_free()
		_shots.remove_at(i)


## 一发粑粑：朝飞行方向的球 + 身后几个越来越小的尾巴点（全共用一份网格和材质）。
## 节点自己的 -Z 是飞行方向，所以尾巴摆在 +Z。
func _new_shot(index: int) -> Node3D:
	var node := Node3D.new()
	node.name = "Shot%d" % index
	add_child(node)
	node.add_child(_mesh_node(_shot_mesh, _shot_mat, "Body"))
	var last := maxi(1, Config.POOP_TRAIL - 1)
	for i in Config.POOP_TRAIL:
		var dot := _mesh_node(_trail_mesh, _shot_mat, "Trail%d" % i)
		dot.position = Vector3(0.0, 0.0, 0.28 + 0.26 * float(i))
		dot.scale = Vector3.ONE * lerpf(0.60, 0.15, float(i) / float(last))
		node.add_child(dot)
	return node


## 让一颗粑粑朝着它飞的方向（服务器快照里就有 dx/dy/dz，不用自己差分）。
static func _face_flight(node: Node3D, flight: Vector3) -> void:
	if flight.length() < 0.001:
		return
	var forward := flight.normalized()
	# 垂直往下飞时 UP 和方向平行，looking_at 会退化成 NaN
	var up := Vector3.UP if absf(forward.y) < 0.95 else Vector3.BACK
	node.basis = Basis.looking_at(forward, up)


## 这一拍谁挨了：快照只给累计命中数，涨了就说明刚被砸中（命中点服务器不发）。
static func hit_seats(last: Array, counts: Array) -> Array:
	var out := []
	for seat in mini(last.size(), counts.size()):
		if int(counts[seat]) > int(last[seat]):
			out.append(seat)
	return out


## 色块贴在帽子上的位置：y_norm 0 是帽底、1 是顶尖，radius 取那一层的帽檐半径 ——
## 换个体型也不会飘在空中（和 NameTag 挂额头的那套规矩一样）。
static func splat_spot(angle: float, y_norm: float, radius: float, base: float, cap_height: float) -> Vector3:
	return Vector3(sin(angle) * radius, base + cap_height * 2.0 * y_norm, cos(angle) * radius)


func _watch_hits(counts: Array) -> void:
	if _hits.is_empty():
		for count in counts:
			_hits.append(int(count))
		return
	for seat in hit_seats(_hits, counts):
		_on_hit(seat)
	for i in mini(_hits.size(), counts.size()):
		_hits[i] = int(counts[i])


func _on_hit(seat: int) -> void:
	var account := _seat_account(seat)
	if account == "":
		return
	if account == _net.player_name:
		# 局里的座位号不是森林里的 Party 座位号（账号才是），同屏 2P 也同一个账号：
		# 打中的所有本机分身一起演
		for node in get_tree().get_nodes_in_group("player"):
			var player := node as Player
			if player == null:
				continue
			player.hit()
			_splats_on(player.look_mesh())
	else:
		var ghost := RemotePlayer.of(get_tree(), account)
		if ghost == null:
			return
		ghost.hit()
		_splats_on(ghost.look_mesh())
	_sfx.play("splat")


func _seat_account(seat: int) -> String:
	var seats: Array = _net.session.get("seats", []) if _net != null else []
	if seat < 0 or seat >= seats.size():
		return ""
	return str((seats[seat] as Dictionary).get("account", ""))


func _splats_on(mesh: MushroomMesh) -> void:
	for i in Config.POOP_SPLATS:
		_splat_on(mesh)


## 一块溅上的色块：从 0 弹出来、贴着帽面，跟着人走。
## 圆心摆在帽面上：一半坐进去、一半鼓出来 —— 全摊在里面看不见，全摆在外面就像贴了张碟子。
func _splat_on(mesh: MushroomMesh) -> void:
	var y_norm := _rng.randf_range(0.05, 0.55)
	var full := _rng.randf_range(0.8, 1.3)
	var radius := mesh.cap_radius_at(y_norm) * 0.95
	var node := _mesh_node(_splat_mesh, _splat_mat, "Splat")
	node.position = splat_spot(_rng.randf() * TAU, y_norm, radius, mesh.cap_base(), mesh.cap_height)
	node.scale = Vector3.ZERO
	mesh.add_child(node)
	_splats.append(node)
	create_tween().tween_property(node, "scale", Vector3(1.0, 0.7, 1.0) * full, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _clear() -> void:
	for node in _beetles:
		node.queue_free()
	_beetles.clear()
	for node in _shots:
		node.queue_free()
	_shots.clear()
	# 色块挂在人身上，不是挂在 PoopField 底下：得自己收
	for node in _splats:
		if is_instance_valid(node):
			node.queue_free()
	_splats.clear()
	_hits.clear()


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
