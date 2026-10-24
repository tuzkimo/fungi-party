extends TestBase

const P := "user://test_gacha.cfg"

func _clean() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(P))

func _seeded(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

func test_weights_sum_to_hundred() -> void:
	var sum := 0
	for w in Config.GACHA_WEIGHTS:
		sum += w
	check_eq(sum, 100, "权重和为 100")
	check_eq(Config.GACHA_WEIGHTS.size(), 5, "五个档位都有权重")
	check_eq(Config.GACHA_REFUND.size(), 5, "五个档位都有退币价")
	check_eq(Config.RARITY_NAMES.size(), 5, "五个档位都有名字")

func test_pick_rarity_stays_in_range() -> void:
	var rng := _seeded(42)
	for i in 500:
		var r := Gacha.pick_rarity(rng, 0)
		check(r >= 0 and r <= 4, "档位落在 0~4（实得 %d）" % r)
		if r < 0 or r > 4:
			return

func test_pity_forces_top_on_last_pull() -> void:
	var rng := _seeded(7)
	check_eq(Gacha.pick_rarity(rng, Config.GACHA_PITY - 1), 4, "第 50 抽必出夯")
	check_eq(Gacha.pick_rarity(rng, Config.GACHA_PITY), 4, "超了也还是夯")

func test_pity_one_short_is_not_forced() -> void:
	var rng := _seeded(1234)
	var always_top := true
	for i in 200:
		if Gacha.pick_rarity(rng, Config.GACHA_PITY - 2) != 4:
			always_top = false
			break
	check(not always_top, "差两抽时不该每抽都是夯")

func test_pull_takes_exactly_price() -> void:
	_clean()
	Save.write(P, {"coins": Config.GACHA_PRICE_ONE})
	var r := Gacha.pull(P, _seeded(1))
	check(r.ok, "钱刚好够就能抽")
	check(not r.duplicate, "第一抽不会是重复")
	check_eq(r.coins, 0, "抽完刚好归零")
	check_eq(Save.read(P).coins, 0, "落盘也是 0")
	_clean()

func test_pull_refuses_when_short() -> void:
	_clean()
	Save.write(P, {"coins": Config.GACHA_PRICE_ONE - 1})
	var r := Gacha.pull(P, _seeded(1))
	check(not r.ok, "差 1 币抽不了")
	check_eq(Save.read(P).coins, Config.GACHA_PRICE_ONE - 1, "抽不了不扣钱")
	check_eq(Save.read(P).owned.size(), 0, "抽不了不产出")
	_clean()

func test_new_skin_goes_into_owned() -> void:
	_clean()
	Save.write(P, {"coins": Config.GACHA_PRICE_ONE})
	var r := Gacha.pull(P, _seeded(3))
	check(r.ok and not r.duplicate, "抽到新皮肤")
	check_eq(r.refund, 0, "新的不退币")
	check_eq(Save.read(P).owned, PackedStringArray([r.id]), "进已拥有")
	_clean()

func test_duplicate_refunds_by_rarity() -> void:
	_clean()
	Save.write(P, {"coins": Config.GACHA_PRICE_ONE * 200})
	var rng := _seeded(11)
	var dup_found := false
	for i in 200:
		var r := Gacha.pull(P, rng)
		if r.duplicate:
			dup_found = true
			check_eq(r.refund, Config.GACHA_REFUND[r.rarity], "退币金额按档位")
			break
	check(dup_found, "抽够多次总会重复")
	_clean()

func test_duplicate_does_not_duplicate_owned_entry() -> void:
	_clean()
	Save.write(P, {"coins": Config.GACHA_PRICE_ONE * 200, "owned": PackedStringArray(["poop"])})
	var rng := _seeded(5)
	var dup_found := false
	for i in 200:
		var r := Gacha.pull(P, rng)
		if r.duplicate:
			dup_found = true
			break
	check(dup_found, "200 抽里出现了重复")
	check(
		Save.read(P).owned.size() <= SkinCatalog.count(),
		"已拥有不会超过总表（实得 %d）" % Save.read(P).owned.size(),
	)
	_clean()

func test_pity_resets_on_duplicate_top() -> void:
	_clean()
	# 三顶夯都已有，保底出的必是重复的夯，照样要归零
	Save.write(P, {
		"coins": Config.GACHA_PRICE_ONE * 60,
		"owned": PackedStringArray(["hero", "king", "glow"]),
		"equipped": "hero",
		"pity": Config.GACHA_PITY - 1,
	})
	var r := Gacha.pull(P, _seeded(9))
	check_eq(r.rarity, 4, "保底触发")
	check(r.duplicate, "抽到的是已拥有的夯")
	check_eq(Save.read(P).pity, 0, "重复的夯也归零")
	_clean()

func test_auto_equip_only_when_nothing_worn() -> void:
	_clean()
	Save.write(P, {"coins": Config.GACHA_PRICE_ONE})
	var r := Gacha.pull(P, _seeded(21))
	check_eq(Save.read(P).equipped, r.id, "还没穿东西时自动穿上")
	_clean()

func test_auto_equip_keeps_existing() -> void:
	_clean()
	Save.write(P, {
		"coins": Config.GACHA_PRICE_ONE * 3,
		"owned": PackedStringArray(["poop"]),
		"equipped": "poop",
	})
	Gacha.pull(P, _seeded(31))
	check_eq(Save.read(P).equipped, "poop", "已有穿戴时不被抢")
	_clean()

func test_ten_costs_ten_price_and_returns_ten() -> void:
	_clean()
	Save.write(P, {"coins": Config.GACHA_PRICE_TEN})
	var results := Gacha.pull_ten(P, _seeded(13))
	check_eq(results.size(), 10, "十连出十张")
	var refunded := 0
	for r in results:
		check(r.ok, "每一抽都成功")
		refunded += int(r["refund"])
	check_eq(
		Save.read(P).coins, refunded,
		"十连只扣 450，重复的按档位退回（退 %d）" % refunded,
	)
	_clean()

func test_ten_refused_when_short() -> void:
	_clean()
	Save.write(P, {"coins": Config.GACHA_PRICE_TEN - 1})
	var results := Gacha.pull_ten(P, _seeded(13))
	check_eq(results.size(), 0, "钱不够十连不出卡")
	check_eq(Save.read(P).coins, Config.GACHA_PRICE_TEN - 1, "钱不够不扣")
	_clean()

func test_full_collection_blocks_pulling() -> void:
	_clean()
	var all_ids := PackedStringArray()
	for skin in SkinCatalog.all():
		all_ids.append(skin.id)
	Save.write(P, {"coins": 9999, "owned": all_ids})
	check(not Gacha.can_pull_one(Save.read(P)), "集齐后不能单抽")
	check(not Gacha.can_pull_ten(Save.read(P)), "集齐后不能十连")
	check(not Gacha.pull(P, _seeded(1)).ok, "集齐后 pull 拒绝")
	check_eq(Save.read(P).coins, 9999, "集齐后抽也不扣钱")
	_clean()
