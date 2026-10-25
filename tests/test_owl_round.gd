extends TestBase

## OwlRound 纯模型：投喂序列、张嘴判定、关卡推进、名次与币。
## 判定的核心只有一句：东西抵达嘴边那一刻嘴张着吗？

const SEAT := OwlRound.PLAYER


func _round(seed_value := 1) -> OwlRound:
	return OwlRound.new(seed_value)


## 清掉四个座位的自动排程，让测试自己摆一颗。
func _freeze(r: OwlRound) -> void:
	for m in r.mouths:
		m.wait = 0.0
		m.flying = 0.0
		m.lead = -1.0
		m.poop = false


func _drop(r: OwlRound, seat: int, poop: bool, fall := 0.5) -> void:
	var m: OwlRound.Mouth = r.mouths[seat]
	m.poop = poop
	m.fall = fall
	m.flying = fall
	m.wait = 0.0


func _presses(player: bool) -> Array:
	return [player, false, false, false]


func _run(r: OwlRound, seconds: float, player := false) -> void:
	var step := 1.0 / 60.0
	for i in int(round(seconds / step)):
		r.tick(step, _presses(player))


func _count(r: OwlRound, kind: String, seat: int) -> int:
	var found := 0
	for e in r.events:
		if String(e["kind"]) == kind and int(e["seat"]) == seat:
			found += 1
	return found


func test_level_starts() -> void:
	var r := _round()
	check_eq(r.mouths.size(), OwlRound.SEATS, "四张嘴")
	check_eq(r.time_left, Config.OWL_SECONDS[0], "第一关时长")
	check_eq(r.level, 0, "从第一关开始")
	check(not r.level_over, "开局没结束")
	for m in r.mouths:
		check_eq(m.score, 0, "开局零分")
		check(not m.out, "开局都没出局")


func test_candy_eaten_when_open() -> void:
	var r := _round()
	_freeze(r)
	_drop(r, SEAT, false, 0.5)
	r.events.clear()
	_run(r, 0.5, true)
	check_eq(r.mouths[SEAT].score, 1, "张嘴吃到糖")
	check(not r.mouths[SEAT].out, "吃糖不出局")
	check_eq(_count(r, "eat", SEAT), 1, "记一条 eat 事件")


func test_candy_missed_when_closed() -> void:
	var r := _round()
	_freeze(r)
	_drop(r, SEAT, false, 0.5)
	r.events.clear()
	_run(r, 0.6)
	check_eq(r.mouths[SEAT].score, 0, "闭嘴接不到糖")
	check(not r.mouths[SEAT].out, "闭嘴不会出局")
	check_eq(_count(r, "miss", SEAT), 1, "记一条 miss 事件")


func test_poop_kills_open_mouth() -> void:
	var r := _round()
	_freeze(r)
	_drop(r, SEAT, true, 0.5)
	r.events.clear()
	_run(r, 0.5, true)
	check(r.mouths[SEAT].out, "张嘴吃到屎就出局")
	check_eq(r.mouths[SEAT].score, 0, "屎不加分")
	check_eq(_count(r, "poop", SEAT), 1, "记一条 poop 事件")


func test_poop_safe_when_closed() -> void:
	var r := _round()
	_freeze(r)
	_drop(r, SEAT, true, 0.5)
	r.events.clear()
	_run(r, 0.6)
	check(not r.mouths[SEAT].out, "闭嘴时屎是安全的")
	check_eq(r.mouths[SEAT].score, 0, "闭嘴没有分")


func test_out_mouth_cannot_score() -> void:
	var r := _round()
	_freeze(r)
	_drop(r, SEAT, true, 0.2)
	_run(r, 0.2, true)
	check(r.mouths[SEAT].out, "先让他出局")
	var before: int = r.mouths[SEAT].score
	_freeze(r)
	_drop(r, SEAT, false, 0.5)
	_run(r, 1.0, true)
	check_eq(r.mouths[SEAT].score, before, "出局后按着也吃不到糖")


