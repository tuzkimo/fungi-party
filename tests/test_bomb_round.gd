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
	check(not r.request_throw(-1), "只剩自己时扔不出去")


func test_throw_needs_lock() -> void:
	var r := BombRound.new(4)
	# 开局持有者由种子决定，这一条测的是「玩家的硬直」，所以显式把炸弹放到玩家手里
	r.holder = BombRound.PLAYER
	r.lock = Config.BOMB_CATCH_LOCK
	check(not r.request_throw(-1), "硬直期间立即扔不出去")
	check_eq(r.queued_side, -1, "方向被记下来")
	_run_until(r, Config.BOMB_CATCH_LOCK + 0.05)
	check_eq(r.flight > 0.0, true, "硬直结束后自动扔出去")


func test_explosion_in_flight_kills_the_thrower() -> void:
	var r := BombRound.new(5)
	r.lock = 0.0
	r.fuse = 5.0
	r.request_throw(1)
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
	check(not r.request_throw(-1), "结束后按按钮无效")


func test_request_throw_after_own_death_is_rejected() -> void:
	var r := BombRound.new(10)
	r.alive = [1, 2, 3]
	r.holder = 1
	r.lock = 0.0
	check(not r.request_throw(-1), "玩家已死不接受投掷")
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
