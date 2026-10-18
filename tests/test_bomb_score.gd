extends TestBase


func test_rank_by_reverse_death_order() -> void:
	var death := [3, 1, 2]
	var alive := [0]
	check_eq(BombScore.rank_of(0, death, alive), 0, "活着的第一名")
	check_eq(BombScore.rank_of(2, death, alive), 1, "最后死的第二名")
	check_eq(BombScore.rank_of(1, death, alive), 2, "中间死的第三名")
	check_eq(BombScore.rank_of(3, death, alive), 3, "最先死的第四名")


func test_coins_by_rank() -> void:
	check_eq(BombScore.coins(0), 70, "第一名")
	check_eq(BombScore.coins(3), 20, "第四名也有保底")
	check_eq(BombScore.coins(99), 20, "越界夹到最后一档")


func test_rows_lists_dead_and_alive() -> void:
	var death := [3, 1]
	var alive := [2, 0]
	var rows := BombScore.rows(death, alive, ["你", "蓝", "紫", "红"])
	check_eq(rows[0]["note"], "仍在场上", "活着的人排最前")
	check_eq(rows[rows.size() - 1]["name"], "红", "最先死的排最后")
	check(rows[rows.size() - 1]["note"].ends_with("被炸"), "死人有注记")
