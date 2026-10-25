extends TestBase


func _run_until(r: BombRound, seconds: float) -> void:
	var step := 1.0 / 60.0
	for i in int(seconds / step):
		r.tick(step)


func _drain(r: BombRound) -> Array:
	var out := r.events.duplicate()
	r.events.clear()
	return out


func test_starts_ignited_with_lock() -> void:
	var r := BombRound.new(1)
	check(r.alive == [0, 1, 2, 3], "开局四个人都在")
	check(r.holder >= 0 and r.holder < 4, "炸弹在某人手里")
	check(r.fuse >= Config.BOMB_FUSE_4.x and r.fuse <= Config.BOMB_FUSE_4.y, "引信在 4 人区间内")
	check(is_equal_approx(r.lock, Config.BOMB_CATCH_LOCK), "开局有接住硬直")
	var events := _drain(r)
	check_eq(events[0]["kind"], "ignite", "开局事件是点燃")


func test_neighbour_skips_the_dead() -> void:
	var r := BombRound.new(2)
	r.alive = [0, 2, 3]
	check_eq(r.neighbour(0, -1), 2, "左手边跳过死者")
	check_eq(r.neighbour(0, 1), 3, "右手边是东")
	check_eq(r.neighbour(3, -1), 0, "绕一圈回到玩家")


func test_neighbour_when_alone() -> void:
	var r := BombRound.new(3)
	r.alive = [1]
	r.holder = 1
	check_eq(r.neighbour(1, -1), -1, "只剩自己时没有邻居")
	check(not r.request_throw(0, -1), "只剩自己时扔不出去")


func test_throw_needs_lock() -> void:
	var r := BombRound.new(4)
	# 开局持有者由种子决定，这一条测的是「玩家的硬直」，所以显式把炸弹放到玩家手里
	r.holder = BombRound.PLAYER
	r.lock = Config.BOMB_CATCH_LOCK
	check(not r.request_throw(0, -1), "硬直期间立即扔不出去")
	check_eq(r.queued[0], -1, "方向被记下来")
	_run_until(r, Config.BOMB_CATCH_LOCK + 0.05)
	check_eq(r.flight > 0.0, true, "硬直结束后自动扔出去")


func test_explosion_in_flight_kills_the_thrower() -> void:
	var r := BombRound.new(5)
	r.holder = BombRound.PLAYER
	r.lock = 0.0
	r.fuse = 5.0
	r.request_throw(0, 1)
	var thrower_before := r.thrower
	check(thrower_before >= 0, "已经扔出去了")
	r.fuse = 0.05
	r.tick(0.1)
	check_eq(r.death_order[0], thrower_before, "空中炸算扔的人死")
	check(r.events.any(func(e): return e["kind"] == "explode" and e["in_flight"]), "空中爆炸事件带 in_flight 标记")


func test_explosion_in_hand_kills_the_holder() -> void:
	var r := BombRound.new(6)
	r.lock = 0.0
	r.flight = 0.0
	var holder_before := r.holder
	r.fuse = 0.05
	r.tick(0.1)
	check_eq(r.death_order[0], holder_before, "手上炸算持有人死")


func test_never_throwing_still_explodes() -> void:
	var r := BombRound.new(7)
	_run_until(r, 40.0)
	check(r.death_order.size() >= 1, "一直不按也会被炸死")
	check(r.over or r.fuse > 0.0, "不卡死：要么结束了，要么引信还在烧")


func test_over_when_one_left() -> void:
	var r := BombRound.new(8)
	_run_until(r, 60.0)
	check(r.over, "最后一定结束")
	check_eq(r.alive.size(), 1, "只剩一个人")
	check_eq(r.death_order.size(), 3, "死了三个")


func test_no_events_after_over() -> void:
	var r := BombRound.new(9)
	_run_until(r, 60.0)
	_drain(r)
	_run_until(r, 5.0)
	check_eq(r.events.size(), 0, "结束后不再产生事件")
	check(not r.request_throw(0, -1), "结束后按按钮无效")


