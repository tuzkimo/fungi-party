extends TestBase

## 客户端镜像上那点事：几个字段的消费语义，不起网络也能验。

func test_take_events_only_once() -> void:
	# 快照 20 Hz、场景 60 Hz：不清的话同一批事件会被重放三遍（音效连发、飞行重启）
	var client := NetClient.new()
	client.session = {"kind": "bomb", "game": {"events": [{"kind": "throw"}]}}
	check_eq(client.take_events().size(), 1, "第一批事件拿得到")
	check_eq(client.take_events().size(), 0, "同一批不会被重放")
	check_eq((client.session["game"] as Dictionary).has("events"), false, "消费过的从镜像里抹掉")
	client.free()


func test_take_events_without_a_game_is_empty() -> void:
	var client := NetClient.new()
	check_eq(client.take_events().size(), 0, "没有局内快照就是空的")
	client.free()


## 帐篷 / 饭店的置灰和服务器那道门槛看同一个东西：服务器给的 now 对上次的时间戳
func test_server_now_drives_the_cooldown() -> void:
	var client := NetClient.new()
	check(client.server_now() > 0.0, "还没收到 WORLD 就用本机时间兜底（只用来画倒计时）")
	client.now = 1_700_000_000.0
	check_eq(client.server_now(), 1_700_000_000.0, "收到过就只认服务器那份")
	Save.remote = client
	client.data = Save.normalize({"sleep_at": 1_700_000_030.0})
	check(Save.sleep_wait() > 0.0, "离上次睡觉还没到点")
	client.data = Save.normalize({"sleep_at": 1_700_000_000.0 - Config.SLEEP_COOLDOWN_SECONDS})
	check_eq(Save.sleep_wait(), 0.0, "过点了就能睡")
	client.data = Save.normalize({})
	check_eq(Save.sleep_wait(), 0.0, "老存档没睡过 → 立刻能睡")
	Save.remote = null
	client.free()


## 自动登录用的那把密钥：存过就直接用（不再跑一遍八万轮迭代），没存过才拿口令现算。
func test_key_for_prefers_the_saved_key() -> void:
	var salt := NetAuth.hex(PackedByteArray([1, 2, 3, 4]))
	var saved := "aabbccdd"
	check_eq(NetClient.key_for(saved, "随便什么口令", salt), saved, "存过密钥就用它，口令不参与")
	var derived := NetClient.key_for("", "password1", salt)
	check_eq(derived, NetAuth.hex(NetAuth.derive("password1", PackedByteArray([1, 2, 3, 4]))), "没存过就现算")
	check(derived != NetClient.key_for("", "password2", salt), "不同口令算出来的不一样")


## 断开以后本机那份凭据也要丢掉，否则下一次「输密码登录」会拿着上次的密钥去冒充。
func test_close_forgets_the_key() -> void:
	var client := NetClient.new()
	client.key_hex = "aabbccdd"
	client.close()
	check_eq(client.key_hex, "", "close() 之后没有凭据")
	client.free()
