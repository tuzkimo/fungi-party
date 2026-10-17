class_name ClassroomUI
extends CanvasLayer

## 教室 HUD：时间/口数/被抓、罚站提示、被抓红晕、结算面板。

signal again_pressed
signal forest_pressed

var _hud: Label
var _stun: Label
var _count: Label
var _flash: ColorRect
var _result: ColorRect
var _title: Label
var _detail: Label


func _ready() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UIStyle.theme()
	add_child(root)

	_hud = Label.new()
	_hud.name = "Hud"
	_hud.position = Vector2(28.0, 18.0)
	root.add_child(_hud)

	_stun = Label.new()
	_stun.name = "Stun"
	_stun.text = "罚站中"
	_stun.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stun.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stun.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_stun.visible = false
	root.add_child(_stun)

	_count = Label.new()
	_count.name = "Countdown"
	_count.set_anchors_preset(Control.PRESET_FULL_RECT)
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_count.add_theme_font_size_override("font_size", 120)
	_count.visible = false
	root.add_child(_count)

	_build_result(root)

	_flash = ColorRect.new()
	_flash.name = "Flash"
	_flash.color = Color(0.85, 0.10, 0.10)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.modulate.a = 0.0
	root.add_child(_flash)


func show_countdown(text: String) -> void:
	_count.text = text
	_count.visible = true


func hide_countdown() -> void:
	_count.visible = false


func set_state(time_left: float, bites: int, caught: int, stunned: bool) -> void:
	_hud.text = "时间 %d　吃了 %d/%d　被抓 %d/%d" % [
		ceili(maxf(time_left, 0.0)), bites, Config.BITES_TO_WIN, caught, Config.MAX_CAUGHT
	]
	_stun.visible = stunned


func show_result(bites: int, caught: int, won: bool, earned: int) -> void:
	_result.visible = true
	_title.text = "赢了！" if won else "时间到"
	_detail.text = "吃了 %d 口，被抓 %d 次，+%d 蘑菇币" % [bites, caught, earned]


func flash() -> void:
	_flash.modulate.a = 0.15
	create_tween().tween_property(_flash, "modulate:a", 0.0, 0.3)


func _build_result(root: Control) -> void:
	_result = ColorRect.new()
	_result.name = "Result"
	_result.color = Color(0.05, 0.04, 0.06, 0.93)
	_result.set_anchors_preset(Control.PRESET_FULL_RECT)
	_result.visible = false
	root.add_child(_result)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_result.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 22)
	center.add_child(box)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)

	_detail = Label.new()
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_detail)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 32)
	box.add_child(row)

	var again := Button.new()
	again.text = "再来一局"
	again.custom_minimum_size = Vector2(200.0, 64.0)
	again.pressed.connect(func() -> void: again_pressed.emit())
	UIStyle.style_button(again)
	row.add_child(again)

	var forest := Button.new()
	forest.text = "回森林"
	forest.custom_minimum_size = Vector2(200.0, 64.0)
	forest.pressed.connect(func() -> void: forest_pressed.emit())
	UIStyle.style_button(forest)
	row.add_child(forest)
