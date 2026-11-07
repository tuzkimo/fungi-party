class_name NetClock
extends RefCounted

## 世界时钟：一天 = Config.NET_DAY_SECONDS 真实秒，天色在 MORNING_TIME..NIGHT_TIME 之间线性走完，
## 走完一天 day + 1。
##
## 天数从墙钟算，不数服务器开机时长：服务器一重启（每次部署都重启）天数会归零，
## 玩家存档里的 `slept_day` 就成了「刚睡过的那一天」，于是睡觉一直回 `slept`，
## 得干等下一次重启 —— 真机踩过。照着 Unix 时间算，重启前后、两台设备都是同一个数。

var day := 1
## 进入本天的秒数
var seconds := 0.0


## 对表：`unix_now` 是 Unix 秒（服务器传 Time.get_unix_time_from_system()）。
func sync(unix_now: float) -> void:
	if not is_finite(unix_now) or unix_now < 0.0:
		return
	day = 1 + int(unix_now / float(Config.NET_DAY_SECONDS))
	seconds = fmod(unix_now, float(Config.NET_DAY_SECONDS))


func time_of_day() -> float:
	return lerpf(
		Config.MORNING_TIME,
		Config.NIGHT_TIME,
		clampf(seconds / Config.NET_DAY_SECONDS, 0.0, 1.0)
	)
