extends TestBase

## 扔粑粑的服务器规则：抢粪、直线飞行、三次命中、超时判。

const SEED := 7


func _r() -> PoopRound:
	return PoopRound.new(2, SEED)


## 屎壳郎摆成固定位置（不依赖随机撒点）
func _place(r: PoopRound, spots: Array) -> void:
	r.beetles.clear()
	for spot in spots:
		r.beetles.append({"x": spot.x, "z": spot.z, "yaw": 0.0, "ball": true, "timer": 999.0, "refill": 0.0})


## 让人站到第 beetle 只的粪球上（另一个座位扔到很远，免得顺手抢到别的球）
func _stand_on_ball(r: PoopRound, seat: int, beetle: int) -> void:
	var ball := PoopRound.ball_at(r.beetles[beetle])
	r.feed(seat, 0, Vector3(ball.x, 0.0, ball.y))
	r.feed(1 - seat, 0, Vector3(500.0, 0.0, 500.0))
	r.tick(0.0)


func test_fresh_round_is_empty() -> void:
	var r := _r()
	check_eq(r.left, Config.POOP_SECONDS, "开局满时长")
	check_eq(int(r.ammo.get(0, 0)), 0, "0 号座没弹药")
	check_eq(int(r.hits.get(1, 0)), 0, "1 号座没挨打")
	check_eq(r.beetles.size(), 0, "没人报位置之前不撒屎壳郎")
	check_eq(r.over, false, "没结束")


func test_anchor_spawns_beetles_once() -> void:
	var r := _r()
	r.anchor(Vector3(10.0, 0.0, -4.0))
	check_eq(r.beetles.size(), Config.POOP_BEETLES, "撒 %d 只" % Config.POOP_BEETLES)
	for b in r.beetles:
		var at := Vector2(float(b["x"]), float(b["z"]))
		check(at.distance_to(Vector2(10.0, -4.0)) <= Config.POOP_SPAWN_RADIUS + 0.001, "撒在中点附近")
		check_eq(b["ball"], true, "每只都推着一个球")
	r.anchor(Vector3(-50.0, 0.0, 0.0))
	check_eq(r.beetles.size(), Config.POOP_BEETLES, "锚点只认第一次，再调不多撒一层")


func test_ball_sits_in_front_of_the_beetle() -> void:
	var front := Vector2(3.0, 4.0 - Config.POOP_BALL_AHEAD)
	check(PoopRound.ball_at({"x": 3.0, "z": 4.0, "yaw": 0.0}).is_equal_approx(front), "朝 -Z 推着")
	var back := Vector2(3.0, 4.0 + Config.POOP_BALL_AHEAD)
	check(PoopRound.ball_at({"x": 3.0, "z": 4.0, "yaw": PI}).is_equal_approx(back), "转半圈球在另一头")


func test_walking_onto_a_ball_picks_it_up() -> void:
	var r := _r()
	_place(r, [Vector3(0.0, 0.0, 0.0)])
	r.feed(0, 0, Vector3(0.0, 0.0, 3.0 - Config.POOP_BALL_AHEAD))
	r.tick(0.0)
	check_eq(int(r.ammo.get(0, 0)), 0, "离 3 米抢不到")
	check_eq(r.beetles[0]["ball"], true, "球还在")
	_stand_on_ball(r, 0, 0)
	check_eq(int(r.ammo.get(0, 0)), 1, "走到球上自动拿到一个")
	check_eq(r.beetles[0]["ball"], false, "球被拿走了")


func test_full_slots_refuse_more() -> void:
	var r := _r()
	_place(r, [Vector3(0, 0, 0), Vector3(50, 0, 0), Vector3(100, 0, 0), Vector3(150, 0, 0)])
	for i in Config.POOP_AMMO_MAX:
		_stand_on_ball(r, 0, i)
	check_eq(int(r.ammo.get(0, 0)), Config.POOP_AMMO_MAX, "满槽 %d 发" % Config.POOP_AMMO_MAX)
	_stand_on_ball(r, 0, 3)
	check_eq(int(r.ammo.get(0, 0)), Config.POOP_AMMO_MAX, "满了不再抢")
	check_eq(r.beetles[3]["ball"], true, "球留在原地，谁缺谁拿")


func test_ball_grows_back_after_a_while() -> void:
	var r := _r()
	_place(r, [Vector3(0, 0, 0)])
	_stand_on_ball(r, 0, 0)
	r.feed(0, 0, Vector3(500.0, 0.0, 500.0))
	r.tick(Config.POOP_BALL_REFILL - 0.2)
	check_eq(r.beetles[0]["ball"], false, "还没补上")
	r.tick(0.4)
	check_eq(r.beetles[0]["ball"], true, "%s 秒后屎壳郎又推一个出来" % Config.POOP_BALL_REFILL)


func test_throw_needs_ammo_and_a_direction() -> void:
	var r := _r()
	_place(r, [Vector3(0, 0, 0)])
	r.feed(0, 0, Vector3.ZERO)
	check_eq(r.throw_poop(0, Vector3.FORWARD), false, "没弹药扔不出去")
	_stand_on_ball(r, 0, 0)
	check_eq(r.throw_poop(0, Vector3.ZERO), false, "零向量不收")
	check_eq(r.throw_poop(0, Vector3(INF, 0.0, 0.0)), false, "非有限数不收")
	check_eq(r.throw_poop(0, Vector3.FORWARD), true, "有弹药有方向就飞出去")
	check_eq(int(r.ammo[0]), 0, "扔一发少一个")
	check_eq(r.shots.size(), 1, "天上有一发")


