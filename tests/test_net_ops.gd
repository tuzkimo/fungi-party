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
	check(NetOps.allowed("sleep"), "睡觉可发起")
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


func test_spend_stamina() -> void:
	check(bool(NetOps.apply(_fresh({"stamina": 50}), "spend_stamina", {"cost": 30})["ok"]), "体力够开局")
	check(not bool(NetOps.apply(_fresh({"stamina": 5}), "spend_stamina", {"cost": 30})["ok"]), "体力不够拒开局")
	check(not bool(NetOps.apply(_fresh({"stamina": 100}), "spend_stamina", {"cost": -5})["ok"]), "负数不能加体力")
	check(not bool(NetOps.apply(_fresh({"stamina": 100}), "spend_stamina", {"cost": 99999})["ok"]), "离谱开销拒绝")


## 吃饭 / 睡觉：都没有间隔（钱和肚子是唯一的限制），睡觉直接回满
func test_meal_and_sleep() -> void:
	var save := _fresh({"stamina": 20, "coins": 100})
	var r := NetOps.apply(save, "meal", {})
	check(bool(r["ok"]), "有钱就能吃")
	check_eq([int((r["data"] as Dictionary)["stamina"]), int((r["data"] as Dictionary)["coins"])],
		[20 + Config.MEAL_STAMINA, 100 - Config.MEAL_COINS], "回体力扣钱")
	var again := NetOps.apply(r["data"] as Dictionary, "meal", {})
	check(bool(again["ok"]), "吃完马上能再吃（没有间隔）")
	check_eq(int((again["data"] as Dictionary)["coins"]), 100 - Config.MEAL_COINS * 2, "第二份照扣")
	check(not bool(NetOps.apply(_fresh({"stamina": Config.STAMINA_MAX, "coins": 100}), "meal", {})["ok"]), "饱着不吃")
	check(not bool(NetOps.apply(_fresh({"stamina": 20, "coins": 19}), "meal", {})["ok"]), "差 1 币也吃不了")

	var slept := NetOps.apply(_fresh({"stamina": 3}), "sleep", {})
	check(bool(slept["ok"]), "随时能睡")
	check_eq(int((slept["data"] as Dictionary)["stamina"]), Config.STAMINA_MAX, "睡醒满体力")
	check(bool(NetOps.apply(slept["data"] as Dictionary, "sleep", {})["ok"]), "连着睡也不拦")


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
