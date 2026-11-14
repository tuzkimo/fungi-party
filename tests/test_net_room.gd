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
	check_eq(room.snapshot()["earned"], {}, "服务器还没结账：快照里的收益是空的")
	room.paid = true
	check_eq(int(room.snapshot()["earned"]["a"]), int(room.payouts()["a"]), "真结过账快照才带收益")


## 「手上留着的钱」和「真写进存档的钱」不能是两回事：
## 有人主动走人（不结账）、或者局不到 5 秒就被收掉时，快照里不许报一笔不存在的币。
func test_payouts_only_after_the_server_pays() -> void:
	var room := NetRoom.create("bomb", ["a"], 7)
	room.over = true
	check(not room.payouts().is_empty(), "模型算得出这一局该给多少")
	check_eq(room.snapshot()["earned"], {}, "没写盘之前不播收益")
	room.paid = true
	check(room.snapshot()["earned"].has("a"), "结过账才播收益")


## ---- 传炸弹搬上服务器之后（第 4 步）----


func test_bomb_room_has_a_model() -> void:
	var room := NetRoom.create("bomb", ["a", "b"], 7)
	check(room.model is BombRound, "传炸弹房带规则模型")
	check_eq((room.model as BombRound).humans, 2, "两个真人都在模型里")


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


## ---- 赛跑搬上服务器之后（第 6 步）----


func test_race_room_has_a_model() -> void:
	var room := NetRoom.create("race", ["a", "b"], 7)
	check(room.model is RaceRound, "赛跑房带规则模型")
	check_eq((room.model as RaceRound).humans, 2, "两个真人都在模型里")
	var game: Dictionary = room.snapshot()["game"]
	check_eq((game["racers"] as Array).size(), Config.SEAT_COUNT, "快照里四个跑者")


## 赛跑的输入是「摇杆 + 点一下」：横移留着，跳跃和冲刺一收到就交给模型。
func test_race_input_is_checked() -> void:
	var room := NetRoom.create("race", ["a"], 7)
	var round: RaceRound = room.model
	check(room.input("a", {"move": -1.0}), "横移收下")
	check_eq(round.racers[0].steer, -1.0, "横移进了模型")
	check_eq(room._inputs[0], {}, "横移不排进 tick 队列（模型已经拿到了）")
	check_eq(room.input("a", {"move": "left"}), false, "字符串不是横移")
	check_eq(room.input("a", {"move": true}), false, "布尔不是横移")
	check_eq(room.input("a", {"jump": 1}), false, "整数不是跳跃")
	check_eq(room.input("a", {"dash": "now"}), false, "字符串不是冲刺")
	check(room.input("a", {"jump": true}), "真布尔能跳")
	check(room.input("a", {"dash": true}), "真布尔能冲")
	check_eq(room.input("zzz", {"move": 0.0}), false, "外人输入丢掉")
	check_eq(room.input("a", {}), false, "什么都没带不算输入")


## 网络来的数字先验有限性：NaN/INF 会让 clampf 原样穿过去，模型里就是永久不死之身。
func test_race_move_must_be_finite() -> void:
	var room := NetRoom.create("race", ["a"], 7)
	var round: RaceRound = room.model
	check_eq(room.input("a", {"move": NAN}), false, "NaN 不是横移")
	check_eq(room.input("a", {"move": INF}), false, "INF 不是横移")
	check(is_finite(round.racers[0].x), "模型里的横坐标还是好数（%f）" % round.racers[0].x)

func test_race_tick_needs_no_press_array() -> void:
	var room := NetRoom.create("race", ["a"], 7)
	for i in 240:
		room.tick(1.0 / 20.0)
	var game: Dictionary = room.snapshot()["game"]
	check(float(game["countdown"]) <= 0.0, "倒数走完了")
	check(float((game["racers"] as Array)[0]["z"]) > 1.0, "服务器上真人也在跑")


## 捉迷藏是第一种「不换场景」的对局：房建在服务器上，场景还是森林。
func test_hide_room() -> void:
	var room := NetRoom.create("hide", ["甲", "乙"])
	check(room != null, "hide 房能建")
	check(room.model is HideRound, "模型是 HideRound")
	check_eq(NetRoom.scene_path("hide"), "", "捉迷藏不换场景")
	check_eq(room.input("甲", {"catch": "yes"}), false, "catch 必须是真布尔")
	room.tick(Config.HIDE_COUNTDOWN + 0.1)
	room.model.feed(1, 0, Vector3.ZERO)
	room.model.feed(0, 0, Vector3(0, 0, 1.0))
	check_eq(room.input("甲", {"catch": true}), true, "合法 catch 被收下")
	check_eq(room.over, true, "捉到就收局")
	check_eq(room.payouts(), {"甲": Config.HIDE_STAKE, "乙": -Config.HIDE_STAKE}, "两边各结一份")


## ---- 扔粑粑搬上服务器之后（第 7 步）----


func test_poop_room_has_no_scene() -> void:
	var room := NetRoom.create("poop", ["a", "b"])
	check(room != null, "扔粑粑的房能建")
	check(room.model is PoopRound, "规则模型是 PoopRound")
	check_eq(NetRoom.scene_path("poop"), "", "扔粑粑留在森林里打，没有自己的场景")


func test_poop_input_is_a_direction() -> void:
	var room := NetRoom.create("poop", ["a", "b"])
	var model := room.model as PoopRound
	model.feed(0, 0, Vector3.ZERO)
	model.ammo[0] = 1
	check_eq(room.input("a", {"dirx": "x", "diry": 0, "dirz": 0}), false, "方向不是数就不收")
	check_eq(room.input("a", {"dirx": INF, "diry": 0.0, "dirz": 0.0}), false, "非有限数不收")
	check_eq(room.input("a", {"dirx": 0.0, "diry": 0.0, "dirz": -1.0}), true, "合法方向收下")
	check_eq((room.snapshot()["game"]["shots"] as Array).size(), 1, "立刻飞出去一发")


func test_poop_tick_moves_the_shot() -> void:
	var room := NetRoom.create("poop", ["a", "b"])
	var model := room.model as PoopRound
	model.feed(0, 0, Vector3.ZERO)
	model.feed(1, 0, Vector3(0.0, 0.0, -8.0))
	model.ammo[0] = 1
	room.input("a", {"dirx": 0.0, "diry": 0.0, "dirz": -1.0})
	room.tick(0.8)
	check_eq((room.snapshot()["game"]["hits"] as Array)[1], 1, "tick 推着粑粑飞过去打中了")


## 一局快照 20 Hz 往八个人那儿发：超过 MAX_PACKET 会被服务器静默丢掉，看起来像服务器停了。
func test_poop_snapshot_fits_in_a_packet() -> void:
	var room := NetRoom.create("poop", ["a", "b"])
	(room.model as PoopRound).anchor(Vector3.ZERO)
	check(
		not NetProtocol.pack(NetProtocol.Msg.SESSION, room.snapshot()).is_empty(),
		"满员的扔粑粑快照塞得进一个包"
	)