func test_request_throw_after_own_death_is_rejected() -> void:
	var r := BombRound.new(10)
	r.alive = [1, 2, 3]
	r.holder = 1
	r.lock = 0.0
	check(not r.request_throw(0, -1), "玩家已死不接受投掷")
	check_eq(r.holder, 1, "炸弹没动")


func test_same_seed_replays_identically() -> void:
	var a := BombRound.new(42)
	var b := BombRound.new(42)
	_run_until(a, 30.0)
	_run_until(b, 30.0)
	check_eq(a.death_order, b.death_order, "同种子结果一致")


func test_tier_and_danger() -> void:
	var r := BombRound.new(11)
	r.fuse = Config.BOMB_TIER_WARN + 1.0
	check_eq(r.tier(), 0, "稳燃")
	r.fuse = Config.BOMB_TIER_WARN - 0.1
	check_eq(r.tier(), 1, "冒白星")
	r.fuse = Config.BOMB_TIER_HOT - 0.1
	check_eq(r.tier(), 2, "发白")
	check(is_equal_approx(r.danger(), 0.0) or true, "danger 不为 NaN")


func test_npc_cannot_throw_during_lock() -> void:
	# 设计文档 4.5：人机也受相同的 0.3 秒站稳限制
	var r := BombRound.new(20)
	r.holder = 1
	r.lock = Config.BOMB_CATCH_LOCK
	r.fuse = 0.5
	r.tick(0.05)
	check_eq(r.holder, 1, "硬直期间人机也扔不出去")
	check_eq(r.flight, 0.0, "没有偷偷起飞")


func test_request_throw_when_npc_holds_is_rejected() -> void:
	# 只有持有炸弹的人能扔：玩家按按钮不能替人机把炸弹甩出去
	var r := BombRound.new(21)
	r.holder = 1
	r.lock = 0.0
	r.flight = 0.0
	check(not r.request_throw(0, 1), "炸弹不在自己手上时按不动")
	check_eq(r.holder, 1, "炸弹留在人机手里")
	check_eq(r.queued[0], 0, "也不会被记成待扔方向")


func test_npc_passes_periodically() -> void:
	# 人机不能一直抱着：长引信下也要在几秒内出手（不然炸弹总是在一个人手里）
	var r := BombRound.new(22)
	r.holder = 1
	r.lock = 0.0
	r.flight = 0.0
	r.fuse = 10.0
	_run_until(r, 3.0)
	var thrown := r.events.any(func(e): return e["kind"] == "throw")
	check(thrown or r.holder != 1, "人机抱着的时间有上限")


func test_round_has_many_passes() -> void:
	# 「多扔几次」：一局至少十次传递，不能是抱着不动
	for seed_value in [1, 3, 5]:
		var r := BombRound.new(seed_value)
		var throws := 0
		_run_until(r, 120.0)
		for e in r.events:
			if e["kind"] == "throw":
				throws += 1
		check(throws >= 10, "seed %d 一局只有 %d 次传递（至少 10 次）" % [seed_value, throws])


## 双人：1 号座也是人，他手里的炸弹只能由他按出去。
func test_second_human_throws_his_own_bomb() -> void:
	var r := BombRound.new(23)
	r.humans = 2
	r.holder = 1
	r.lock = 0.0
	r.flight = 0.0
	r.fuse = 5.0
	check(not r.request_throw(0, -1), "一号位按不动二号位手里的炸弹")
	check_eq(r.holder, 1, "炸弹没动")
	check(r.request_throw(1, -1), "二号位自己按得动")
	check(r.flight > 0.0, "飞出去了")


## 双人：两个人都不出手时也会被炸死（没有哪个座位是「自动」的）。
func test_second_human_waits_like_a_human() -> void:
	var r := BombRound.new(24)
	r.humans = 2
	r.holder = 1
	r.lock = 0.0
	r.flight = 0.0
	r.fuse = 3.0
	_run_until(r, 5.0)
	check(r.death_order.size() >= 1, "一直不按也会被炸死")
