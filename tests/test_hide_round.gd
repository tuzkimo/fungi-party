extends TestBase

## 捉迷藏的服务器规则模型：相位、角色、捉到的距离判定、结算。
## 位置由服务器从 MOVE 喂进来（同屏 2P 一个账号两份），模型自己不算几何。

func _r() -> HideRound:
	var r := HideRound.new()
	r.assign(1, 0)               # 0 号座找，1 号座藏
	return r


func test_countdown_then_seeking() -> void:
	var r := _r()
	check_eq(r.phase, "countdown", "开局是倒数")
	r.tick(Config.HIDE_COUNTDOWN - 0.1)
	check_eq(r.phase, "countdown", "差一点还在倒数")
	r.tick(0.2)
	check_eq(r.phase, "seeking", "倒数完进找")
	check(r.left > Config.HIDE_SEEK_SECONDS - 0.5, "找的阶段满时长")


func test_timeout_hider_wins() -> void:
	var r := _r()
	r.tick(Config.HIDE_COUNTDOWN + 0.1)
	r.tick(Config.HIDE_SEEK_SECONDS + 0.1)
	check_eq(r.phase, "over", "找的时间用完就收")
	check_eq(r.winner, 1, "超时藏的人赢")


func test_catch_needs_range_and_seeker() -> void:
	var r := _r()
	r.feed(1, 0, Vector3(0, 0, 0))
	r.feed(0, 0, Vector3(0, 0, Config.HIDE_CATCH + 1.0))
	r.tick(Config.HIDE_COUNTDOWN + 0.1)
	check_eq(r.can_catch(), false, "超出捉到距离不能捉")
	check_eq(r.catch(1), false, "藏的人不能自己捉")
	check_eq(r.catch(0), false, "距离不够的捉不算")
	check_eq(r.over, false, "局没结束")
	r.feed(0, 0, Vector3(0, 0, Config.HIDE_CATCH - 0.2))
	check_eq(r.can_catch(), true, "进范围能捉")
	check_eq(r.catch(0), true, "找的人捉到了")
	check_eq(r.over, true, "捉到就收局")
	check_eq(r.winner, 0, "找的人赢")
	check_eq(r.caught, true, "标记捉到")


func test_catch_needs_positions() -> void:
	var r := _r()
	r.tick(Config.HIDE_COUNTDOWN + 0.1)
	check_eq(r.can_catch(), false, "没人报过位置时不能捉")
	check_eq(r.catch(0), false, "坐标缺一就不算")


func test_two_p_on_each_side_takes_nearest() -> void:
	var r := _r()
	r.feed(1, 0, Vector3(0, 0, 0))
	r.feed(0, 0, Vector3(30, 0, 0))
	r.feed(0, 1, Vector3(1.0, 0, 0))
	r.tick(Config.HIDE_COUNTDOWN + 0.1)
	check_eq(r.can_catch(), true, "2P 的另一个 slot 在范围内也算")


func test_reveal_latches() -> void:
	var r := _r()
	r.feed(1, 0, Vector3(0, 0, 0))
	r.feed(0, 0, Vector3(0, 0, Config.HIDE_REVEAL + 1.0))
	r.tick(0.1)
	check_eq(r.revealed, false, "远的时候没现形")
	r.feed(0, 0, Vector3(0, 0, Config.HIDE_REVEAL - 1.0))
	r.tick(0.1)
	check_eq(r.revealed, true, "进 12 米现形")
	r.feed(0, 0, Vector3(0, 0, 40.0))
	r.tick(0.1)
	check_eq(r.revealed, true, "跑远也不收回现形")


func test_payouts_and_forfeit() -> void:
	var r := _r()
	r.tick(Config.HIDE_COUNTDOWN + 0.1)
	r.forfeit(0)
	check_eq(r.over, true, "放弃就收局")
	check_eq(r.winner, 1, "放弃的人判负")
	check_eq(r.coins_for(1), Config.HIDE_STAKE, "赢家 +5")
	check_eq(r.coins_for(0), -Config.HIDE_STAKE, "输家 -5")
	check_eq(r.coins_for(2), 0, "空座位不结账")


func test_hide_keys_and_flat_distance() -> void:
	var keys := HideRound.hide_keys("甲")
	check_eq(keys, ["甲", "甲|1"] as Array[String], "一个账号占两份世界快照键")
	check_eq(HideRound.flat_distance(Vector3(0, 5, 0), Vector3(3, 9, 4)), 5.0, "只算水平距离")
	check(not is_finite(HideRound.nearest_distance([], [Vector3.ZERO])), "空数组是 INF")


func test_snapshot_fields() -> void:
	var r := _r()
	var s := r.snapshot()
	for key in ["phase", "left", "seeker", "hider", "caught", "revealed", "can_catch", "over", "winner"]:
		check(s.has(key), "快照有 %s" % key)


## 找的人那一份世界快照：没现形之前藏的人整个不在（两份 slot 都剔）。
func test_view_for_hides_hider_when_not_revealed() -> void:
	var players := {"甲": {}, "乙": {}, "乙|1": {}, "丙": {}}
	var seen := HideRound.view_for(players, "甲", "乙", false)
	check_eq(seen.keys().size(), 2, "藏的人两份都剔掉")
	check(seen.has("甲") and seen.has("丙"), "自己和别人还在")
	check_eq(HideRound.view_for(players, "甲", "乙", true).keys().size(), 4, "现形之后照常")
	check_eq(HideRound.view_for(players, "", "乙", false).keys().size(), 4, "没角色就不动")
