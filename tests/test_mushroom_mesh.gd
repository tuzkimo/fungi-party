extends "res://tests/test_base.gd"


func test_build_creates_parts() -> void:
	var m := MushroomMesh.new()
	m.build()
	check(m.get_child_count() >= 6, "部件数量（实得 %d）" % m.get_child_count())
	m.free()


func test_build_is_repeatable() -> void:
	var m := MushroomMesh.new()
	m.build()
	var first := m.get_child_count()
	m.build()
	check_eq(m.get_child_count(), first, "重建后部件数量不翻倍")
	m.free()


func test_build_is_fast() -> void:
	var m := MushroomMesh.new()
	var started := Time.get_ticks_msec()
	m.build()
	var cost := Time.get_ticks_msec() - started
	check(cost < 50, "生成耗时 %d ms，应 <50ms" % cost)
	m.free()
