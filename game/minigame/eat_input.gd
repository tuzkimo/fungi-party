class_name EatInput
extends RefCounted

## 「按住 = 吃」。按 finger index 记，每个手指按落点归到左半 / 右半屏 ——
## 双人同屏时一人一半，谁的手指算谁的，不抢也不按错。
## 单人（player 传 -1）时任意一根手指都算，老行为不变。

## finger index -> 0 左半 / 1 右半
var _sides := {}


## width 是视口宽度，用来判左右半。
func feed(event: InputEvent, width: float) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_sides[event.index] = EatInput.side_of(event.position.x, width)
		else:
			_sides.erase(event.index)


## player = -1 表示「任意一根手指按着」（单人）；0 / 1 表示必须落在那一半。
func pressing(player := -1) -> bool:
	if player < 0:
		return not _sides.is_empty()
	for side in _sides.values():
		if int(side) == player:
			return true
	return false


## 系统抢走前台时抬手事件可能永远不来，不清掉就会一直「按着」。
func clear() -> void:
	_sides.clear()


static func side_of(x: float, width: float) -> int:
	return 0 if x < width * 0.5 else 1
