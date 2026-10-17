extends SceneTree

func _initialize() -> void:
	var files := _test_files()
	var total := 0
	var failures := 0
	for f in files:
		var script: GDScript = load("res://tests/%s" % f)
		if script == null:
			printerr("无法加载 tests/%s" % f)
			failures += 1
			continue
		var case: Object = script.new()
		var before: int = case.failures
		for m in case.get_method_list():
			var method_name: String = m["name"]
			if method_name.begins_with("test_"):
				case.call(method_name)
				total += 1
		failures += case.failures - before
		print("  %s: %d 项，失败 %d" % [f, case.total, case.failures])
	print("测试 %d 项，失败 %d 项" % [total, failures])
	quit(1 if failures > 0 else 0)

func _test_files() -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open("res://tests")
	if dir == null:
		printerr("找不到 tests 目录")
		return result
	for f in dir.get_files():
		if f.begins_with("test_") and f.ends_with(".gd") and f != "test_base.gd":
			result.append(f)
	result.sort()
	return result
