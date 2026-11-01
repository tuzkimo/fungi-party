extends TestBase

## 邀请配对与「同时只开一间房」的规矩。存档由测试自己喂，所以这里不需要服务器和网络。

var ONLINE := PackedStringArray(["甲", "乙", "丙"])
const NOW := 1000.0


func _lobby(saves: Dictionary) -> NetLobby:
	return NetLobby.new(
		func(name: String) -> Dictionary:
			return (saves.get(name, {}) as Dictionary).duplicate(true),
		func(name: String, data: Dictionary) -> void:
			saves[name] = data
	)


func _fresh() -> Dictionary:
	return {
		"甲": {"stamina": 100, "coins": 0},
		"乙": {"stamina": 100, "coins": 0},
		"丙": {"stamina": 100, "coins": 0},
	}


func test_cost_matches_config() -> void:
	check_eq(NetLobby.cost_of("classroom"), Config.STAMINA_COST_CLASSROOM, "教室 12")
	check_eq(NetLobby.cost_of("bomb"), Config.STAMINA_COST_BOMB, "传炸弹 25")
	check_eq(NetLobby.cost_of("owl"), Config.STAMINA_COST_OWL, "猫头鹰 30")
	check_eq(NetLobby.cost_of("race"), Config.STAMINA_COST_RACE, "赛跑 20")
	check_eq(NetLobby.cost_of("nope"), 0, "不认识的 kind 没有成本")
	for kind in NetRoom.KINDS:
		check(NetLobby.cost_of(kind) > 0, "%s 有成本" % kind)


func test_invite_rejects() -> void:
	var lobby := _lobby(_fresh())
	check_eq(str(lobby.invite("甲", "乙", "nope", ONLINE, NOW)["error"]), "kind", "不认识的 kind")
	check_eq(str(lobby.invite("甲", "甲", "race", ONLINE, NOW)["error"]), "self", "不能邀请自己")
	check_eq(str(lobby.invite("甲", "丁", "race", ONLINE, NOW)["error"]), "offline", "对方不在线")
	var tired := {"甲": {"stamina": 5}, "乙": {"stamina": 100}}
	check_eq(str(_lobby(tired).invite("甲", "乙", "race", ONLINE, NOW)["error"]), "stamina", "自己体力不够")
	check_eq(lobby.pending.size(), 0, "被拒的邀请不留下任何东西")


func test_invite_show_up_for_the_invitee() -> void:
	var lobby := _lobby(_fresh())
	check(lobby.invite("甲", "乙", "classroom", ONLINE, NOW)["ok"], "邀请成功")
	var got := lobby.invites_for("乙", ONLINE, NOW)
	check_eq(got.size(), 1, "被邀请人看到一条")
	check_eq(str(got[0]["from"]), "甲", "知道是谁邀请的")
	check_eq(str(got[0]["kind"]), "classroom", "知道玩哪一款")
	check_eq(lobby.invites_for("丙", ONLINE, NOW).size(), 0, "别人看不到这条邀请")
	check_eq((_fresh() as Dictionary).size(), 3, "查邀请不改存档")


func test_invite_expires() -> void:
	var lobby := _lobby(_fresh())
	lobby.invite("甲", "乙", "owl", ONLINE, NOW)
	var late := NOW + Config.NET_INVITE_SECONDS + 1.0
	check_eq(lobby.invites_for("乙", ONLINE, late).size(), 0, "过期的邀请不再显示")
	check_eq(lobby.pending.size(), 0, "过期的邀请被清掉")
	lobby.invite("甲", "乙", "owl", ONLINE, NOW)
	check_eq(str(lobby.answer("甲", "乙", "owl", true, ONLINE, late)["error"]), "expired", "过期了不能接受")


