class_name EatInput
extends RefCounted

## 「按住 = 吃」的输入。按 finger index 绑定，不按坐标判定：
## 手指滑到屏幕边缘照样算按住，只有记住的那根抬起才松手。

var finger := -1


func feed(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		finger = next_finger(finger, event.index, event.pressed)


func pressing() -> bool:
	return finger >= 0


static func next_finger(current: int, index: int, pressed: bool) -> int:
	if pressed:
		return current if current >= 0 else index
	return -1 if index == current else current
