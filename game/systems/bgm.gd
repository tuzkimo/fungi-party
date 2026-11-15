class_name Bgm
extends Node

## 扔粑粑那一局的底噪：和 Sfx 一样 runtime 合成，项目里没有音频文件。
## 循环点落在乐句自然衰减完的地方（尾巴再补 40ms 线性收敛），接回去听不出接缝，也不咔哒。

## 132 BPM，两小节 4/4 = 8 拍，约 3.6 秒一圈
const BPM := 132.0
const BEATS := 8.0
const MIX_RATE := 22050
## 琶音：每个和弦四个音，一拍两个八分音符（C / Am / F / G）
const CHORDS: Array = [
	[523.25, 659.25, 783.99, 1046.50],
	[440.00, 523.25, 659.25, 880.00],
	[349.23, 440.00, 523.25, 698.46],
	[392.00, 493.88, 587.33, 783.99],
]
## 每两拍一个低音（半个和弦的长度）
const BASS: Array = [130.81, 110.00, 174.61, 98.00]
## 收尾收敛：留一点静音给循环点
const TAPER_SECONDS := 0.04

var _player: AudioStreamPlayer
var _tween: Tween
## 正在淡出：`start()` / `stop()` 每帧都会被调一遍，得幂等，否则 tween 每帧重建、淡出永远走不完
var _stopping := false


## 进这一局时淡进来；已经在放就当作无事发生（每帧调都安全）
func start() -> void:
	_ensure()
	if _player.playing and not _stopping:
		return
	_stopping = false
	if not _player.playing:
		_player.volume_db = -60.0
		_player.play()
	_fade(Config.BGM_DB, 0.8)


## 收局 / 退出时淡出去再停
func stop() -> void:
	if _player == null or not _player.playing or _stopping:
		return
	_stopping = true
	_fade(-60.0, 0.5).tween_callback(_player.stop)


func _exit_tree() -> void:
	if _player != null:
		_player.stop()


func _ensure() -> void:
	if _player != null:
		return
	_player = AudioStreamPlayer.new()
	_player.name = "Loop"
	_player.stream = _loop_stream()
	_player.volume_db = -60.0
	add_child(_player)


func _fade(to_db: float, seconds: float) -> Tween:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_player, "volume_db", to_db, seconds)
	return _tween


## 一圈的 PCM：琶音（拨弦，指数衰减）+ 低音 + 反拍的一下轻沙锤。
## 纯函数，不读全局采样率，无头测试能直接跑。
static func pcm_loop(mix_rate: int) -> PackedByteArray:
	var beat := 60.0 / BPM
	var eighth := beat * 0.5
	var total := int(BEATS * beat * float(mix_rate))
	var samples := PackedFloat32Array()
	samples.resize(total)
	for chord in CHORDS.size():
		var notes: Array = CHORDS[chord]
		var at := float(chord) * beat * 2.0
		for i in notes.size():
			_add_note(samples, mix_rate, at + float(i) * eighth, float(notes[i]), eighth * 1.6, 0.20)
		_add_note(samples, mix_rate, at, float(BASS[chord]), beat * 1.2, 0.22)
	# 沙锤打在反拍上：给琶音一点推动力，又不抢拍子
	for i in int(BEATS * 2.0):
		_add_noise(samples, mix_rate, float(i) * eighth + eighth * 0.5, 0.03, 0.05)
	_taper(samples, int(TAPER_SECONDS * float(mix_rate)))
	return _to_bytes(samples)


## 一个音符：5ms 的起音（免得「啪」一声）+ 指数衰减，基音带一点二次谐波，听着像拨弦。
static func _add_note(buffer: PackedFloat32Array, mix_rate: int, start: float, freq: float, seconds: float, amp: float) -> void:
	var from := int(start * float(mix_rate))
	var count := int(seconds * float(mix_rate))
	for i in count:
		var index := from + i
		if index < 0 or index >= buffer.size():
			continue
		var t := float(i) / float(mix_rate)
		var attack := minf(1.0, t / 0.005)
		var phase := TAU * freq * t
		buffer[index] += (sin(phase) + 0.25 * sin(phase * 2.0)) * exp(-t * 6.0) * attack * amp


## 沙锤：一小撮白噪声，一阶高通掉低频，短到听不出音高。
static func _add_noise(buffer: PackedFloat32Array, mix_rate: int, start: float, seconds: float, amp: float) -> void:
	var from := int(start * float(mix_rate))
	var count := int(seconds * float(mix_rate))
	var rng := RandomNumberGenerator.new()
	rng.seed = from + 1
	var previous := 0.0
	for i in count:
		var index := from + i
		if index < 0 or index >= buffer.size():
			continue
		var t := float(i) / float(mix_rate)
		var raw := rng.randf_range(-1.0, 1.0)
		buffer[index] += (raw - previous) * exp(-t * 90.0) * amp
		previous = raw


## 尾巴线性收到 0：循环点前最后一点余音不至于「咔」一声接上开头。
static func _taper(buffer: PackedFloat32Array, count: int) -> void:
	var from := maxi(0, buffer.size() - count)
	for i in range(from, buffer.size()):
		buffer[i] *= float(buffer.size() - i) / float(count + 1)


static func _to_bytes(samples: PackedFloat32Array) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(samples.size() * 2)
	for i in samples.size():
		out.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	return out


func _loop_stream() -> AudioStreamWAV:
	var data := pcm_loop(MIX_RATE)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = data.size() / 2
	return stream
