extends "res://tests/test_base.gd"

## 体型目录：加角色只加一条表项，存档里写了不存在的 id 要回落到红蘑菇。


func test_default_is_red() -> void:
	check_eq(BodyCatalog.normalize(""), "red", "空 id 回落到红蘑菇")
	check_eq(BodyCatalog.normalize("sponge"), "red", "乱写的 id 回落到红蘑菇")
	check_eq(BodyCatalog.normalize("seafood"), "seafood", "认得的 id 原样返回")


func test_every_body_loads() -> void:
	var ids := BodyCatalog.ids()
	check(ids.size() >= 2, "至少两个角色（实得 %d）" % ids.size())
	check_eq(ids[0], "red", "第一项是默认角色")
	for id in ids:
		check(not BodyCatalog.display_name(id).is_empty(), "%s 有中文名" % id)
		var body := BodyCatalog.create(id)
		check(body != null, "%s 能实例化" % id)
		if body != null:
			var probe := MushroomMesh.new()
			body.host = probe
			body.apply_defaults(probe)
			check(probe.body_height > 0.5 and probe.cap_radius > 0.0, "%s 的默认尺寸是正数" % id)
			probe.free()


func test_ids_are_unique() -> void:
	var seen := {}
	for id in BodyCatalog.ids():
		check(not seen.has(id), "%s 只出现一次" % id)
		seen[id] = true
