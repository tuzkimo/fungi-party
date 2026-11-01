extends TestBase

## 世界时钟：一天 = Config.NET_DAY_SECONDS 真实秒，天色在清晨..夜里走完，走完一天 day + 1。


func test_starts_at_morning_of_day_one() -> void:
	var clock := NetClock.new()
	check_eq(clock.day, 1, "新时钟是第 1 天")
	check(absf(clock.time_of_day() - Config.MORNING_TIME) < 0.001, "一开机是清晨")


func test_half_a_day_is_the_middle() -> void:
	var clock := NetClock.new()
	clock.advance(Config.NET_DAY_SECONDS * 0.5)
	var mid := (Config.MORNING_TIME + Config.NIGHT_TIME) * 0.5
	check(absf(clock.time_of_day() - mid) < 0.001, "半天正好走到中间")
	check_eq(clock.day, 1, "没走完还是同一天")


func test_full_day_wraps_to_next_morning() -> void:
	var clock := NetClock.new()
	clock.advance(Config.NET_DAY_SECONDS)
	check_eq(clock.day, 2, "走完一天 day + 1")
	check(absf(clock.time_of_day() - Config.MORNING_TIME) < 0.001, "又回到清晨")

	# 一大步跨好几天：多余的部分不能丢
	clock.advance(Config.NET_DAY_SECONDS * 2.5)
	check_eq(clock.day, 4, "跨了几天就加几天")
	check(absf(clock.time_of_day() - mid()) < 0.001, "剩下的半天照走")


func test_time_stays_between_morning_and_night() -> void:
	var clock := NetClock.new()
	for i in 11:
		var t := clock.time_of_day()
		check(t >= Config.MORNING_TIME - 0.001 and t <= Config.NIGHT_TIME + 0.001, "第 %d 格在清晨..夜里之间（%.3f）" % [i, t])
		clock.advance(Config.NET_DAY_SECONDS * 0.1)


func test_bad_delta_is_ignored() -> void:
	var clock := NetClock.new()
	clock.advance(NAN)
	clock.advance(-1.0)
	clock.advance(0.0)
	check_eq(clock.day, 1, "NaN / 负数 / 0 都不推进")
	check(absf(clock.time_of_day() - Config.MORNING_TIME) < 0.001, "天色也没动")


func mid() -> float:
	return (Config.MORNING_TIME + Config.NIGHT_TIME) * 0.5
