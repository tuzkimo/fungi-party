extends TestBase

## 森林里「走到谁跟前」那一下：只认 4 米内的真账号（同屏 2P 的 `账号|1` 不是人）。

func test_nearest_skips_two_p() -> void:
	var world := {
		"甲": {"x": 1.0, "z": 0.0},
		"乙": {"x": 3.0, "z": 0.0},
		"乙|1": {"x": 0.2, "z": 0.0},
	}
	check_eq(NearPanel.nearest(world, Vector3.ZERO, 4.0), "甲", "跳过 2P 那份")
	check_eq(NearPanel.nearest(world, Vector3.ZERO, 0.5), "", "太远就不发起")
	check_eq(NearPanel.nearest({}, Vector3.ZERO, 4.0), "", "世界里没人")


func test_nearest_ignores_height() -> void:
	var world := {"甲": {"x": 0.0, "y": 6.0, "z": 2.0}}
	check_eq(NearPanel.nearest(world, Vector3.ZERO, 4.0), "甲", "树冠上的人也算在跟前")
