extends TestBase


func test_all_fifteen_load() -> void:
	var all := SkinCatalog.all()
	check_eq(all.size(), 15, "15 顶皮肤全部加载")
	for skin in all:
		check(skin != null, "皮肤不是 null")
		if skin != null:
			check(skin.display_name != "", "%s 有中文名" % skin.id)


func test_ids_unique_and_match_filename() -> void:
	var seen := {}
	for skin in SkinCatalog.all():
		if skin == null:
			continue
		check(not seen.has(skin.id), "id 唯一：%s" % skin.id)
		seen[skin.id] = true
		check(
			SkinCatalog.PATHS.has("res://game/skins/%s.tres" % skin.id),
			"id 与文件名一致：%s" % skin.id,
		)


func test_three_skins_per_rarity() -> void:
	for r in 5:
		check_eq(SkinCatalog.by_rarity(r).size(), 3, "档位 %d 正好 3 顶" % r)


func test_parts_are_in_whitelist() -> void:
	for skin in SkinCatalog.all():
		if skin == null:
			continue
		for part in skin.parts:
			check(SkinCatalog.PART_NAMES.has(part), "%s 的零件 %s 在白名单里" % [skin.id, part])


func test_by_id_and_missing() -> void:
	check(SkinCatalog.by_id("hero") != null, "hero 查得到")
	check_eq(SkinCatalog.by_id("hero").rarity, 4, "菇勇者是夯")
	check(SkinCatalog.by_id("nope") == null, "查不到的 id 返回 null")


func test_blueberry_upgraded() -> void:
	var skin := SkinCatalog.by_id("blueberry")
	check(skin != null, "老蓝莓帽还在")
	if skin == null:
		return
	check_eq(skin.rarity, 3, "蓝莓帽升为顶级")
	check_eq(skin.spot_count, 9, "还是 9 个斑点")
	check(skin.tint_cap.b > skin.tint_cap.r, "帽子偏蓝")


func test_group_by_rarity_lists_every_tier() -> void:
	var groups := SkinCatalog.group_by_rarity()
	check_eq(groups.size(), 5, "五档全在，哪怕一顶都没抽到（衣柜当收集册用）")
	if groups.size() != 5:
		return
	check_eq(groups[0].rarity, 4, "夯在最前面")
	check_eq(groups[4].rarity, 0, "拉完了在最后")
	for i in 5:
		check_eq(groups[i].rarity, 4 - i, "第 %d 组是第 %d 档" % [i, 4 - i])
		check_eq((groups[i].skins as Array).size(), 3, "第 %d 档正好 3 顶" % (4 - i))


func test_group_by_rarity_keeps_same_tier_together() -> void:
	var groups := SkinCatalog.group_by_rarity()
	check_eq(groups.size(), 5, "五组")
	if groups.is_empty():
		return
	var ids: Array[String] = []
	for skin in groups[0].skins as Array:
		ids.append(skin.id)
	check_eq(ids, ["hero", "king", "glow"], "夯这一档按总表顺序排好")
