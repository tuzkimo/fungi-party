extends TestBase

func test_humans_from_zero_then_npcs() -> void:
	var room := NetRoom.create("classroom", ["a", "b"])
	check(room != null, "两个真人的教室房能建")
	check_eq(room.seats.size(), Config.SEAT_COUNT, "座位数满 4")
	check_eq(room.seats[0]["account"], "a", "0 号座位是第一个真人")
	check_eq(room.seats[1]["account"], "b", "1 号座位是第二个真人")
	check_eq(room.seats[0]["npc"], false, "真人座位不是人机")
	for i in range(2, Config.SEAT_COUNT):
		check_eq(room.seats[i]["npc"], true, "%d 号座位补人机" % i)
		check_eq(room.seats[i]["account"], "", "%d 号人机没有账号" % i)


func test_single_human_gets_three_npcs() -> void:
	var room := NetRoom.create("bomb", ["solo"])
	check_eq(room.seats[0]["account"], "solo", "单人开局坐 0 号")
	var npcs := 0
	for s in room.seats:
		if s["npc"]:
			npcs += 1
	check_eq(npcs, 3, "单人局补 3 个人机")


func test_full_room_has_no_npcs() -> void:
	var humans: Array[String] = ["a", "b", "c", "d"]
	var room := NetRoom.create("race", humans)
	check(room != null, "满员 4 人能建")
	for i in Config.SEAT_COUNT:
		check_eq(room.seats[i]["npc"], false, "满员时 %d 号位不是人机" % i)


func test_reject_bad_input() -> void:
	check(NetRoom.create("classroom", []) == null, "没人不能建")
	check(NetRoom.create("nope", ["a"]) == null, "不认识的 kind 不能建")
	check(NetRoom.create("owl", ["a", "b", "c", "d", "e"]) == null, "超过 4 人不能建")
	check(NetRoom.create("owl", ["a", "a"]) == null, "同一个账号不能坐两个位")
	check(NetRoom.create("owl", [""]) == null, "空账号不能建")


func test_seat_of() -> void:
	var room := NetRoom.create("owl", ["a", "b"])
	check_eq(room.seat_of("b"), 1, "找到真人座位号")
	check_eq(room.seat_of("zzz"), -1, "不在局里的账号找不到")
	check_eq(room.seat_of(""), -1, "人机座位不算账号")


func test_input_from_outsider_dropped() -> void:
	var room := NetRoom.create("classroom", ["a"])
	check_eq(room.input("zzz", {"press": true}), false, "外人输入丢掉")
	check_eq(room.input("a", {"press": true}), true, "本局的人输入收下")


func test_tick_advances_clock() -> void:
	var room := NetRoom.create("classroom", ["a"])
	room.tick(0.5)
	room.tick(0.5)
	check(absf(room.elapsed - 1.0) < 0.0001, "时钟按 tick 累加")
	check_eq(room.over, false, "还没模型就没法结束")


func test_snapshot_fields() -> void:
	var room := NetRoom.create("classroom", ["a"])
	var snap := room.snapshot()
	for key in ["kind", "seats", "elapsed", "over", "winner"]:
		check(snap.has(key), "快照带 %s" % key)
	check_eq(snap["kind"], "classroom", "快照带 kind")
	check_eq(snap["seats"].size(), Config.SEAT_COUNT, "快照座位数对得上")
	check_eq(snap["over"], false, "开局没结束")
	check_eq(snap["winner"], -1, "开局没赢家")


## ---- 教室搬上服务器之后（第 3 步）----


func test_classroom_room_has_a_model() -> void:
	var room := NetRoom.create("classroom", ["a"], 7)
	check(room.model is ClassroomRound, "教室房带规则模型")
	check_eq(float(room.snapshot()["game"].get("countdown", -1.0)), ClassroomRound.COUNTDOWN, "快照里有局内状态")
	check(NetRoom.create("race", ["a"], 7).model == null, "还没搬上服务器的游戏没有模型")


func test_room_tick_drives_the_model() -> void:
	var room := NetRoom.create("classroom", ["a"], 7)
	room.input("a", {"press": true})
	for i in 200:
		room.tick(1.0 / 60.0)
	var game: Dictionary = room.snapshot()["game"]
	check(float(game["countdown"]) <= 0.0, "3 秒倒数走完")
	check(float(game["time_left"]) < Config.ROUND_SECONDS, "回合时间在走")
	check_eq((game["seats"] as Array).size(), Config.SEAT_COUNT, "四个座位都在局里")


func test_input_keeps_only_press() -> void:
	var room := NetRoom.create("classroom", ["a"], 7)
	check(room.input("a", {"press": true, "junk": "x".repeat(100)}), "本局的人能按")
	check_eq(room._inputs[0].keys(), ["press"], "客户端多塞的字段一个都不留")


func test_payouts_only_after_the_round() -> void:
	var room := NetRoom.create("classroom", ["a"], 7)
	check(room.payouts().is_empty(), "没结束不结账")
	var round: ClassroomRound = room.model
	round.eat.seats[0].bites = 2
	round.eat.winner = 0
	room.over = true
	check_eq(
		int(room.payouts()["a"]),
		Config.COIN_BASE + Config.COIN_PER_BITE * 2 + Config.COIN_WIN_BONUS,
		"结束之后按口数结账"
	)
	check_eq(int(room.snapshot()["earned"]["a"]), int(room.payouts()["a"]), "快照里带着这一局的收益")


