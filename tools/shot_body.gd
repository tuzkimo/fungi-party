extends SceneTree

## 一次性看效果的工具：把几个体型/皮肤的组合渲染成 png，别在游戏里瞎猜。
## 用法：godot --path . --script res://tools/shot_body.gd
## 输出：shots/body_*.png（需要真窗口渲染，--headless 出不了图）

const OUT := "res://shots/"
const SHOTS := [
	{"body": "red", "skin": "", "yaw": 0.0, "file": "body_red"},
	{"body": "seafood", "skin": "", "yaw": 0.0, "file": "body_seafood_front"},
	{"body": "seafood", "skin": "", "yaw": 40.0, "file": "body_seafood_quarter"},
	{"body": "seafood", "skin": "", "yaw": 90.0, "file": "body_seafood_side"},
	{"body": "seafood", "skin": "hero", "yaw": 25.0, "file": "body_seafood_hero"},
	{"body": "red", "skin": "king", "yaw": 0.0, "file": "body_red_king"},
	{"body": "seafood", "skin": "king", "yaw": 0.0, "file": "body_seafood_king"},
	{"body": "seafood", "skin": "fly_agaric", "yaw": 0.0, "file": "body_seafood_brim"},
	{"body": "seafood", "skin": "wilt", "yaw": 0.0, "file": "body_seafood_wilt"},
]

var _index := 0
var _frame := 0
var _mesh: MushroomMesh
var _scene: Node3D


func _initialize() -> void:
	_scene = Node3D.new()
	root.add_child(_scene)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.80, 0.86, 0.90)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.72, 0.76, 0.84)
	e.ambient_light_energy = 1.0
	env.environment = e
	_scene.add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42.0, -32.0, 0.0)
	sun.light_energy = 1.2
	_scene.add_child(sun)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20.0, 20.0)
	ground.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.62, 0.70, 0.55)
	ground.material_override = mat
	_scene.add_child(ground)

	var cam := Camera3D.new()
	cam.fov = 30.0
	cam.position = Vector3(0.0, 1.20, 5.2)
	_scene.add_child(cam)
	cam.look_at(Vector3(0.0, 1.02, 0.0))

	_mesh = MushroomMesh.new()
	_scene.add_child(_mesh)
	_apply()


func _apply() -> void:
	var shot: Dictionary = SHOTS[_index]
	_mesh.use_body(str(shot["body"]))
	_mesh.use_skin(SkinCatalog.by_id(str(shot["skin"])))
	_mesh.build()
	_mesh.rotation_degrees.y = float(shot["yaw"])


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame < 8:
		return false
	_frame = 0
	var image := root.get_texture().get_image()
	image.save_png(OUT + str(SHOTS[_index]["file"]) + ".png")
	print("saved ", SHOTS[_index]["file"])
	_index += 1
	if _index >= SHOTS.size():
		return true
	_apply()
	return false
