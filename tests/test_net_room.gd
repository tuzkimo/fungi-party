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
