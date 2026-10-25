class_name MushroomMesh
extends Node3D

## 程序化生成蘑菇角色的全部外观。所有尺寸按「脚底 y=0」排布。
## 这里只是门面：挑体型、存皮肤字段、给外面读尺寸。几何在 game/player/body/ 下。
## 外观只在这里和 body/ 里改；角色逻辑不引用这里的任何节点。

const OUTLINE_GROW := 0.018

static var _default_skin: MushroomSkin

## 当前体型 id（BodyCatalog 里的键）。换体型用 use_body()，别直接赋值。
var body_id := ""
var _body: MushroomBody

@export var body_height := 1.4
@export var cap_radius := 0.70
@export var cap_height := 0.46
## 帽子剖面的「尖度」：1 是圆锥、2 是正球面。取中间偏尖 = 圆角三角。
@export var cap_sharpness := 1.45
@export var spot_count := 7
@export var tint_cap := Color(0.90, 0.22, 0.20)
@export var tint_body := Color(0.96, 0.78, 0.62)
@export var spot_shape := 0
@export var spot_color := Color(0.99, 0.97, 0.94)
@export var spot_glow := 0.0
@export var parts: Array[String] = []
@export var cap_tilt := 0.0
@export var cap_squash := 0.0


## 默认外观的唯一来源是 MushroomSkin 的字段初值，不在这里另抄一份。
static func default_skin() -> MushroomSkin:
	if _default_skin == null:
		_default_skin = MushroomSkin.new()
	return _default_skin


## 换体型：把新体型的默认尺寸抄上来。同一个 id 再调一次不会把调用方的覆盖擦掉。
func use_body(id: String) -> MushroomBody:
	var wanted := BodyCatalog.normalize(id)
	if _body != null and body_id == wanted:
		return _body
	body_id = wanted
	_body = BodyCatalog.create(wanted)
	_body.host = self
	_body.apply_defaults(self)
	return _body


## 按存档把体型和皮肤一起刷上：读一次盘，四处「显示玩家本人」的地方都走这里。
func use_saved_look() -> void:
	var data := Save.read()
	use_body(str(data["character"]))
	use_skin(SkinCatalog.by_id(str(data["equipped"])))
	build()


## 只搬字段，不重建；调用方改完自己的覆盖再 build() 一次。
func use_skin(skin: MushroomSkin) -> void:
	_ensure_body()
	if skin == null:
		# 没穿皮肤 = 这个角色本来的样子，不是「红蘑菇的配色」
		_body.apply_defaults(self)
		_body.apply_look_defaults(self)
		return
	tint_cap = skin.tint_cap
	tint_body = skin.tint_body
	spot_count = skin.spot_count
	spot_shape = skin.spot_shape
	spot_color = skin.spot_color
	spot_glow = skin.spot_glow
	parts = skin.parts.duplicate()
	cap_tilt = skin.cap_tilt
	cap_squash = skin.cap_squash


func body() -> MushroomBody:
	_ensure_body()
	return _body


## 帽子底面（y=0 那个平面的世界高度）。
func cap_base() -> float:
	_ensure_body()
	return _body.cap_base()


## 帽尖的高度：头顶的标记、名牌都按这个摆，别写死数字。
func top() -> float:
	return cap_base() + cap_height * 2.0


## y_norm 0 是帽子底、1 是顶尖。返回该高度处帽子的水平半径。
func cap_radius_at(y_norm: float) -> float:
	_ensure_body()
	return _body.cap_radius_at(y_norm)


func _ensure_body() -> void:
	if _body == null:
		use_body(body_id)


func _ready() -> void:
	build()


func build() -> void:
	for child in get_children():
		remove_child(child)
		child.free()
	_ensure_body()
	_body.build()
