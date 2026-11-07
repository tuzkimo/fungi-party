extends TestBase

const P := "user://test_day.cfg"


func _clean() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(P))


func test_day_time_runs_from_morning_to_night() -> void:
	check(absf(Day.day_time(100) - 0.28) < 0.001, "满体力是清晨")
	check(absf(Day.day_time(0) - 0.80) < 0.001, "体力耗尽接近天黑（实得 %.3f）" % Day.day_time(0))
	check(Day.day_time(50) > Day.day_time(100), "体力少了太阳更高")
	check(Day.day_time(10) > Day.day_time(60), "体力越少天越晚")


func test_advance_time_never_rewinds() -> void:
	check(absf(Day.advance_time(0.7, 100) - 0.7) < 0.001, "吃完回体力，太阳不倒回去")
	check(absf(Day.advance_time(0.1, 20) - Day.day_time(20)) < 0.001, "体力照常推进天色")


func test_spend_cost() -> void:
	var r := Day.spend_cost(100, 20)
	check(r["ok"], "够就能玩")
	check_eq(r["stamina"], 80, "扣掉一局的花销")
	var bad := Day.spend_cost(11, 12)
	check(not bad["ok"], "差一点也玩不了")
	check_eq(bad["stamina"], 11, "玩不成不扣体力")
	check_eq(Day.spend_cost(12, 12)["stamina"], 0, "正好够扣到 0，不会负数")
	check(not Day.can_play(0, 12), "0 体力玩不了")


func test_entry_label() -> void:
	check_eq(Day.entry_label(100, 12), "体力 −12 · 剩 88", "够体力时给花销和余额")
	check_eq(Day.entry_label(11, 12), "太累了，明天再来", "不够时给原因")


func test_meal() -> void:
	var r := Day.meal(40, 100)
	check(r["ok"], "饿了有钱就能吃")
	check_eq(r["stamina"], 65, "一份回 25")
	check_eq(r["coins"], 80, "扣 20 币")
	check_eq(Day.meal(95, 100)["stamina"], 100, "回体力不超过满")
	check(not Day.meal(40, 19)["ok"], "差 1 币也吃不了")
	check(not Day.meal(100, 100)["ok"], "饱着的时候不吃")
	check(Day.meal(11, 100)["ok"], "见底照样吃：饭店不跟太阳也不跟体力走")


func test_rejected_meal_changes_nothing() -> void:
	var r := Day.meal(100, 100)
	check_eq(r["coins"], 100, "吃不成不扣钱")
	check_eq(r["stamina"], 100, "吃不成不回体力")


## 睡觉 / 吃饭的门槛是冷却，不跟世界时钟的第几天对表：两个人在线各恢复各的。
func test_recovery_cooldowns() -> void:
	check(Day.ready(1000.0, 0.0, 60.0), "从来没做过 → 立刻能做")
	check(not Day.ready(1000.0, 990.0, 60.0), "刚做过 → 还在冷却")
	check(Day.ready(1050.0, 990.0, 60.0), "到点就能做")
	check(absf(Day.wait_left(1000.0, 990.0, 60.0) - 50.0) < 0.001, "倒计时按秒算")
	check_eq(Day.wait_left(1100.0, 990.0, 60.0), 0.0, "过点了不倒扣")
	check_eq(Day.wait_text(1.0), "1 分钟", "不足一分钟也算一分钟")
	check_eq(Day.wait_text(61.0), "2 分钟", "向上取整")


func test_rollover() -> void:
	var r := Day.rollover(3)
	check_eq(r["stamina"], 100, "睡醒满体力")
	check_eq(r["day"], 4, "天数加一")
	check(absf(r["day_time"] - 0.28) < 0.001, "睡醒是清晨")


func test_save_wrappers() -> void:
	_clean()
	check(Save.spend_stamina(20, P), "第一局扣得动")
	check_eq(Save.read(P).stamina, 80, "扣完入库")
	check(Save.spend_stamina(80, P), "正好够第二局")
	check_eq(Save.read(P).stamina, 0, "扣到 0")
	check(not Save.spend_stamina(12, P), "0 体力第三局进不去")
	_clean()


func test_eat_meal_and_rollover_persist() -> void:
	_clean()
	Save.write(P, {"stamina": 40, "coins": 100, "day": 2, "day_time": 0.75})
	check(Save.eat_meal(P), "有钱就能吃")
	var d := Save.read(P)
	check_eq([d.stamina, d.coins], [65, 80], "吃一份同时改体力和钱")
	check(Save.eat_meal(P), "吃饭没有间隔，有钱就能连着吃")
	check_eq([Save.read(P).stamina, Save.read(P).coins], [90, 60], "第二份再回 25 体力、再扣 20 币")
	Save.set_day_time(0.62, P)
	check(absf(Save.read(P).day_time - 0.62) < 0.001, "天色写回存档")
	Save.rollover(P)
	var e := Save.read(P)
	check_eq([e.stamina, e.day], [100, 3], "睡一觉满体力、天数加一")
	check(e.sleep_at > 0.0, "记下睡的时间")
	check(Save.sleep_wait(P) > 0.0, "刚睡完还在冷却")
	check(absf(e.day_time - 0.28) < 0.001, "过夜回到清晨")
	check_eq(e.coins, 60, "过夜不动钱")
	_clean()
