extends TestBase


func test_blueberry_skin_loads() -> void:
	var skin := SkinCatalog.by_id("blueberry")
	check(skin != null, "蓝莓帽从总表里取得到")
	if skin == null:
		return
	check_eq(skin.spot_count, 9, "蓝莓帽 9 个斑点")
	check(skin.tint_cap.b > skin.tint_cap.r, "帽子偏蓝")
