class_name Controls

## 键鼠动作在代码里注册，不写进 project.godot：
## 序列化的 InputEvent 长串手写容易随版本漂移，代码里几行搞定。

const ACTION_KEYS := {
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"jump": [KEY_SPACE],
	"run": [KEY_SHIFT],
	"orbit": [KEY_CTRL],
}


static func ensure() -> void:
	for action in ACTION_KEYS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		if InputMap.action_get_events(action).is_empty():
			for keycode in ACTION_KEYS[action]:
				var event := InputEventKey.new()
				event.physical_keycode = keycode
				InputMap.action_add_event(action, event)
