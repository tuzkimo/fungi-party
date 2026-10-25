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
	# 抽卡只写四个键：不能把体力、天色抹回缺省
	Save.write(P, {"coins": 50, "owned": PackedStringArray(["blueberry"]), "equipped": "blueberry"})
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


func test_legacy_bool_owned_migrates() -> void:
	_clean()
	# v3 存档的样子：只写了布尔键
	Save.write(P, {"coins": 0, "owned": true, "equipped": true})
	var d := Save.read(P)
	check_eq(d.owned, PackedStringArray(["blueberry"]), "老存档的蓝莓帽补进已拥有")
	check_eq(d.equipped, "blueberry", "老存档继续穿着蓝莓帽")
	_clean()


func test_legacy_bool_not_equipped_migrates() -> void:
	_clean()
	Save.write(P, {"owned": true, "equipped": false})
	var d := Save.read(P)
	check_eq(d.owned, PackedStringArray(["blueberry"]), "买了没穿的也有皮肤")
	check_eq(d.equipped, "", "没穿就是默认红帽")
	_clean()


func test_fresh_save_has_no_skin() -> void:
	_clean()
	var d := Save.read(P)
	check_eq(d.owned.size(), 0, "新存档一顶都没有")
	check_eq(d.equipped, "", "新存档穿默认")
	check_eq(d.pity, 0, "新存档保底计数为 0")


func test_owned_roundtrip() -> void:
	_clean()
	Save.write(P, {"owned": PackedStringArray(["hero", "poop"]), "equipped": "hero", "pity": 7})
	var d := Save.read(P)
	check_eq(d.owned, PackedStringArray(["hero", "poop"]), "已拥有列表存得住")
	check_eq(d.equipped, "hero", "穿戴 id 存得住")
	check_eq(d.pity, 7, "保底计数存得住")
	_clean()


func test_equip_requires_owned_id() -> void:
	_clean()
	Save.write(P, {"owned": PackedStringArray(["hero"])})
	check(not Save.equip("poop", P), "没拥有的穿不上")
	check_eq(Save.read(P).equipped, "", "穿不上就不写盘")
	check(Save.equip("hero", P), "拥有的能穿")
	check_eq(Save.read(P).equipped, "hero", "穿上入库")
	check(Save.equip("", P), "能换回默认")
	check_eq(Save.read(P).equipped, "", "换回默认后为空")
	check_eq(Save.read(P).coins, 0, "换衣服不动钱")
	_clean()


func test_equip_gone_id_is_ignored() -> void:
	_clean()
	# 皮肤 id 从总表里消失后，存档里还留着：不能崩，也不能穿
	Save.write(P, {"owned": PackedStringArray(["ghost"]), "equipped": "ghost"})
	var d := Save.read(P)
	check_eq(d.equipped, "ghost", "存档层不做白名单判断（读出来就是原样）")
	check(SkinCatalog.by_id(d.equipped) == null, "上层拿到 null 会回落默认外观")
	_clean()


func test_character_defaults_to_red() -> void:
	_clean()
	check_eq(Save.read(P).character, "red", "没写过角色就是红蘑菇")
	_clean()


func test_character_roundtrip() -> void:
	_clean()
	Save.write(P, {"coins": 120})
	check(Save.set_character("seafood", P), "能换成海鲜菇")
	check_eq(Save.read(P).character, "seafood", "角色存得住")
	check_eq(Save.read(P).coins, 120, "换角色不动钱")
	check(not Save.set_character("sponge", P), "不存在的角色写不进去")
	check_eq(Save.read(P).character, "seafood", "拒绝之后存档没变")
	_clean()


## 手改存档写了个乱七八糟的 id：读出来是原样（存档层不做白名单），
## BodyCatalog.normalize() 兜住它，玩家看到的是红蘑菇而不是崩溃。
func test_unknown_character_falls_back_to_red() -> void:
	_clean()
	Save.write(P, {"character": "sponge"})
	check_eq(BodyCatalog.normalize(Save.read(P).character), "red", "乱写的角色回落红蘑菇")
	_clean()
