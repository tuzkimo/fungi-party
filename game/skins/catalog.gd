class_name SkinCatalog

## 皮肤总表。用显式路径而不是扫目录：DirAccess 对导出的 res:// 不可靠，且顺序要稳定。

const PATHS: Array[String] = [
	# 夯
	"res://game/skins/hero.tres",
	"res://game/skins/king.tres",
	"res://game/skins/glow.tres",
	# 顶级
	"res://game/skins/blueberry.tres",
	"res://game/skins/fly_agaric.tres",
	"res://game/skins/stardust.tres",
	# 人上人
	"res://game/skins/matcha.tres",
	"res://game/skins/sakura.tres",
	"res://game/skins/cocoa.tres",
	# NPC
	"res://game/skins/plain.tres",
	"res://game/skins/shiitake.tres",
	"res://game/skins/canned.tres",
	# 拉完了
	"res://game/skins/poop.tres",
	"res://game/skins/stone.tres",
	"res://game/skins/wilt.tres",
]

const PART_NAMES: Array[String] = [
	"sword", "cape", "horned_helmet", "crown", "bloom", "wide_brim",
]


static func all() -> Array[MushroomSkin]:
	var result: Array[MushroomSkin] = []
	for path in PATHS:
		var skin := load(path) as MushroomSkin
		if skin == null:
			push_error("皮肤加载失败：%s" % path)
			continue
		result.append(skin)
	return result


static func by_id(id: String) -> MushroomSkin:
	if id == "":
		return null
	for skin in all():
		if skin.id == id:
			return skin
	return null


static func by_rarity(rarity: int) -> Array[MushroomSkin]:
	var result: Array[MushroomSkin] = []
	for skin in all():
		if skin.rarity == rarity:
			result.append(skin)
	return result


static func count() -> int:
	return PATHS.size()
