extends SceneTree

## 本地 / 测试用的服务端入口：导出的运行时二进制没有 --script，只能用主场景起；
## 开发时用这个 8 行壳把同一个 Node（server_main.gd）挂到 root 上。
##   godot --headless --path . --script res://game/net/server_local.gd -- --port 7099 --saves build/accounts

func _initialize() -> void:
	var srv: Node = load("res://game/net/server_main.gd").new()
	srv.name = "Server"
	# 直接 add_child 会撞「Parent node is busy setting up children」
	root.add_child.call_deferred(srv)
