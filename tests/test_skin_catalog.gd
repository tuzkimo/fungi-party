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


func test_group_by_rarity_empty() -> void:
	check_eq(SkinCatalog.group_by_rarity(PackedStringArray()).size(), 0, "一顶都没有就没有分组")


func test_group_by_rarity_orders_high_to_low() -> void:
	var groups := SkinCatalog.group_by_rarity(PackedStringArray(["poop", "hero", "star"]))
	check_eq(groups.size(), 2, "只出现有皮肤的两档（star 是不存在的 id）")
	if groups.size() != 2:
		return
	check_eq(groups[0].rarity, 4, "夯在最前面")
	check_eq(groups[0].skins.size(), 1, "夯这一档只有菇勇者")
	check_eq(groups[0].skins[0].id, "hero", "拿到的就是菇勇者")
	check_eq(groups[1].rarity, 0, "拉完了排在后面")
	check_eq(groups[1].skins[0].id, "poop", "拉完了是屎菇")


func test_group_by_rarity_keeps_same_tier_together() -> void:
	var groups := SkinCatalog.group_by_rarity(
		PackedStringArray(["ghost", "king", "hero", "glow"]),
	)
	check_eq(groups.size(), 1, "三顶夯归成一组，未知 id 丢掉")
	if groups.is_empty():
		return
	check_eq(groups[0].rarity, 4, "就是夯这一档")
	check_eq(groups[0].skins.size(), 3, "三顶都在")
