extends TestBase

const P := "user://test_save.cfg"

func _clean() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(P))

func test_missing_file_defaults() -> void:
	_clean()
	var d := Save.read(P)
	check_eq(d.coins, 0, "没有存档时币为 0")
	check(not d.owned and not d.equipped, "没有存档时没皮肤")

func test_roundtrip() -> void:
	_clean()
	Save.write(P, {"coins": 120, "owned": true, "equipped": true})
	var d := Save.read(P)
	check_eq(d.coins, 120, "币存得住")
	check(d.owned and d.equipped, "皮肤状态存得住")
	_clean()

func test_add_coins_clamps_at_zero() -> void:
	_clean()
	Save.write(P, {"coins": 5, "owned": false, "equipped": false})
	check_eq(Save.add_coins(-200, P), 0, "买不起时不会变成负数")
	_clean()

func test_apply_round_earns() -> void:
	_clean()
	var r := Save.apply_round(12, false, 1, P)
	check_eq(r.earned, StealEat.coins(12, false, 1), "结算用的是同一个公式")
	check_eq(Save.read(P).coins, r.earned, "结算后币入库")
	_clean()
