class_name Sfx
extends Node

## 全部音效运行时生成：16bit 小端单声道 PCM 直接填进 AudioStreamWAV，项目里没有音频文件。
## 纯函数（pcm_* / tick_interval）不读全局采样率，才能在无头测试里跑。

const MIX_RATE := 22050
const TICK_SECONDS := 0.06
const BOOM_SECONDS := 0.5
const POP_SECONDS := 0.08
const WHOOSH_SECONDS := 0.15
const WIN_SECONDS := 0.34
## 滴答间隔：平静 0.55 秒一次，白热 0.12 秒一次。
const TICK_SLOW := 0.55
const TICK_FAST := 0.12
const FIZZ_SECONDS := 1.0

var _fizz: AudioStreamPlayer
var _oneshot: AudioStreamPlayer
var _streams := {}
var _danger := 0.0
var _in_hand := false
var _tick_left := 0.0


func _ready() -> void:
	_ensure()


## 强制退出时还挂着播放中的流，会留下 AudioStream 泄漏告警。
func _exit_tree() -> void:
	if _fizz != null:
		_fizz.stop()
	if _oneshot != null:
		_oneshot.stop()


## 滴答只在 danger > 0（进入冒白星档附近）之后才响，越危险越急。
func _process(delta: float) -> void:
	if _danger <= 0.0:
		_tick_left = 0.0
		return
	_tick_left -= delta
	if _tick_left > 0.0:
		return
	var interval := tick_interval(_danger)
	_tick_left = interval
	play("tick")
	if _in_hand:
		vibrate(int(interval * 1000.0 * 0.6))


func _ensure() -> void:
	if _fizz != null:
		return
	_fizz = AudioStreamPlayer.new()
	_fizz.name = "Fizz"
	_fizz.stream = _fizz_stream()
	_fizz.volume_db = linear_to_db(0.10)
	add_child(_fizz)
	_oneshot = AudioStreamPlayer.new()
	_oneshot.name = "OneShot"
	add_child(_oneshot)
	_streams = {
		"tick": _wave(pcm_tick(MIX_RATE)),
		"catch": _wave(pcm_pop(MIX_RATE)),
		"throw": _wave(pcm_whoosh(MIX_RATE)),
		"boom": _wave(pcm_boom(MIX_RATE)),
		"win": _wave(pcm_win(MIX_RATE)),
	}
	_fizz.play()


## kind ∈ "tick" "catch" "throw" "boom" "win"。
func play(kind: String) -> void:
	_ensure()
	if not _streams.has(kind):
		return
	_oneshot.stream = _streams[kind]
	_oneshot.play()


## 驱动嗤嗤声的音量/速率；danger 0→1 对应引信剩下的最后 3 秒。
func set_danger(danger: float, in_hand: bool) -> void:
	_ensure()
	_danger = clampf(danger, 0.0, 1.0)
	_in_hand = in_hand
	_fizz.pitch_scale = lerpf(0.85, 1.8, _danger)
	_fizz.volume_db = linear_to_db(lerpf(0.10, 0.45, _danger))
	if not _fizz.playing:
		_fizz.play()


## 暂停与结算时调用：嗤嗤声、滴答、震动全停。
func stop_fuse() -> void:
	_danger = 0.0
	_in_hand = false
	_tick_left = 0.0
	if _fizz != null:
		_fizz.stop()


## 桌面是空操作；真机上按滴答节拍震。
func vibrate(ms: int) -> void:
	if ms > 0:
		Input.vibrate_handheld(ms)


static func tick_interval(danger: float) -> float:
	return lerpf(TICK_SLOW, TICK_FAST, clampf(danger, 0.0, 1.0))


## 嗤嗤声：白噪声过一阶低通，循环播放。
static func pcm_fizz(seconds: float, mix_rate: int) -> PackedByteArray:
	var count := int(seconds * mix_rate)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var low := 0.0
	for i in count:
		low = lerpf(low, rng.randf_range(-1.0, 1.0), 0.25)
		samples[i] = low * 0.6
	return _to_bytes(samples)


## 滴答：1800Hz 短脉冲 + 快速衰减。
static func pcm_tick(mix_rate: int) -> PackedByteArray:
	var count := int(TICK_SECONDS * mix_rate)
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i in count:
		var t := float(i) / float(mix_rate)
		samples[i] = sin(TAU * 1800.0 * t) * exp(-t * 60.0)
	return _to_bytes(samples)


## 爆炸：低频正弦下扫 + 噪声爆点 + 指数衰减。
static func pcm_boom(mix_rate: int) -> PackedByteArray:
	var count := int(BOOM_SECONDS * mix_rate)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var phase := 0.0
	for i in count:
		var t := float(i) / float(mix_rate)
		phase += TAU * lerpf(80.0, 45.0, t / BOOM_SECONDS) / float(mix_rate)
		var env := exp(-t * 7.0)
		var burst := rng.randf_range(-1.0, 1.0) * exp(-t * 40.0) * 0.5
		samples[i] = (sin(phase) * 0.8 + burst) * env
	return _to_bytes(samples)


## 接住：上滑正弦短音。
static func pcm_pop(mix_rate: int) -> PackedByteArray:
	var count := int(POP_SECONDS * mix_rate)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var phase := 0.0
	for i in count:
		var t := float(i) / float(mix_rate)
		phase += TAU * lerpf(420.0, 900.0, t / POP_SECONDS) / float(mix_rate)
		samples[i] = sin(phase) * exp(-t * 22.0)
	return _to_bytes(samples)


## 扔出：噪声过两级低通差分（近似带通），包络先扬后落。
static func pcm_whoosh(mix_rate: int) -> PackedByteArray:
	var count := int(WHOOSH_SECONDS * mix_rate)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	var low1 := 0.0
	var low2 := 0.0
	for i in count:
		var t := float(i) / float(mix_rate)
		low1 = lerpf(low1, rng.randf_range(-1.0, 1.0), 0.5)
		low2 = lerpf(low2, low1, 0.5)
		samples[i] = (low1 - low2) * sin(PI * t / WHOOSH_SECONDS) * 1.5
	return _to_bytes(samples)


## 胜利：三个上行短音。
static func pcm_win(mix_rate: int) -> PackedByteArray:
	var count := int(WIN_SECONDS * mix_rate)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var notes := [523.25, 659.25, 783.99]
	var phase := 0.0
	for i in count:
		var t := float(i) / float(mix_rate)
		var index := mini(int(t / (WIN_SECONDS / 3.0)), notes.size() - 1)
		phase += TAU * float(notes[index]) / float(mix_rate)
		var local := t - float(index) * (WIN_SECONDS / 3.0)
		samples[i] = sin(phase) * exp(-local * 9.0) * 0.7
	return _to_bytes(samples)


static func _to_bytes(samples: PackedFloat32Array) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(samples.size() * 2)
	for i in samples.size():
		out.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	return out


func _fizz_stream() -> AudioStreamWAV:
	var stream := _wave(pcm_fizz(FIZZ_SECONDS, MIX_RATE))
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(FIZZ_SECONDS * MIX_RATE)
	return stream


func _wave(data: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream
