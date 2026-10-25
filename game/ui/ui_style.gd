class_name UIStyle

## 三个浮层（教室 HUD、商店、校门）共用的外观：
## 系统字体（默认字体没有中文字形）、深色面板、看得见的按钮底。
## 系统字体不是自家的：动态拼进去的文字只用 ASCII 标点（??? 与半角括号），
## 全角的 ？ （） 在真机上是豆腐块（框里写着 FF1F）。

const BUTTON_COLORS := {
	"normal": Color(0.24, 0.22, 0.26),
	"hover": Color(0.32, 0.30, 0.35),
	"pressed": Color(0.17, 0.16, 0.19),
	"disabled": Color(0.13, 0.12, 0.14),
}


static func theme() -> Theme:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Noto Sans CJK SC", "Noto Sans SC", "Droid Sans Fallback", "sans-serif"])
	font.allow_system_fallback = true
	var result := Theme.new()
	result.default_font = font
	result.default_font_size = 28
	return result


static func panel() -> StyleBoxFlat:
	# 默认 Panel 是半透明的，场景穿过来会把字吃掉
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.06, 0.08, 0.93)
	style.set_corner_radius_all(14)
	style.content_margin_left = 32.0
	style.content_margin_right = 32.0
	style.content_margin_top = 22.0
	style.content_margin_bottom = 22.0
	return style


## border 给档位描边用：不传就是原来那样没有边框。
static func style_button(button: Button, border := Color(0.0, 0.0, 0.0, 0.0)) -> void:
	for state in BUTTON_COLORS:
		var style := StyleBoxFlat.new()
		style.bg_color = BUTTON_COLORS[state]
		style.set_corner_radius_all(10)
		style.content_margin_left = 20.0
		style.content_margin_right = 20.0
		style.content_margin_top = 8.0
		style.content_margin_bottom = 8.0
		if border.a > 0.0:
			style.border_color = border
			style.set_border_width_all(3)
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_disabled_color", Color(0.55, 0.53, 0.57))
