extends "res://tests/test_base.gd"

## 猫头鹰模型：喂食小游戏树上那只和教室里的老师共用同一份。


func _node(n: Node, part_name: String) -> Node:
	return n.find_child(part_name, true, false)


func test_owl_has_its_parts() -> void:
	var owl := OwlModel.new()
	owl.build()
	for part_name in ["Body", "Belly", "Eye", "Pupil", "Beak", "Ear", "Wing", "Foot"]:
		check(_node(owl, part_name) != null, "%s 在" % part_name)
	check(owl.get_child_count() >= 10, "眼睛翅膀都是成对的（实得 %d）" % owl.get_child_count())
	owl.free()


## 脚底要落在 bottom() 上，否则摆到地上会浮着或者陷进地里。
func test_bottom_matches_the_lowest_part() -> void:
	var owl := OwlModel.new()
	owl.build()
	var lowest := 99.0
	for child in owl.get_children():
		var node := child as MeshInstance3D
		var aabb := node.mesh.get_aabb()
		lowest = minf(lowest, (node.transform * aabb.position).y)
		lowest = minf(lowest, (node.transform * Vector3(aabb.position.x, aabb.end.y, aabb.position.z)).y)
	check(absf(lowest - owl.bottom()) < 0.05, "bottom() 对得上最低点（%.3f vs %.3f）" % [owl.bottom(), lowest])
	for child in owl.get_children():
		(child as MeshInstance3D).free()
	owl.free()


## 教室的老师必须是猫头鹰，不是一朵放大的蘑菇。
func test_teacher_is_an_owl() -> void:
	var teacher := Teacher.new()
	teacher._ready()
	var owl := _node(teacher, "TeacherOwl")
	check(owl is OwlModel, "老师是猫头鹰")
	check(_node(teacher, "TeacherBody") == null, "老师不再是蘑菇")
	check(_node(teacher, "GazeCone") != null, "视线锥还在")
	teacher.free()
