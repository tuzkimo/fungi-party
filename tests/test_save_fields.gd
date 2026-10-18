extends TestBase

const P := "user://test_save_fields.cfg"


func _clean() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(P))


func test_old_save_gets_defaults() -> void:
	_clean()
	Save.write(P, {"coins": 50, "owned": false, "equipped": false})
	var d := Save.read(P)
	check_eq(d.coins, 50, "老字段照旧")
	check_eq(d.stamina, 100, "老存档默认满体力")
	check_eq(d.meals, 0, "老存档没吃过饭")
	check_eq(d.day, 1, "老存档是第一天")
	check(absf(d.day_time - 0.28) < 0.001, "老存档在清晨（实得 %.3f）" % d.day_time)
	_clean()


func test_partial_write_keeps_other_fields() -> void:
	_clean()
	Save.write(P, {"coins": 250, "stamina": 40, "day_time": 0.6})
	# 买皮肤只写三个键：不能把体力、天色抹回缺省
	Save.write(P, {"coins": 50, "owned": true, "equipped": true})
	var d := Save.read(P)
	check_eq(d.coins, 50, "币按新的写")
	check_eq(d.stamina, 40, "体力不被别的写入抹掉")
	check(absf(d.day_time - 0.6) < 0.001, "天色不被别的写入抹掉")
	_clean()


func test_roundtrip_all_fields() -> void:
	_clean()
	Save.write(P, {"coins": 7, "stamina": 33, "meals": 2, "day": 9, "day_time": 0.71})
	var d := Save.read(P)
	check_eq([d.coins, d.stamina, d.meals, d.day], [7, 33, 2, 9], "五个数字字段存得住")
	check(absf(d.day_time - 0.71) < 0.001, "天体水位存得住")
	_clean()


func test_corrupt_save_falls_back_to_defaults() -> void:
	_clean()
	var f := FileAccess.open(P, FileAccess.WRITE)
	f.store_string("这不是配置" + String.chr(0) + String.chr(1))
	f.close()
	var d := Save.read(P)
	check_eq(d.stamina, 100, "存坏了也不崩，回缺省")
	check_eq(d.coins, 0, "币回缺省")
	_clean()


func test_equip_moved_to_save() -> void:
	_clean()
	Save.write(P, {"owned": false})
	check(not Save.equip(true, P), "没买不能穿")
	Save.write(P, {"owned": true, "equipped": false})
	check(Save.equip(true, P), "买了能穿")
	check(Save.read(P).equipped, "穿上入库")
	check_eq(Save.read(P).coins, 0, "换衣服不动钱")
	_clean()
