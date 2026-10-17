extends TestBase

func test_tracks_finger() -> void:
	var f := EatInput.next_finger(-1, 2, true)
	check_eq(f, 2, "按下记住手指")
	check_eq(EatInput.next_finger(f, 0, true), 2, "别的手指按下不影响")
	check_eq(EatInput.next_finger(f, 2, false), -1, "记住的那根抬起才松手")
	check_eq(EatInput.next_finger(f, 0, false), 2, "别的手指抬起不算松手")
