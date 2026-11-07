extends TestBase

## 服务器 op 的入参全是网络来的：越界、类型不对、名单外的都要拒，且不许改存档。


func _fresh(overrides: Dictionary = {}) -> Dictionary:
	var data := Save.defaults()
	for key in overrides:
		data[key] = overrides[key]
	return data


func test_op_allowlist() -> void:
	check(NetOps.allowed("pull"), "抽卡可发起")
	check(NetOps.allowed("meal"), "吃饭可发起")
	check(not NetOps.allowed("grant"), "名单外拒绝")
	check(not NetOps.allowed(""), "空 op 拒绝")
	var r := NetOps.apply(_fresh(), "grant", {"coins": 99999})
	check(not bool(r["ok"]), "名单外直接失败")
	check_eq(int((r["data"] as Dictionary)["coins"]), 0, "失败时存档不动")


func test_pull_one_spends_price() -> void:
	var r := NetOps.apply(_fresh({"coins": 100}), "pull", {"n": 1})
	check(bool(r["ok"]), "够钱就能抽")
	var save := r["data"] as Dictionary
	check_eq(int(save["coins"]), 100 - Config.GACHA_PRICE_ONE, "扣一抽的钱")
	check_eq((save["owned"] as PackedStringArray).size(), 1, "多了一顶皮肤")
	check(int(save["pity"]) >= 0 and int(save["pity"]) <= 1, "保底计数按规则走")


func test_pull_rejects_bad_count_and_broke() -> void:
	check(not bool(NetOps.apply(_fresh({"coins": 999}), "pull", {"n": 5})["ok"]), "五连不存在")
	# int("10") 会被当成 10：不崩、按十连处理就行，别指望它报错
	check(bool(NetOps.apply(_fresh({"coins": 999}), "pull", {"n": "10"})["ok"]), "字符串参数不炸")
	check(not bool(NetOps.apply(_fresh({"coins": 49}), "pull", {"n": 1})["ok"]), "钱不够不能抽")
	check(not bool(NetOps.apply(_fresh({"coins": 449}), "pull", {"n": 10})["ok"]), "十连钱不够")
	var save := _fresh({"coins": 49})
	NetOps.apply(save, "pull", {"n": 1})
	check_eq(int(save["coins"]), 49, "抽失败不改调用方的字典")


func test_pull_ten_spends_once() -> void:
	var r := NetOps.apply(_fresh({"coins": 450}), "pull", {"n": 10})
	check(bool(r["ok"]), "十连能抽")
	var save := r["data"] as Dictionary
	var pulls := (r["result"] as Dictionary)["pulls"] as Array
	check_eq(pulls.size(), 10, "出十张")
	# 十张里有重复会退币，所以只能断言「花的不超过 450、且挣回来的都在」
	var refunded := 0
	for p in pulls:
		refunded += int(p["refund"])
	check_eq(int(save["coins"]), 450 - Config.GACHA_PRICE_TEN + refunded, "十连只扣一次钱，重复按档退")


func test_meal_and_stamina() -> void:
	var save := _fresh({"stamina": 20, "coins": 100})
	var r := NetOps.apply(save, "meal", {}, {"now": 5000.0})
	check(bool(r["ok"]), "还没满就能吃")
	check_eq(int((r["data"] as Dictionary)["stamina"]), 20 + Config.MEAL_STAMINA, "回体力")
	check_eq(int((r["data"] as Dictionary)["coins"]), 100 - Config.MEAL_COINS, "扣饭钱")

	var full := _fresh({"stamina": Config.STAMINA_MAX, "coins": 100})
	check(not bool(NetOps.apply(full, "meal", {}, {"now": 5000.0})["ok"]), "满体力不再吃")

	check(bool(NetOps.apply(_fresh({"stamina": 50}), "spend_stamina", {"cost": 30})["ok"]), "体力够开局")
	check(not bool(NetOps.apply(_fresh({"stamina": 5}), "spend_stamina", {"cost": 30})["ok"]), "体力不够拒开局")
	check(not bool(NetOps.apply(_fresh({"stamina": 100}), "spend_stamina", {"cost": -5})["ok"]), "负数不能加体力")
	check(not bool(NetOps.apply(_fresh({"stamina": 100}), "spend_stamina", {"cost": 99999})["ok"]), "离谱开销拒绝")


func test_equip_requires_ownership() -> void:
	var owned := SkinCatalog.all()[0].id
	var r := NetOps.apply(_fresh({"owned": PackedStringArray([owned])}), "equip", {"skin": owned})
	check(bool(r["ok"]), "有的皮肤能穿")
	check_eq(str((r["data"] as Dictionary)["equipped"]), owned, "穿上去了")
	check(not bool(NetOps.apply(_fresh(), "equip", {"skin": owned})["ok"]), "没有的皮肤不能穿")
	check(not bool(NetOps.apply(_fresh(), "equip", {"skin": "不存在的皮肤"})["ok"]), "不存在的皮肤不能穿")


