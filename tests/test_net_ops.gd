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
	var r := NetOps.apply(save, "meal", {})
	check(bool(r["ok"]), "还没满就能吃")
	check_eq(int((r["data"] as Dictionary)["stamina"]), 20 + Config.MEAL_STAMINA, "回体力")
	check_eq(int((r["data"] as Dictionary)["coins"]), 100 - Config.MEAL_COINS, "扣饭钱")

	var full := _fresh({"stamina": Config.STAMINA_MAX, "coins": 100})
	check(not bool(NetOps.apply(full, "meal", {})["ok"]), "满体力不再吃")

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


func test_sleep_once_per_world_day() -> void:
	var save := _fresh({"stamina": 12, "meals": 2, "day": 4, "day_time": 0.8})
	var r := NetOps.apply(save, "sleep", {}, {"day": 7})
	check(bool(r["ok"]), "今天没睡过就能睡")
	var next := r["data"] as Dictionary
	check_eq(int(next["stamina"]), Config.STAMINA_MAX, "体力回满")
	check_eq(int(next["meals"]), 0, "份数清零")
	check_eq(int(next["day"]), 7, "日子跟世界时钟走")
	check_eq(int(next["slept_day"]), 7, "记下睡过哪天")
	check(absf(float(next["day_time"]) - 0.8) < 0.001, "天色归世界时钟，睡觉不动它")

	var again := NetOps.apply(next, "sleep", {}, {"day": 7})
	check(not bool(again["ok"]), "同一天不能再睡")
	check_eq(str(again.get("error", "")), "slept", "拒绝原因是 slept")
	check(absf(float((again["data"] as Dictionary)["day_time"]) - 0.8) < 0.001, "被拒也不动天色")

	check(bool(NetOps.apply(next, "sleep", {}, {"day": 8})["ok"]), "到了下一天又能睡")


## 日子是服务器注入的：客户端在 args 里塞一个 day 不算数
func test_sleep_reads_the_world_day_not_the_args() -> void:
	var r := NetOps.apply(_fresh({"day": 4}), "sleep", {"day": 99}, {"day": 7})
	check_eq(int((r["data"] as Dictionary)["day"]), 7, "日子来自世界，不来自客户端")


## 老存档没有 slept_day：读成 -1，第一天就能睡
func test_old_save_can_sleep_on_day_one() -> void:
	var r := NetOps.apply(_fresh(), "sleep", {}, {"day": 1})
	check(bool(r["ok"]), "没睡过就能睡")
	check(bool(NetOps.slept_today(r["data"] as Dictionary, 1)), "slept_today 认得出")