func test_poop_ends_lane() -> void:
	var r := _round()
	_freeze(r)
	_drop(r, SEAT, true, 0.2)
	_run(r, 0.2, true)
	check(r.mouths[SEAT].out, "先让他出局")
	_run(r, 5.0, true)
	check_eq(r.mouths[SEAT].flying, 0.0, "出局后线上不再有东西")
	check_eq(r.mouths[SEAT].wait, 0.0, "出局后不再排下一颗")


func test_level_advance_keeps_scores() -> void:
	var r := _round()
	_freeze(r)
	_drop(r, SEAT, false, 0.2)
	_run(r, 0.2, true)
	check_eq(r.mouths[SEAT].score, 1, "先吃一颗")
	r.time_left = 0.01
	r.tick(0.02, _presses(false))
	check(r.level_over, "时间到本关结束")
	r.start_level(1)
	check_eq(r.time_left, Config.OWL_SECONDS[1], "进第二关")
	check_eq(r.level, 1, "关卡号推进")
	check_eq(r.mouths[SEAT].score, 1, "分数跨关保留")
	check(not r.level_over, "新一关重新开始")


## 出局只在本关有效：下一关四个人都得回来，而且还能继续得分。
func test_out_resets_next_level() -> void:
	var r := _round()
	_freeze(r)
	_drop(r, SEAT, true, 0.2)
	_run(r, 0.2, true)
	check(r.mouths[SEAT].out, "第一关吃屎出局")
	r.start_level(1)
	check(not r.mouths[SEAT].out, "新一关复活")
	_freeze(r)
	_drop(r, SEAT, false, 0.2)
	_run(r, 0.2, true)
	check_eq(r.mouths[SEAT].score, 1, "复活后还能接着吃糖")


func test_level_over_stops_tick() -> void:
	var r := _round()
	r.level_over = true
	var before := r.time_left
	_run(r, 5.0, true)
	check_eq(r.time_left, before, "结束后时间不再走")
	check_eq(r.mouths[SEAT].score, 0, "结束后不再计分")


func test_fast_forward_keeps_arrivals_exact() -> void:
	var r := _round()
	_freeze(r)
	_drop(r, SEAT, false, 0.5)
	r.events.clear()
	r.tick(Config.OWL_FAST_FORWARD, _presses(true))
	check_eq(r.mouths[SEAT].score, 1, "一次大 delta 只结算一颗")
	check_eq(_count(r, "eat", SEAT), 1, "只有一条 eat 事件")
	var expected := Config.OWL_SECONDS[0] - Config.OWL_FAST_FORWARD
	check(is_equal_approx(r.time_left, expected), "时间按 delta 扣完")


func test_big_delta_does_not_double_count() -> void:
	var r := _round()
	_freeze(r)
	_drop(r, SEAT, false, 0.05)
	r.events.clear()
	r.tick(0.5, _presses(true))
	check_eq(r.mouths[SEAT].score, 1, "一颗糖只算一分")
	check_eq(r.mouths[SEAT].flying, 0.0, "那颗糖已经被吃掉")
	var expected := Config.OWL_SECONDS[0] - 0.5
	check(is_equal_approx(r.time_left, expected), "时间按 delta 扣")


func test_npcs_score_over_a_level() -> void:
	var r := _round(7)
	_run(r, Config.OWL_SECONDS[0])
	check_eq(r.mouths[SEAT].score, 0, "玩家从不按就是零分")
	var npc: int = r.mouths[1].score + r.mouths[2].score + r.mouths[3].score
	check(npc > 0, "人机会自己吃到糖")