## ---- 传炸弹搬上服务器之后（第 4 步）----


func test_bomb_room_has_a_model() -> void:
	var room := NetRoom.create("bomb", ["a", "b"], 7)
	check(room.model is BombRound, "传炸弹房带规则模型")
	check_eq((room.model as BombRound).humans, 2, "两个真人都在模型里")
	check(NetRoom.create("race", ["a"], 7).model == null, "还没搬上服务器的游戏没有模型")


func test_bomb_throw_input_goes_straight_to_the_model() -> void:
	var room := NetRoom.create("bomb", ["a"], 7)
	var round: BombRound = room.model
	round.holder = 0
	round.lock = 0.0
	round.flight = 0.0
	check(room.input("a", {"throw": -1}), "本局的人能扔")
	check_eq(round.thrower, 0, "服务器立刻记下是谁扔的")
	check_eq(round.target, 1, "扔到自己左手边那一位")


func test_bomb_ignores_a_throw_from_an_outsider() -> void:
	var room := NetRoom.create("bomb", ["a"], 7)
	var round: BombRound = room.model
	round.holder = 0
	round.lock = 0.0
	round.flight = 0.0
	check_eq(room.input("zzz", {"throw": -1}), false, "外人的投掷丢掉")
	check_eq(round.holder, 0, "炸弹还在原位")


func test_bomb_tick_does_not_need_a_press_array() -> void:
	var room := NetRoom.create("bomb", ["a"], 7)
	var before: float = (room.model as BombRound).fuse
	for i in 10:
		room.tick(1.0 / 20.0)
	check((room.model as BombRound).fuse < before, "时钟在推引信")


func test_bomb_payouts_after_the_round() -> void:
	var room := NetRoom.create("bomb", ["a"], 7)
	var round: BombRound = room.model
	round.alive = [0]
	round.death_order = [1, 2, 3]
	round.over = true
	room.tick(1.0 / 20.0)
	check(room.over, "模型结束了房间也结束")
	check_eq(int(room.payouts()["a"]), int(Config.BOMB_RANK_COINS[0]), "活到最后按第一名结账")


## ---- 评审挑出来的输入校验（第 4 步修）----


func test_bomb_throw_input_is_checked() -> void:
	var room := NetRoom.create("bomb", ["a"], 7)
	var round: BombRound = room.model
	round.holder = 0
	round.lock = 0.0
	round.flight = 0.0
	check_eq(room.input("a", {"throw": {}}), false, "不是数字的投掷丢掉")
	check_eq(room.input("a", {"throw": "1"}), false, "字符串也不算方向")
	check_eq(room.input("a", {"throw": 0}), false, "0 不是合法方向")
	check_eq(round.holder, 0, "炸弹没动")
	check(room.input("a", {"throw": 1.0}), "浮点数也是数字")


## ---- 猫头鹰搬上服务器之后（第 5 步）----


func test_owl_room_has_a_model() -> void:
	var room := NetRoom.create("owl", ["a", "b"], 7)
	check(room.model is OwlRound, "猫头鹰房带规则模型")
	check_eq((room.model as OwlRound).humans, 2, "两个真人都在模型里")


## 三关的推进在模型里：房间推一次就该看见关卡、时钟和四个座位。
func test_owl_room_drives_the_whole_match() -> void:
	var room := NetRoom.create("owl", ["a"], 7)
	check(room.input("a", {"press": true}), "本局的人能按")
	check_eq(room._inputs[0].keys(), ["press"], "客户端多塞的字段一个都不留")
	room.tick(1.0 / 20.0)
	var game: Dictionary = room.snapshot()["game"]
	check_eq(int(game["level"]), 0, "第一关")
	check(float(game["countdown"]) < Config.OWL_COUNTDOWN, "开场倒数在走")
	for i in 80:
		room.tick(1.0 / 20.0)
	game = room.snapshot()["game"]
	check(float(game["time_left"]) < Config.OWL_SECONDS[0], "倒数走完钟才走")
	check_eq((game["seats"] as Array).size(), OwlRound.SEATS, "四个座位都在局里")


## press 也是网络来的：类型不对就当没按，别让服务器每收一条坏包打一条运行时错误。
func test_press_input_is_checked() -> void:
	var room := NetRoom.create("owl", ["a"], 7)
	check_eq(room.input("a", {"press": "yes"}), false, "字符串不是按着")
	check_eq(room.input("a", {"press": {}}), false, "字典不是按着")
	check_eq(room.input("a", {"press": null}), false, "null 不是按着")
	check_eq(room._inputs[0], {}, "被拒的输入一个字都不留")
	check(room.input("a", {"press": true}), "真布尔收下")
	check_eq(room._inputs[0], {"press": true}, "只留 press")


func test_owl_payouts_after_the_match() -> void:
	var room := NetRoom.create("owl", ["a"], 7)
	var round: OwlRound = room.model
	round.mouths[0].score = 9
	round.mouths[1].score = 7
	round.match_over = true
	room.tick(1.0 / 20.0)
	check(room.over, "模型结束了房间也结束")
	check_eq(room.winner, 0, "分数最高的那个是赢家")
	check_eq(int(room.payouts()["a"]), OwlRound.coins(0), "按名次结账")
