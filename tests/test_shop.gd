extends TestBase

const P := "user://test_shop.cfg"

func _clean() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(P))

func test_buy_takes_exactly_price() -> void:
	_clean()
	Save.write(P, {"coins": 250, "owned": false, "equipped": false})
	check(ShopPanel.purchase(P), "钱够就能买")
	var d := Save.read(P)
	check_eq(d.coins, 50, "扣掉正好一顶的价")
	check(d.owned and d.equipped, "买完立刻拥有并穿戴")
	_clean()

func test_cannot_afford() -> void:
	_clean()
	Save.write(P, {"coins": 199, "owned": false, "equipped": false})
	check(not ShopPanel.purchase(P), "差 1 币也买不了")
	check_eq(Save.read(P).coins, 199, "买不成不扣钱")
	_clean()

func test_already_owned_not_charged_again() -> void:
	_clean()
	Save.write(P, {"coins": 250, "owned": true, "equipped": true})
	check(not ShopPanel.purchase(P), "已拥有不再成交")
	check_eq(Save.read(P).coins, 250, "不会重复扣钱")
	_clean()
