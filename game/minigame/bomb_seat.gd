class_name BombSeat
extends Node3D

## 一个座位上的菌子：身体用 MushroomMesh，头顶一个自发光色块方便认人。
## 只负责「看起来怎样」，规则全在 BombRound。

const OFFSETS := [Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, 0, -1), Vector3(1, 0, 0)]
const MARK_Y := 2.0
const MARK_RISE := 0.32
const DEAD_SCALE := 0.55
const DEAD_CAP := Color(0.32, 0.31, 0.33)
const DEAD_BODY := Color(0.40, 0.39, 0.41)

var _mesh: MushroomMesh
var _mark: MeshInstance3D
var _phase := 0.0
var _shown_alive := true


## 南(0) +Z、西(1) -X、北(2) -Z、东(3) +X。座位朝圆心的旋转在 _ready 里按位置算。
static func seat_position(index: int) -> Vector3:
	return OFFSETS[index] * Config.BOMB_SEAT_RADIUS


func _ready() -> void:
	var towards := -position
	if towards.length() > 0.01:
		rotation.y = atan2(towards.x, towards.z)


## use_saved_skin 只有玩家座位传 true：读了皮肤就照存档换配色。（use_skin 不 build，等别处 build）
func setup(color: Color, use_saved_skin: bool) -> void:
	var skin: MushroomSkin = null
	if use_saved_skin:
		skin = SkinCatalog.by_id(str(Save.read()["equipped"]))

	_mesh = MushroomMesh.new()
	_mesh.name = "Body"
	_mesh.use_skin(skin)
	if skin == null:
		_mesh.tint_cap = color
	add_child(_mesh)

	_mark = MeshInstance3D.new()
	_mark.name = "Mark"
	var sphere := SphereMesh.new()
	sphere.radius = 0.15
	sphere.height = 0.30
	sphere.radial_segments = 12
	sphere.rings = 6
	_mark.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.7
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mark.material_override = mat
	_mark.position = Vector3(0.0, MARK_Y, 0.0)
	add_child(_mark)


## hurried：0 就是安稳抱着，1 是「快炸了」——呼吸更快、身体后仰、色块抬高。
func apply(hurried: float, alive: bool, delta: float) -> void:
	if _mesh == null or _mark == null:
		return
	hurried = clampf(hurried, 0.0, 1.0)
	if _shown_alive != alive:
		_shown_alive = alive
		if not alive:
			_grey_out()
	if not alive:
		_mesh.scale = _mesh.scale.lerp(Vector3.ONE * DEAD_SCALE, minf(1.0, delta * 6.0))
		_mesh.rotation.x = lerpf(_mesh.rotation.x, 0.0, minf(1.0, delta * 6.0))
		_mark.visible = false
		return
	_phase += delta * lerpf(2.5, 10.0, hurried)
	var wave := sin(_phase)
	var breath := 1.0 + (0.04 + 0.09 * hurried) * wave
	_mesh.scale = Vector3(1.0 / breath, breath, 1.0 / breath)
	_mesh.rotation.x = deg_to_rad(-8.0) * hurried * (0.6 + 0.4 * wave)
	_mark.visible = true
	_mark.position.y = MARK_Y + MARK_RISE * hurried * (0.5 + 0.5 * wave)


func _grey_out() -> void:
	_mesh.tint_cap = DEAD_CAP
	_mesh.tint_body = DEAD_BODY
	_mesh.build()
