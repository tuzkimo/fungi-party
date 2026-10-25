extends TestBase

## 信封是唯一的进程间信任边界：解不开的东西一律 ok=false，不能半解。


func test_roundtrip_keeps_chinese_name() -> void:
	var out := NetProtocol.unpack(NetProtocol.pack(NetProtocol.Msg.HELLO, {"name": "阿菌"}))
	check(bool(out["ok"]), "能解开")
	check_eq(int(out["kind"]), int(NetProtocol.Msg.HELLO), "类型原样")
	check_eq(str((out["body"] as Dictionary)["name"]), "阿菌", "中文昵称原样")


func test_packed_version_is_current() -> void:
	var raw: Dictionary = bytes_to_var(NetProtocol.pack(NetProtocol.Msg.OP, {}))
	check_eq(int(raw["v"]), NetProtocol.VERSION, "打出来的信封带当前版本")


func test_version_mismatch_is_rejected() -> void:
	var raw := var_to_bytes({"v": NetProtocol.VERSION + 1, "t": 0, "b": {}})
	var out := NetProtocol.unpack(raw)
	check(not bool(out["ok"]), "版本不符要拒")
	check_eq(str(out["reason"]), "version", "理由是版本")


func test_garbage_is_rejected() -> void:
	check_eq(str(NetProtocol.unpack(PackedByteArray([1, 2, 3]))["reason"]), "garbage", "随机字节不是信封")
	check_eq(str(NetProtocol.unpack(var_to_bytes([1, 2, 3]))["reason"]), "garbage", "数组不是信封")
	check_eq(str(NetProtocol.unpack(var_to_bytes({"v": NetProtocol.VERSION, "t": 0}))["reason"]), "garbage", "缺字段不是信封")


func test_empty_and_oversize_rejected() -> void:
	check_eq(str(NetProtocol.unpack(PackedByteArray())["reason"]), "size", "空包")
	var huge := PackedByteArray()
	huge.resize(NetProtocol.MAX_PACKET + 1)
	check_eq(str(NetProtocol.unpack(huge)["reason"]), "size", "超长包")
	check_eq(NetProtocol.pack(NetProtocol.Msg.OP, {"x": "a".repeat(NetProtocol.MAX_PACKET)}).size(), 0, "打包也不许超长")
