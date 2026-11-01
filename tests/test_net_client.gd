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
