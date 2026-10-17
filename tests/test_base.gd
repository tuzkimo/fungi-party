class_name TestBase

var failures := 0
var total := 0

func check(cond: bool, msg: String) -> void:
	total += 1
	if not cond:
		failures += 1
		printerr("FAIL: %s" % msg)

func check_eq(actual: Variant, expected: Variant, msg: String) -> void:
	check(actual == expected, "%s（期望 %s，实得 %s）" % [msg, expected, actual])
