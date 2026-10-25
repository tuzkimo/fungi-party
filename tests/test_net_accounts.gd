extends TestBase

## 账号文件是服务器上唯一持久的东西：写坏了玩家就丢了。

const DIR := "user://test_net_accounts"


func _clean() -> void:
	var abs := ProjectSettings.globalize_path(DIR)
	if not DirAccess.dir_exists_absolute(abs):
		return
	for f in DirAccess.get_files_at(abs):
		DirAccess.remove_absolute(abs.path_join(f))
	DirAccess.remove_absolute(abs)


func _register(player_name: String, password: String) -> Dictionary:
	var ch := Accounts.challenge(DIR, player_name)
	var cred := Accounts.credentials(password, str(ch["salt"]))
	Accounts.register(DIR, player_name, str(cred["salt"]), str(cred["key"]))
	return cred


func _login(player_name: String, key_bytes: PackedByteArray) -> bool:
	var nonce := NetAuth.hex(NetAuth.random_bytes(16))
	var proof := NetAuth.hex(NetAuth.proof(key_bytes, NetAuth.unhex(nonce)))
	return Accounts.verify(DIR, player_name, proof, nonce)


func test_register_then_login() -> void:
	_clean()
	var cred := _register("菌子", "password1")
	check(Accounts.exists(DIR, "菌子"), "注册后有记录")
	check(_login("菌子", cred["key_bytes"]), "口令对能登录")
	_clean()


func test_wrong_password_and_nonce_fail() -> void:
	_clean()
	_register("菌子", "password1")
	var wrong := NetAuth.derive("password2", NetAuth.unhex(Accounts.challenge(DIR, "菌子")["salt"]))
	check(not _login("菌子", wrong), "口令错不能登录")
	# 同一把密钥配别的 nonce 也必须过（proof 是按 nonce 现算的），但旧 proof 不能复用
	var nonce := NetAuth.hex(NetAuth.random_bytes(16))
	var stale := NetAuth.hex(NetAuth.proof(wrong, NetAuth.unhex(nonce)))
	check(not Accounts.verify(DIR, "菌子", stale, nonce), "别的密钥算出的 proof 不认")
	check(not Accounts.verify(DIR, "没这个人", stale, nonce), "不存在的账号不认")
	_clean()


func test_two_accounts_get_different_salts() -> void:
	_clean()
	var a := _register("甲", "password1")
	var b := _register("乙", "password1")
	check(a["salt"] != b["salt"], "同口令也要不同的盐")
	check(not _login("甲", b["key_bytes"]), "乙的密钥登不进甲")
	_clean()


func test_password_never_touches_disk() -> void:
	_clean()
	_register("菌子", "password1")
	var file := FileAccess.open(Accounts.path_for(DIR, "菌子"), FileAccess.READ)
	var text := file.get_as_text()
	file.close()
	check(not text.contains("password1"), "文件里没有明文口令")
	check(text.contains("salt"), "存了盐")
	_clean()


func test_bad_names_rejected() -> void:
	check(not Accounts.valid_name("../etc"), "路径穿越")
	check(not Accounts.valid_name("a/b"), "带斜杠")
	check(not Accounts.valid_name(""), "空名字")
	check(not Accounts.valid_name("a".repeat(Accounts.MAX_NAME + 1)), "太长")
	check(not Accounts.valid_name("菌 子"), "带空格")
	check(not Accounts.valid_name(".hidden"), "隐藏文件")
	check(Accounts.valid_name("菌子"), "正常名字")
	check(not bool(Accounts.challenge(DIR, "../x")["ok"]), "非法名字进不了 challenge")
	check(not bool(Accounts.register(DIR, "../x", "00", "00")["ok"]), "非法名字进不了注册")


func test_partial_write_keeps_other_fields_and_types() -> void:
	_clean()
	_register("菌子", "password1")
	Accounts.write(DIR, "菌子", {"coins": 250, "stamina": 40, "day_time": 0.6})
	Accounts.write(DIR, "菌子", {"coins": 50, "owned": PackedStringArray(["blueberry"]), "pity": 7})
	var data := Accounts.read(DIR, "菌子")
	check_eq(data["coins"], 50, "币按新的写")
	check_eq(data["stamina"], 40, "体力不被别的写入抹掉")
	check(absf(float(data["day_time"]) - 0.6) < 0.001, "天色不被别的写入抹掉")
	check_eq(data["pity"], 7, "保底计数按新的写")
	# JSON 读回来整数是浮点、PackedStringArray 是 Array：这里必须已经被 normalize 收口
	check_eq(typeof(data["coins"]), TYPE_INT, "币还是 int")
	check_eq(typeof(data["owned"]), TYPE_PACKED_STRING_ARRAY, "owned 还是 PackedStringArray")
	check_eq(typeof(data["day_time"]), TYPE_FLOAT, "天色还是 float")
	check((data["owned"] as PackedStringArray).has("blueberry"), "皮肤还在")
	_clean()


func test_writes_leave_no_tmp_and_survive_reread() -> void:
	_clean()
	_register("菌子", "password1")
	Accounts.write(DIR, "菌子", {"coins": 999})
	var abs := ProjectSettings.globalize_path(DIR)
	var names := DirAccess.get_files_at(abs)
	check_eq(names.size(), 1, "目录里只有一个文件（实得 %s）" % [names])
	check_eq(int(Accounts.read(DIR, "菌子")["coins"]), 999, "重读拿到新值")
	_clean()


func test_unknown_account_reads_defaults() -> void:
	_clean()
	var data := Accounts.read(DIR, "没这个人")
	check_eq(int(data["coins"]), 0, "不存在的账号给缺省存档")
	# 写不存在的账号不许凭空造出文件
	Accounts.write(DIR, "没这个人", {"coins": 100000})
	check(not Accounts.exists(DIR, "没这个人"), "写不存在的账号不建文件")
	_clean()