func test_throw_without_positions_fails() -> void:
	var r := _r()
	_place(r, [Vector3(0, 0, 0)])
	r.ammo[0] = 1
	check_eq(r.throw_poop(0, Vector3.FORWARD), false, "没报过位置不知道从哪扔")


func test_straight_shot_hits_the_chest() -> void:
	var r := _r()
	_place(r, [Vector3(0, 0, 0)])
	_stand_on_ball(r, 0, 0)
	r.feed(0, 0, Vector3.ZERO)
	r.feed(1, 0, Vector3(0.0, 0.0, -8.0))
	r.throw_poop(0, Vector3.FORWARD)
	r.tick(0.2)
	r.tick(0.2)
	check_eq(int(r.hits[1]), 0, "两步才到 -5.6 米，还没打中")
	r.tick(0.2)
	check_eq(int(r.hits[1]), 1, "这一步跨过 -8 米，线段扫到胸口（点判会漏）")
	check_eq(r.shots.size(), 0, "打中就消失")


func test_shot_misses_when_aimed_aside() -> void:
	var r := _r()
	_place(r, [Vector3(0, 0, 0)])
	_stand_on_ball(r, 0, 0)
	r.feed(0, 0, Vector3.ZERO)
	r.feed(1, 0, Vector3(0.0, 0.0, -8.0))
	r.throw_poop(0, Vector3(1.0, 0.0, -1.0))
	r.tick(Config.POOP_RANGE / Config.POOP_THROW_SPEED + 0.1)
	check_eq(int(r.hits[1]), 0, "斜着扔打不中")
	check_eq(r.shots.size(), 0, "飞满 %d 米就自己没了" % Config.POOP_RANGE)


func test_two_p_slots_both_count() -> void:
	var r := _r()
	_place(r, [Vector3(0, 0, 0)])
	_stand_on_ball(r, 0, 0)
	r.feed(0, 0, Vector3.ZERO)
	r.feed(1, 0, Vector3(50.0, 0.0, 0.0))
	r.feed(1, 1, Vector3(0.0, 0.0, -6.0))
	r.throw_poop(0, Vector3.FORWARD)
	for i in 4:
		r.tick(0.15)
	check_eq(int(r.hits[1]), 1, "同屏 2P 那个 slot 被打中也算这个账号")


func test_three_hits_ends_the_round() -> void:
	var r := _r()
	_place(r, [Vector3(0, 0, 0)])
	r.feed(0, 0, Vector3.ZERO)
	r.feed(1, 0, Vector3(0.0, 0.0, -8.0))
	r.ammo[0] = Config.POOP_HITS   # 抢粪那条路另有测试，这里直接给弹药
	for i in Config.POOP_HITS:
		r.throw_poop(0, Vector3.FORWARD)
		for j in 4:
			r.tick(0.15)
	check_eq(int(r.hits[1]), Config.POOP_HITS, "打中 %d 次" % Config.POOP_HITS)
	check_eq(r.over, true, "三次就收局")
	check_eq(r.winner, 0, "扔的人赢")
	check_eq(r.coins_for(0), Config.POOP_STAKE, "赢的拿 %d 币" % Config.POOP_STAKE)
	check_eq(r.coins_for(1), -Config.POOP_STAKE, "输的付")
	check_eq(r.coins_for(2), 0, "没坐人的座位不算账")


func test_timeout_tie_pays_nothing() -> void:
	var r := _r()
	r.tick(Config.POOP_SECONDS + 0.1)
	check_eq(r.over, true, "到点收局")
	check_eq(r.winner, -1, "打平没有赢家")
	check_eq(r.coins_for(0), 0, "平局不结账")
	check_eq(r.coins_for(1), 0, "平局不结账")


func test_timeout_fewer_hits_wins() -> void:
	var r := _r()
	r.hits[1] = 1
	r.tick(Config.POOP_SECONDS + 0.1)
	check_eq(r.winner, 0, "挨得少的赢")
	check_eq(r.coins_for(0), Config.POOP_STAKE, "赢的照拿")
	check_eq(r.coins_for(1), -Config.POOP_STAKE, "挨得多的付")


func test_forfeit_pays() -> void:
	var r := _r()
	check_eq(r.forfeit(1), true, "认输算数")
	check_eq(r.over, true, "认输就收局")
	check_eq(r.winner, 0, "对方赢")
	check_eq(r.coins_for(1), -Config.POOP_STAKE, "认输照付")
	check_eq(r.forfeit(0), false, "收了的局不能再认")


func test_snapshot_shape() -> void:
	var r := _r()
	r.anchor(Vector3.ZERO)
	var snap := r.snapshot()
	for key in ["left", "hits", "ammo", "beetles", "shots", "over", "winner"]:
		check(snap.has(key), "快照有 %s" % key)
	check_eq((snap["hits"] as Array).size(), Config.SEAT_COUNT, "命中按座位排到 SEAT_COUNT")
	check_eq((snap["beetles"] as Array).size(), Config.POOP_BEETLES, "快照带着屎壳郎")
