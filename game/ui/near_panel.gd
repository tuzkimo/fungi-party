class_name NearPanel
extends CanvasLayer

## 森林里走到别人跟前才弹的那一个按钮：「和 X 玩捉迷藏」。
## 只画和发信号，最近的是谁由 main.gd 每帧算（它手里有 world 和自己的坐标）。

signal hide_pressed(to: String)

var _root: Control
var _button: Button
var _name := ""


func _ready() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UIStyle.theme()
	add_child(_root)

	_button = Button.new()
	_button.name = "Hide"
	_button.custom_minimum_size = Vector2(420.0, 72.0)
	_button.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_button.offset_left = -210.0
	_button.offset_right = 210.0
	# 压在邀请横幅（-190..-110）上面一层，两条同时出现也不打架
	_button.offset_top = -290.0
	_button.offset_bottom = -218.0
	_button.visible = false
	_button.pressed.connect(func() -> void: hide_pressed.emit(_name))
	UIStyle.style_button(_button)
	_root.add_child(_button)


## 换人（或空串收起）。同一帧重复同一个名字不重建文字。
func set_target(name: String) -> void:
	if name == _name:
		return
	_name = name
	_button.visible = name != ""
	_button.text = "和 %s 玩捉迷藏" % name


## 世界里离我最近的那个真账号（同屏 2P 的 `账号|1` 不是人）；太远就是空串。
static func nearest(world: Dictionary, at: Vector3, reach: float) -> String:
	var best := ""
	var best_distance := reach
	for key in world:
		var name := str(key)
		if name.contains("|"):
			continue
		var state: Dictionary = world[key]
		var spot := Vector3(float(state.get("x", 0.0)), 0.0, float(state.get("z", 0.0)))
		var distance := Vector2(spot.x, spot.z).distance_to(Vector2(at.x, at.z))
		if distance < best_distance:
			best_distance = distance
			best = name
	return best