func test_answer_without_invite() -> void:
	var lobby := _lobby(_fresh())
	check_eq(str(lobby.answer("甲", "乙", "owl", true, ONLINE, NOW)["error"]), "invite", "没有邀请不能接受")
	lobby.invite("甲", "乙", "owl", ONLINE, NOW)
	check_eq(str(lobby.answer("丙", "乙", "owl", true, ONLINE, NOW)["error"]), "invite", "冒充别人回答")
	check_eq(str(lobby.answer("甲", "乙", "race", true, ONLINE, NOW)["error"]), "invite", "换一款游戏回答")


func test_answer_declined_costs_nothing() -> void:
	var saves := _fresh()
	var lobby := _lobby(saves)
	lobby.invite("甲", "乙", "bomb", ONLINE, NOW)
	var r := lobby.answer("甲", "乙", "bomb", false, ONLINE, NOW)
	check(bool(r["ok"]), "拒绝也是一次合法回答")
	check_eq(bool(r["result"]["accepted"]), false, "回执说没成局")
	check(lobby.room == null, "拒绝不成局")
	check_eq(saves.duplicate(true), _fresh(), "拒绝一分体力不扣")
	check_eq(lobby.pending.size(), 0, "回答过就没有待处理邀请了")


func test_answer_starts_and_charges_both() -> void:
	var saves := _fresh()
	var lobby := _lobby(saves)
	lobby.invite("甲", "乙", "owl", ONLINE, NOW)
	var r := lobby.answer("甲", "乙", "owl", true, ONLINE, NOW)
	check(bool(r["ok"]), "接受成局")
	check(lobby.room != null, "有一间房了")
	check_eq(lobby.room.kind, "owl", "房是猫头鹰")
	check_eq(lobby.room.seat_of("甲"), 0, "发起的坐 0 号")
	check_eq(lobby.room.seat_of("乙"), 1, "接受的坐 1 号")
	var cost := Config.STAMINA_COST_OWL
	var out := r["saves"] as Dictionary
	check_eq(int((out["甲"] as Dictionary)["stamina"]), 100 - cost, "邀请方扣自己的")
	check_eq(int((out["乙"] as Dictionary)["stamina"]), 100 - cost, "被邀请方扣自己的")
	check_eq(int(saves["甲"]["stamina"]), 100, "调用方那份存档不原地改")
	check_eq(lobby.invites_for("乙", ONLINE, NOW).size(), 0, "进了房不再收邀请")


func test_answer_needs_stamina_at_the_moment() -> void:
	var saves := _fresh()
	var lobby := _lobby(saves)
	lobby.invite("甲", "乙", "owl", ONLINE, NOW)
	saves["乙"]["stamina"] = 3
	check_eq(str(lobby.answer("甲", "乙", "owl", true, ONLINE, NOW)["error"]), "stamina", "接受时不够就进不去")
	check(lobby.room == null, "不成局")
	check_eq(int(saves["甲"]["stamina"]), 100, "没成局不扣体力")
	saves["乙"]["stamina"] = 100
	lobby.invite("甲", "乙", "owl", ONLINE, NOW)
	saves["甲"]["stamina"] = 1
	check_eq(str(lobby.answer("甲", "乙", "owl", true, ONLINE, NOW)["error"]), "stamina", "邀请方中间花掉了也进不去")
	check(lobby.room == null, "不成局")


func test_answer_inviter_gone() -> void:
	var lobby := _lobby(_fresh())
	lobby.invite("甲", "乙", "race", ONLINE, NOW)
	check_eq(str(lobby.answer("甲", "乙", "race", true, PackedStringArray(["乙"]), NOW)["error"]), "offline", "邀请方掉线不能成局")
	check(lobby.room == null, "不成局")


func test_one_room_at_a_time() -> void:
	var saves := _fresh()
	var lobby := _lobby(saves)
	lobby.invite("甲", "乙", "classroom", ONLINE, NOW)
	lobby.answer("甲", "乙", "classroom", true, ONLINE, NOW)
	check_eq(str(lobby.invite("甲", "丙", "classroom", ONLINE, NOW)["error"]), "busy", "房里不能再邀请")
	check_eq(str(lobby.invite("丙", "甲", "classroom", ONLINE, NOW)["error"]), "busy", "房里的人也不再被邀请")
	check_eq(lobby.invites_for("甲", ONLINE, NOW).size(), 0, "在房里的人看不到邀请")


