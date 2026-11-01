extends TestBase

## 座位配色：圆点和头顶色块共用一份，同一个对手不能两种颜色。

func test_my_seats_use_player_colors() -> void:
	var colors := RaceUI.seat_colors([0, 1])
	check_eq(colors.size(), Config.SEAT_COUNT, "四个座位一套色")
	check_eq(colors[0], RaceUI.PLAYER_COLORS[0], "0 号是自己的红")
	check_eq(colors[1], RaceUI.PLAYER_COLORS[1], "1 号是 2P 的绿")
	check_eq(colors[2], RaceUI.RIVAL_COLORS[0], "2 号是第一个对手色")
	check_eq(colors[3], RaceUI.RIVAL_COLORS[1], "3 号是第二个对手色")

func test_online_room_has_one_seat_of_my_own() -> void:
	# 联机时我是 1 号座位：自己的点还是玩家色，别画成对手色
	var colors := RaceUI.seat_colors([1])
	check_eq(colors[1], RaceUI.PLAYER_COLORS[0], "我那一格是玩家色")
	check_eq(colors[0], RaceUI.RIVAL_COLORS[0], "别人吃对手色")
