extends TestBase

## 联机时天色只读服务器世界时钟：不由体力派生、也不落本机盘。
## 单机那条路由 `Day.day_time()` / `test_day.gd` 管，这里不重复。


func test_online_sky_comes_from_the_server_clock() -> void:
	var net := NetClient.new()
	net.clock = 0.62
	net.data = Save.normalize({"stamina": Config.STAMINA_MAX})
	Save.remote = net

	var loop := DayLoop.new()
	loop._ready()
	check(absf(loop.time_of_day - 0.62) < 0.001, "满体力也不该是清晨（实得 %.3f）" % loop.time_of_day)

	# 体力掉到底也不自己把太阳推到夜里
	net.data = Save.normalize({"stamina": 0})
	loop.refresh()
	check(absf(loop.time_of_day - 0.62) < 0.001, "体力见底也用服务器的天色")

	Save.remote = null
	loop.free()
	net.free()


## 联机睡觉：体力等服务器回包才落地（DayLoop 挂在 NetClient.changed 上）
func test_refresh_follows_the_net_mirror() -> void:
	var net := NetClient.new()
	net.data = Save.normalize({"stamina": 12, "slept_day": -1})
	Save.remote = net

	var loop := DayLoop.new()
	loop._ready()
	check_eq(loop.stamina, 12, "先读到镜像里的体力")

	# 服务器那封 OP_RESULT 落地后的样子：镜像已换人、changed 已经发出来
	net.data = Save.normalize({"stamina": Config.STAMINA_MAX, "slept_day": 3, "day": 3})
	net.changed.emit()
	check_eq(loop.stamina, Config.STAMINA_MAX, "回包之后体力跟着刷新")
	check_eq(loop.day, 3, "日子也跟着刷新")

	Save.remote = null
	loop.free()
	net.free()