## 成局时两个人手上的其它邀请一起作废：房都开了，那条邀请已经没意义了。
func test_formation_voids_other_invites() -> void:
	var lobby := _lobby(_fresh())
	lobby.invite("丙", "甲", "classroom", ONLINE, NOW)
	lobby.invite("甲", "乙", "classroom", ONLINE, NOW)
	lobby.answer("甲", "乙", "classroom", true, ONLINE, NOW)
	check_eq(lobby.pending.size(), 0, "甲进了房，丙发给他的那条邀请也清了")


func test_leaving_clears_invites() -> void:
	var lobby := _lobby(_fresh())
	lobby.invite("甲", "乙", "race", ONLINE, NOW)
	lobby.invite("乙", "甲", "race", ONLINE, NOW)
	lobby.leave("甲")
	check_eq(lobby.pending.size(), 0, "掉线的人发出的和收到的邀请都作废")


func test_leaving_ends_the_room() -> void:
	var lobby := _lobby(_fresh())
	lobby.invite("甲", "乙", "bomb", ONLINE, NOW)
	lobby.answer("甲", "乙", "bomb", true, ONLINE, NOW)
	lobby.leave("乙")
	check(lobby.room != null, "房里的人掉线房还在（等人机顶上）")
	check_eq(lobby.room.over, true, "但这一局已经收了")


func test_room_clock_and_hard_stop() -> void:
	var lobby := _lobby(_fresh())
	lobby.invite("甲", "乙", "classroom", ONLINE, NOW)
	lobby.answer("甲", "乙", "classroom", true, ONLINE, NOW)
	lobby.tick(0.5)
	check(absf(lobby.room.elapsed - 0.5) < 0.0001, "房里的时钟在走")
	lobby.tick(Config.NET_ROOM_MAX_SECONDS)
	check_eq(lobby.room.over, true, "没人结算也会到点收房")


func test_scene_path_for_every_kind() -> void:
	for kind in NetRoom.KINDS:
		check(NetRoom.scene_path(kind) != "", "%s 有场景" % kind)
	check_eq(NetRoom.scene_path("nope"), "", "不认识的 kind 没有场景")
	check_eq(NetRoom.scene_path("classroom"), Config.CLASSROOM_PATH, "教室场景路径")


## 教室这一局结束就照口数结账，落盘一次（服务器调 NetLobby.tick）。
func test_round_settles_the_coins_once() -> void:
	var saves := _fresh()
	var lobby := _lobby(saves)
	lobby.invite("甲", "乙", "classroom", ONLINE, NOW)
	lobby.answer("甲", "乙", "classroom", true, ONLINE, NOW)
	var round: ClassroomRound = lobby.room.model
	round.eat.seats[0].bites = 3
	round.eat.winner = 0
	lobby.leave("乙")
	lobby.tick(0.1)
	var earned := Config.COIN_BASE + Config.COIN_PER_BITE * 3 + Config.COIN_WIN_BONUS
	check_eq(int(saves["甲"]["coins"]), earned, "走了也按吃到的口数结账")
	lobby.tick(0.1)
	check_eq(int(saves["甲"]["coins"]), earned, "结账只结一次")
	check(lobby.settled, "记下已经结过账了")


## 不是教室（还没搬上服务器）的局没有模型，不收钱也不算账。
func test_unmodelled_room_settles_nothing() -> void:
	var saves := _fresh()
	var lobby := _lobby(saves)
	lobby.invite("甲", "乙", "race", ONLINE, NOW)
	lobby.answer("甲", "乙", "race", true, ONLINE, NOW)
	lobby.tick(0.1)
	check(lobby.room != null, "房还在")
	check_eq(int(saves["甲"]["coins"]), 0, "没搬的游戏不结账")
