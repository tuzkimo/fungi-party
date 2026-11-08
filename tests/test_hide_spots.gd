extends TestBase

## 森林藏点：台阶跳得上去、顶面够得着建筑和树干、点与点不挤在一起。

func test_steps_are_jumpable() -> void:
	for kind in ["stone", "crates"]:
		var heights := HideSpots.climb_heights(kind)
		check(heights.size() > 0, "%s 有台阶" % kind)
		var previous := 0.0
		for h in heights:
			check(h - previous <= Config.JUMP_HEIGHT * 0.8, "%s 的台阶 %.2f 米能跳上去" % [kind, h - previous])
			previous = h
		# 石头要能上树干顶（最低 2.16），木箱要能上门楣（2.75）
		var need := 2.16 if kind == "stone" else 2.75
		check(previous + Config.JUMP_HEIGHT >= need, "%s 顶面 %.2f 米够得着 %.2f" % [kind, previous, need])


func test_spots_spread_out() -> void:
	var spots := HideSpots.spots()
	check(spots.size() >= 12, "至少 12 处藏点")
	for i in spots.size():
		for j in range(i + 1, spots.size()):
			check(spots[i].distance_to(spots[j]) >= 6.0, "%d 和 %d 号藏点不挤在一起" % [i, j])
		var nearest := INF
		for poi in Config.POI_SPOTS:
			nearest = minf(nearest, spots[i].distance_to(poi))
		var kind := str(Config.HIDE_SPOTS[i].get("kind", ""))
		# 木箱本来就贴着建筑放（它是往屋顶的梯子），只要求别压在触发区里
		var clearance := 2.0 if kind == "crates" else 6.0
		check(nearest >= clearance, "%d 号藏点离 POI 至少 %.1f 米（实 %.1f）" % [i, clearance, nearest])


## 垫脚石必须真的有树可借：用同一份 seed 复现撒树，看每块石头 6 米内有没有树。
func test_every_stone_has_a_tree() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var keep: Array[Vector3] = []
	keep.append_array(Config.POI_SPOTS)
	keep.append_array(HideSpots.spots())
	var trees := ForestGen.scatter_positions(rng, 240, 52.0, 6.0, keep)
	check(trees.size() > 200, "撒出了 %d 棵树" % trees.size())
	for entry in Config.HIDE_SPOTS:
		if str(entry["kind"]) != "stone":
			continue
		var spot: Vector3 = entry["pos"]
		var best := INF
		for tree in trees:
			best = minf(best, Vector2(tree.x - spot.x, tree.z - spot.z).length())
		check(best <= HideSpots.TREE_REACH, "%s 旁边有树（最近 %.1f 米）" % [spot, best])
