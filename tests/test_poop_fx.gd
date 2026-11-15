extends TestBase

## 扔粑粑的表现层：命中怎么触发、色块摆在哪、起手 / 晃动曲线、合成出来的一圈音乐接不接得上。


## 快照只给累计命中数：涨了的那几个座位才是这一拍挨了的人。
func test_hit_seats_from_counters() -> void:
	check_eq(PoopField.hit_seats([0, 0], [0, 0]), [], "没涨就没人挨")
	check_eq(PoopField.hit_seats([0, 0], [1, 0]), [0], "0 号涨了")
	check_eq(PoopField.hit_seats([0, 1], [1, 2]), [0, 1], "两个人都涨了")
	check_eq(PoopField.hit_seats([0, 0], [0, 3]), [1], "同一格涨两下也只演一次")
	check_eq(PoopField.hit_seats([], [1]), [], "长度不一致不越界")
	check_eq(PoopField.hit_seats([2], []), [], "反过来也不越界")


## 色块要贴在帽面上：位置跟着 `cap_base()` / `top()` / `cap_radius_at()`，换体型不飘。
func test_splat_spot_sits_on_the_cap() -> void:
	var base := 0.9
	var height := 0.35
	var low := PoopField.splat_spot(0.0, 0.0, 0.7, base, height)
	check(is_equal_approx(low.y, base), "y_norm 0 就是帽底")
	check(is_equal_approx(low.z, 0.7), "角 0 时在 +Z 上")
	var high := PoopField.splat_spot(PI * 0.5, 1.0, 0.2, base, height)
	check(is_equal_approx(high.y, base + height * 2.0), "y_norm 1 和 top() 同一套算法")
	check(is_equal_approx(high.x, 0.2), "角 90 度时在 +X 上")


## 扔出去那一下：后仰蓄力 → 前甩 → 回正，两端都是 0（中途停下不会突然弹回去）。
func test_throw_lean_goes_back_then_forward() -> void:
	check(is_equal_approx(Movement.throw_lean(0.0), 0.0), "起手从 0 开始")
	check(Movement.throw_lean(0.08) < -0.05, "先往后（蓄力）")
	check(Movement.throw_lean(0.26) > 0.05, "再往前（甩出去）")
	check(is_equal_approx(Movement.throw_lean(Movement.THROW_ANIM_SECONDS), 0.0), "结束时回正")
	check(is_equal_approx(Movement.throw_lean(-1.0), 0.0), "没在扔就是 0")


## 被打中：先压扁、晃两圈半，结束时回到原样。
func test_hit_anim_returns_to_rest() -> void:
	var half := Movement.HIT_ANIM_SECONDS * 0.5
	check(is_equal_approx(Movement.hit_wobble(0.0), 0.0), "挨中那一下从 0 开始")
	check(absf(Movement.hit_wobble(0.05)) > 0.05, "中途在晃")
	check(is_equal_approx(Movement.hit_wobble(Movement.HIT_ANIM_SECONDS), 0.0), "结束时归零")
	check(Movement.hit_squash(half).y < 0.9, "中途压扁")
	check(Movement.hit_squash(Movement.HIT_ANIM_SECONDS).is_equal_approx(Vector3.ONE), "结束回到原样")


## 一发粑粑：尾巴在身后、越来越小、整条够长（截图会被树挡住，靠结构验）
func test_shot_has_a_tapering_trail_behind() -> void:
	var field := PoopField.new()
	field._ready()
	var shot := field._new_shot(0)
	var trail: Array[Node3D] = []
	for child in shot.get_children():
		if str(child.name).begins_with("Trail"):
			trail.append(child as Node3D)
	check_eq(trail.size(), Config.POOP_TRAIL, "尾巴点数")
	var last_z := 0.0
	for dot in trail:
		check(dot.position.z > last_z, "尾巴在 +Z（身后）越来越远")
		last_z = dot.position.z
	check(trail[-1].position.z - trail[0].position.z > 0.5, "整条尾巴够长才看得出在飞")
	check(trail[0].scale.x > trail[-1].scale.x, "尾巴越往后越小")
	# 朝向：节点自己的 -Z 指向飞行方向，尾巴才落在身后
	PoopField._face_flight(shot, Vector3(14.0, 0.0, 0.0))
	check(shot.basis.z.dot(Vector3(14.0, 0.0, 0.0)) < -13.0, "-Z 指向飞行方向（z=%s）" % str(shot.basis.z))
	field.free()


## 一圈 8 拍，循环点必须接近静音：不然每 3.6 秒「咔」一下。
func test_bgm_loop_is_seamless() -> void:
	var rate := Bgm.MIX_RATE
	var started := Time.get_ticks_msec()
	var data := Bgm.pcm_loop(rate)
	# 进这一局只合成一次，超过小半秒就会卡一下；桌面这个数看不出来，真机得靠它盯着
	var elapsed := Time.get_ticks_msec() - started
	print("    合成一圈 %d ms" % elapsed)
	check(elapsed < 400, "合成一圈不卡（实得 %d ms）" % elapsed)
	var beat := 60.0 / Bgm.BPM
	check_eq(data.size(), int(Bgm.BEATS * beat * float(rate)) * 2, "长度正好 8 拍")
	var loud := 0
	for i in range(0, data.size(), 2):
		if absi(data.decode_s16(i)) > 200:
			loud += 1
	check(loud > data.size() / 8, "不是静音")
	var tail := absi(data.decode_s16(data.size() - 2))
	check(tail < 400, "尾巴收到静音（实得 %d）" % tail)