## 一条线一关投喂多少次：加长关卡 + 加密节奏后，第一关就该有 15 次以上。
func test_density_rises_with_levels() -> void:
	var per_lane := []
	for lv in Config.OWL_SECONDS.size():
		var r := _round(11 + lv)
		r.start_level(lv)
		r.events.clear()
		_run(r, Config.OWL_SECONDS[lv])
		var mine := 0
		for e in r.events:
			if int(e["seat"]) == SEAT:
				mine += 1
		per_lane.append(mine)
	check(per_lane[0] >= 14, "第一关一条线至少投喂 14 次（加长前只有 10 次左右）")
	check(per_lane[2] > per_lane[0] * 1.3, "第三关明显比第一关密")


## 节奏要有快慢：连珠的每一段都必须严格短于平时的间隔，否则玩家数得出拍子。
func test_burst_is_faster_than_normal() -> void:
	for i in Config.OWL_GAP.size():
		check(Config.OWL_BURST_GAP[i].y < Config.OWL_GAP[i].x, "连珠比平时短")
		check(Config.OWL_BURST_CHANCE[i] > 0.0 and Config.OWL_BURST_CHANCE[i] < 1.0, "连珠是随机出现的")


func test_seed_reproduces_schedule() -> void:
	var a := _round(42)
	var b := _round(42)
	_run(a, 10.0)
	_run(b, 10.0)
	check_eq(a.events, b.events, "同种子排出同一串事件")
	check(not a.events.is_empty(), "十秒里确实发生了事")


func test_ranking_by_score_ties_by_seat() -> void:
	check_eq(OwlRound.ranking([5, 7, 7, 2]), [1, 2, 0, 3], "分高的在前，同分按座位序")
	check_eq(OwlRound.ranking([3, 3, 3, 3]), [0, 1, 2, 3], "全平局时玩家在前")
	check_eq(OwlRound.ranking([0, 0, 0, 9]), [3, 0, 1, 2], "一个人独高")


func test_coins_by_rank() -> void:
	check_eq(OwlRound.coins(0), 70, "第一名 70 币")
	check_eq(OwlRound.coins(1), 50, "第二名 50 币")
	check_eq(OwlRound.coins(2), 35, "第三名 35 币")
	check_eq(OwlRound.coins(3), 20, "最后一名 20 币")
	check_eq(OwlRound.coins(9), 20, "名次越界夹到最后")


func test_levels_get_harder() -> void:
	for i in range(1, Config.OWL_SECONDS.size()):
		check(Config.OWL_SECONDS[i] > Config.OWL_SECONDS[i - 1], "一关比一关长")
		check(Config.OWL_FALL[i] < Config.OWL_FALL[i - 1], "下落越来越快")
		check(Config.OWL_POOP[i] > Config.OWL_POOP[i - 1], "屎越来越多")
		check(Config.OWL_GAP[i].x < Config.OWL_GAP[i - 1].x, "投喂越来越密")


func test_npc_personalities() -> void:
	check(Config.OWL_NPC_EAT[1] > Config.OWL_NPC_EAT[0], "贪的敢吃糖")
	check(Config.OWL_NPC_EAT[0] > Config.OWL_NPC_EAT[2], "胆小的更常漏糖")
	check(Config.OWL_NPC_GREED[1] > Config.OWL_NPC_GREED[0], "贪的更容易吃屎")
	check(Config.OWL_NPC_GREED[0] > Config.OWL_NPC_GREED[2], "胆小的最不会吃屎")


## 双人：1 号座也改由输入驱动，不再走人机的「提前量」那套。
func test_second_human_is_driven_by_input() -> void:
	var r := _round(3)
	r.humans = 2
	_freeze(r)
	_drop(r, 1, false, 0.5)
	r.events.clear()
	var step := 1.0 / 60.0
	for i in 30:
		r.tick(step, [false, true, false, false])
	check_eq(r.mouths[1].score, 1, "1 号座按着就吃到糖")

func test_players_out_needs_everyone() -> void:
	var r := _round(4)
	r.humans = 2
	check(not r.players_out(), "开局都没出局")
	r.mouths[0].out = true
	check(not r.players_out(), "一个人出局还算在玩")
	r.mouths[1].out = true
	check(r.players_out(), "两个人都出局才快进")
