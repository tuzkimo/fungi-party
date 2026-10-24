extends TestBase

## test.sh 把编辑器扫描的输出丢掉了，所以 UI 脚本语法错了测试也照样全绿。
## 这里把 game/ 下每个 .gd 都 load 一遍，编译不过就红。


func test_every_game_script_compiles() -> void:
	var files: Array[String] = []
	_collect("res://game", files)
	check(files.size() > 10, "扫到 %d 个脚本" % files.size())
	for path in files:
		var script := load(path)
		check(script != null, "%s 能编译" % path)


func _collect(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for f in dir.get_files():
		if f.ends_with(".gd"):
			out.append("%s/%s" % [dir_path, f])
	for sub in dir.get_directories():
		_collect("%s/%s" % [dir_path, sub], out)
