extends TestBase


func _touch(index: int, x: float, pressed: bool) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = Vector2(x, 400.0)
	event.pressed = pressed
	return event


func test_side_of_splits_the_screen() -> void:
	check_eq(EatInput.side_of(100.0, 1280.0), 0, "左半")
	check_eq(EatInput.side_of(640.0, 1280.0), 1, "正中算右半")
	check_eq(EatInput.side_of(1200.0, 1280.0), 1, "右半")


func test_solo_any_finger() -> void:
	var f := EatInput.new()
	f.feed(_touch(3, 1200.0, true), 1280.0)
	check(f.pressing(), "单人任意手指都算按住")
	check(f.pressing(1), "落在右半")
	check(not f.pressing(0), "左半没有手指")
	f.feed(_touch(3, 1200.0, false), 1280.0)
	check(not f.pressing(), "抬手就松开")


func test_each_half_is_its_own_hand() -> void:
	var f := EatInput.new()
	f.feed(_touch(1, 100.0, true), 1280.0)
	check(f.pressing(0), "左边按下，一号位按住")
	check(not f.pressing(1), "二号位不受影响")
	f.feed(_touch(2, 1100.0, true), 1280.0)
	check(f.pressing(1), "右边按下，二号位按住")
	f.feed(_touch(1, 100.0, false), 1280.0)
	check(not f.pressing(0), "一号位松手")
	check(f.pressing(1), "二号位还按着")


func test_clear_drops_every_finger() -> void:
	var f := EatInput.new()
	f.feed(_touch(1, 100.0, true), 1280.0)
	f.clear()
	check(not f.pressing(), "清掉之后没人按着")
