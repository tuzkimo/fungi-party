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


## 帐篷的置灰和服务器那道门槛看同一个东西：slept_day 对世界时钟的今天
func test_slept_today_follows_the_world_day() -> void:
	var client := NetClient.new()
	check(not client.slept_today(), "镜像还没下来就是没睡过")
	client.data = Save.normalize({"slept_day": 3})
	client.day = 3
	check(client.slept_today(), "同一天算睡过")
	client.day = 4
	check(not client.slept_today(), "第二天又没睡过")
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