func test_set_character_validates_body() -> void:
	var r := NetOps.apply(_fresh(), "set_character", {"id": "seafood"})
	check(bool(r["ok"]), "合法体型")
	check_eq(str((r["data"] as Dictionary)["character"]), "seafood", "换上了")
	check(not bool(NetOps.apply(_fresh(), "set_character", {"id": "外星菇"})["ok"]), "不存在的体型拒绝")


func test_add_coins_bounds() -> void:
	check(bool(NetOps.apply(_fresh(), "add_coins", {"amount": 70})["ok"]), "冠军 70 币照收")
	check(not bool(NetOps.apply(_fresh(), "add_coins", {"amount": -50})["ok"]), "负数不能扣币")
	check(not bool(NetOps.apply(_fresh(), "add_coins", {"amount": 999999})["ok"]), "离谱收益拒绝")
	check_eq(int(NetOps.apply(_fresh({"coins": 10}), "add_coins", {"amount": 20})["data"]["coins"]), 30, "照实加")


func test_day_time_is_not_client_writable() -> void:
	check(not NetOps.allowed("patch_day_time"), "天色归世界时钟，客户端不能再推")


## 睡觉的门槛是冷却，不是世界第几天：两个人在线时各睡各的，谁也卡不住谁。
func test_sleep_has_a_cooldown_not_a_day() -> void:
	var save := _fresh({"stamina": 12, "day": 4, "day_time": 0.8})
	var r := NetOps.apply(save, "sleep", {}, {"now": 1000.0})
	check(bool(r["ok"]), "没睡过就能睡")
	var next := r["data"] as Dictionary
	check_eq(int(next["stamina"]), Config.STAMINA_MAX, "体力回满")
	check_eq(float(next["sleep_at"]), 1000.0, "记下睡的时间")
	check(absf(float(next["day_time"]) - 0.8) < 0.001, "天色归世界时钟，睡觉不动它")

	var again := NetOps.apply(next, "sleep", {}, {"now": 1000.0 + Config.SLEEP_COOLDOWN_SECONDS - 1.0})
	check(not bool(again["ok"]), "冷却没到不能再睡")
	check_eq(str(again.get("error", "")), "cooldown", "拒绝原因是 cooldown")
	check_eq(int((again["data"] as Dictionary)["stamina"]), Config.STAMINA_MAX, "被拒不改体力")

	check(
		bool(NetOps.apply(next, "sleep", {}, {"now": 1000.0 + Config.SLEEP_COOLDOWN_SECONDS})["ok"]),
		"冷却到点又能睡"
	)


## 时间也是服务器注入的：客户端在 args 里塞 sleep_at / now 都不算数
func test_sleep_reads_the_server_clock_not_the_args() -> void:
	var r := NetOps.apply(
		_fresh({"sleep_at": 5000.0}), "sleep", {"now": 9999.0, "sleep_at": 1.0}, {"now": 1000.0}
	)
	check(not bool(r["ok"]), "服务器说还在冷却就是冷却")
	check_eq(str(r.get("error", "")), "cooldown", "不给客户端绕过去的机会")


## 没有服务器时间就不改存档：宁可拒，也不拿 0 当「可以睡」
func test_sleep_without_server_clock_is_refused() -> void:
	var r := NetOps.apply(_fresh(), "sleep", {}, {})
	check(not bool(r["ok"]), "没有 now 就拒")
	check_eq(str(r.get("error", "")), "clock", "拒绝原因是 clock")


## 老存档没有 sleep_at：读成 0 = 没睡过，立刻能睡
func test_old_save_can_sleep_right_away() -> void:
	var r := NetOps.apply(_fresh(), "sleep", {}, {"now": 1000.0})
	check(bool(r["ok"]), "没睡过就能睡")


## 吃饭同样只认冷却 + 钱 + 还饱不饱（不再有「一天三份」）
func test_meal_op() -> void:
	var save := _fresh({"stamina": 40, "coins": 100})
	var r := NetOps.apply(save, "meal", {}, {"now": 2000.0})
	check(bool(r["ok"]), "有钱就能吃")
	var next := r["data"] as Dictionary
	check_eq([int(next["stamina"]), int(next["coins"])], [65, 80], "回 25 体力扣 20 币")
	check_eq(float(next["meal_at"]), 2000.0, "记下吃的时间")
	var again := NetOps.apply(next, "meal", {}, {"now": 2000.0 + 1.0})
	check_eq(str(again.get("error", "")), "cooldown", "刚吃完要等")
	check_eq(int((again["data"] as Dictionary)["coins"]), 80, "被拒不扣钱")
	check(bool(NetOps.apply(next, "meal", {}, {"now": 2000.0 + Config.MEAL_COOLDOWN_SECONDS})["ok"]), "到点又能吃")
