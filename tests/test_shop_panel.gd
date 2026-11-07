extends "res://tests/test_base.gd"

## 摊位的抽卡：联机时币和已拥有的皮肤都在服务器上，本机那份只读。
## 走本机 Gacha.pull 等于白抽（不扣钱、抽到的也不算数），所以联机一律发 op。


class FakeNet extends NetClient:
	var asked: Array = []

	func request(op: String, args: Dictionary = {}) -> void:
		asked.append({"op": op, "args": args})


## `Save.remote` 是静态的，测完一定要还原，否则后面的用例会以为自己在联机。
func test_online_pull_asks_the_server() -> void:
	var net := FakeNet.new()
	Save.remote = net
	var panel := ShopPanel.new()
	panel._ready()
	panel._pull(1)
	check_eq(net.asked.size(), 1, "联机单抽发一条 op")
	check_eq(str((net.asked[0] as Dictionary)["op"]), "pull", "op 是 pull")
	check_eq(int(((net.asked[0] as Dictionary)["args"] as Dictionary)["n"]), 1, "报的是单抽")
	check_eq(panel._awaiting, 1, "在等服务器回执")
	check(panel._one.disabled and panel._ten.disabled, "等回执时两个都按不动（不是点了没反应）")
	check_eq(panel._one.text, "抽卡中...", "按钮上写明在等")

	# 回执没到之前不再发第二条（币是服务器扣的，别叠着抽）
	panel._pull(10)
	check_eq(net.asked.size(), 1, "还没回执就再点，不会多抽一条")

	panel.free()
	net.free()
	Save.remote = null


## 回执到了才放演出，且只放一次：`last_result` 里还留着上一条，别把它再演一遍。
func test_online_pull_shows_the_server_result_once() -> void:
	var net := FakeNet.new()
	Save.remote = net
	var panel := ShopPanel.new()
	panel._ready()
	panel._pull(1)
	var old: Dictionary = net.last_result

	# 服务器扣钱、发卡、回执
	net.data = Save.normalize({"coins": 50, "owned": PackedStringArray(["blueberry"])})
	net.last_result = {
		"op": "pull", "ok": true, "result": {"pulls": [{"id": "blueberry", "rarity": 2, "duplicate": false, "refund": 0}]}
	}
	panel._take_online_pull()
	check_eq(panel._awaiting, 0, "回执到了就不等了")
	check_eq(panel._results.get_child_count(), 1, "结果画了一张卡")
	check_eq(panel._coins.text.split(" ")[1], "50", "币是服务器扣完那份")
	check(not panel._one.disabled, "回执到了按钮恢复")

	# 再点一次：新回执还没到之前，别把上一条再演一遍
	panel._pull(1)
	panel._take_online_pull()
	check_eq(panel._awaiting, 1, "新回执没到就还在等")
	check_eq(panel._results.get_child_count(), 1, "没重放上一次的结果")

	check(not is_same(old, net.last_result), "认新回执靠的确实是「换了个字典」")
	panel.free()
	net.free()
	Save.remote = null
