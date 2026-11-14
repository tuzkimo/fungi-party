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


## 座位形象：自己那份按本机存档，别人按他 MOVE 报上来的 body / skin（别再画成 NPC 色块）
func test_seat_look_prefers_the_players_own_look() -> void:
	var client := NetClient.new()
	client.player_name = "我"
	client.session = {
		"seats": [
			{"account": "我", "npc": false},
			{"account": "别人", "npc": false},
			{"account": "", "npc": true},
		],
	}
	client.world = {"别人": {"body": "seafood", "skin": "poop"}}
	check_eq(str(client.seat_look(0)["body"]), str(Save.read()["character"]), "自己按存档")
	var other := client.seat_look(1)
	check_eq([str(other["body"]), str(other["skin"])], ["seafood", "poop"], "别人按他报上来的形象")
	var unknown := client.seat_look(5)
	check_eq(str(unknown["body"]), str(Save.read()["character"]), "座位表里没有就按自己那份")
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


func test_in_any_room() -> void:
	var client := NetClient.new()
	check_eq(client.in_any_room(), false, "没连上不算在局里")
	client.state = NetClient.State.READY
	check_eq(client.in_any_room(), false, "连上了但没被拉进局也不算")
	client.session = {"kind": "poop"}
	check_eq(client.in_any_room(), true, "在局里")
	check_eq(client.in_room("poop"), true, "in_room 照样按款判")
	check_eq(client.in_room("hide"), false, "不是这一款就不是")
	client.session = {"kind": "poop", "over": true}
	check_eq(client.in_any_room(), false, "收了的局不算在局里")
	client.free()
