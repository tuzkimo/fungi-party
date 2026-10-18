extends TestBase

const RATE := 22050


func _not_silent(data: PackedByteArray) -> bool:
	var loud := 0
	for i in range(0, data.size(), 2):
		if absi(data.decode_s16(i)) > 200:
			loud += 1
	return loud > data.size() / 8


func test_fizz_length_and_not_silent() -> void:
	var data := Sfx.pcm_fizz(0.25, RATE)
	check_eq(data.size(), int(0.25 * RATE) * 2, "16bit 单声道长度")
	check(_not_silent(data), "嗤嗤声不能是静音")


func test_one_shots_not_silent() -> void:
	check(_not_silent(Sfx.pcm_tick(RATE)), "滴答有声")
	check(_not_silent(Sfx.pcm_boom(RATE)), "爆炸有声")
	check(_not_silent(Sfx.pcm_pop(RATE)), "接住有声")
	check(_not_silent(Sfx.pcm_whoosh(RATE)), "扔出有声")


func test_tick_interval_tightens_with_danger() -> void:
	check(is_equal_approx(Sfx.tick_interval(0.0), 0.55), "平静时 0.55 秒一次")
	check(is_equal_approx(Sfx.tick_interval(1.0), 0.12), "白热时 0.12 秒一次")
	check(Sfx.tick_interval(0.5) < Sfx.tick_interval(0.2), "越危险越急")
