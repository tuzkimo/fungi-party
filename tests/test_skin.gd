extends TestBase

func test_blueberry_skin_loads() -> void:
	var skin := load(Config.SKIN_PATH) as MushroomSkin
	check(skin != null, "皮肤资源能加载（路径 %s）" % Config.SKIN_PATH)
	if skin == null:
		return
	check_eq(skin.spot_count, 9, "蓝莓帽 9 个斑点")
	check(skin.tint_cap.b > skin.tint_cap.r, "帽子偏蓝")
