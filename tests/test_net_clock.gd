extends TestBase

## 世界时钟：一天 = Config.NET_DAY_SECONDS 真实秒，天数照墙钟算（重启前后、两台设备都是同一个数），
## 天色在清晨..夜里走完。

const DAY := Config.NET_DAY_SECONDS


func test_day_and_time_from_wall_clock() -> void:
	var clock := NetClock.new()
	clock.sync(0.0)
	check_eq(clock.day, 1, "Unix 0 是第 1 天")
	check(absf(clock.time_of_day() - Config.MORNING_TIME) < 0.001, "一天的开始是清晨")

	clock.sync(DAY * 0.5)
	check_eq(clock.day, 1, "没走完还是同一天")
	check(absf(clock.time_of_day() - mid()) < 0.001, "半天正好走到中间")

	clock.sync(DAY)
	check_eq(clock.day, 2, "走完一天 day + 1")
	check(absf(clock.time_of_day() - Config.MORNING_TIME) < 0.001, "又回到清晨")

	clock.sync(DAY * 4.5)
	check_eq(clock.day, 5, "跨了几天就加几天")
	check(absf(clock.time_of_day() - mid()) < 0.001, "剩下的半天照走")


## 真机踩过的坑：服务器一重启天数归零，存档里的 slept_day 就「永远睡过了」。
func test_restart_lands_on_the_same_day() -> void:
	var before := NetClock.new()
	before.sync(1_700_000_000.0)
	var after := NetClock.new()
	after.sync(1_700_000_061.0)
	check_eq(after.day, before.day, "重启后还是同一天")
	check(after.time_of_day() > before.time_of_day(), "天色接着走，不回到清晨")


func test_time_stays_between_morning_and_night() -> void:
	var clock := NetClock.new()
	for i in 11:
		clock.sync(DAY * 0.1 * i)
		var t := clock.time_of_day()
		check(
			t >= Config.MORNING_TIME - 0.001 and t <= Config.NIGHT_TIME + 0.001,
			"第 %d 格在清晨..夜里之间（%.3f）" % [i, t]
		)


func test_bad_unix_is_ignored() -> void:
	var clock := NetClock.new()
	clock.sync(DAY)
	clock.sync(NAN)
	clock.sync(-1.0)
	check_eq(clock.day, 2, "NaN / 负数都不改动")
	check(absf(clock.time_of_day() - Config.MORNING_TIME) < 0.001, "天色也没动")


func mid() -> float:
	return (Config.MORNING_TIME + Config.NIGHT_TIME) * 0.5
