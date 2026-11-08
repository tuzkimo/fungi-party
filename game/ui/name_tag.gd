class_name NameTag
extends Label3D

## 蘑菇头顶的名字牌：森林里的自己 / 2P / 别人、四款小游戏里每个座位都用它，别各写一份 Label3D 参数。
## 字体跟 UI 共用 `UIStyle.font()`：内置字体没有中文字形，真机上名字会是一排豆腐块。

const FONT_SIZE := 64
const PIXEL_SIZE := 0.0045
const OUTLINE_SIZE := 18
## 远了就淡到看不见：满屏都是名字反而看不清谁是谁。
## Label3D 不认 `visibility_range_*`（实测没效果），所以自己按到镜头的距离算。
const FADE_END := 26.0
const FADE_MARGIN := 8.0
## 不淡的时候的透明度（名字不能太抢眼）
const BASE_ALPHA := 0.92

## 捉迷藏期间整座森林都不挂名字（不然远处一眼就认出「那个是 XX」）。
## 所有人（含观战的人）都读这一位，由 `HideGame` 按服务器的 WORLD 标记置位。
static var hidden := false


## 挂到 host 头顶 height 处（host 通常是角色那个 Node3D，y=0 是脚底）。
static func attach(host: Node3D, text: String, height: float) -> NameTag:
	var tag := NameTag.new()
	tag.name = "Name"
	tag.font = UIStyle.font()
	tag.text = text
	tag.font_size = FONT_SIZE
	tag.pixel_size = PIXEL_SIZE
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.modulate = Color(1, 1, 1, BASE_ALPHA)
	tag.outline_modulate = Color(0.05, 0.05, 0.06, 0.9)
	tag.outline_size = OUTLINE_SIZE
	tag.position = Vector3(0.0, height, 0.0)
	host.add_child(tag)
	return tag


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var distance := global_position.distance_to(camera.global_position)
	var fade := clampf((FADE_END - distance) / FADE_MARGIN, 0.0, 1.0)
	visible = fade > 0.0 and not hidden
	modulate.a = BASE_ALPHA * fade
