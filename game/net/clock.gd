class_name NetClock
extends RefCounted

## 世界时钟：一天 = Config.NET_DAY_SECONDS 真实秒，天色在 MORNING_TIME..NIGHT_TIME 之间线性走完，
## 走完一天 day + 1。服务器每帧 advance()，客户端只读 WORLD 里那份，两边不算第二遍。

var day := 1
## 进入本天的秒数
var seconds := 0.0


func advance(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	seconds += delta
	while seconds >= Config.NET_DAY_SECONDS:
		seconds -= Config.NET_DAY_SECONDS
		day += 1


func time_of_day() -> float:
	return lerpf(
		Config.MORNING_TIME,
		Config.NIGHT_TIME,
		clampf(seconds / Config.NET_DAY_SECONDS, 0.0, 1.0)
	)
