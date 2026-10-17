class_name NpcSeat
extends RefCounted

## 人机性格：胆量越大，被盯住后撑得越久（也越容易被抓）；偶尔赌一口、偶尔发呆。
## 「发呆」不单独占字段，就是一段更长的 _rest。

var guts := 0.0
var _seen := 0.0
var _delay := 0.0
var _rest := 0.0

var _rng := RandomNumberGenerator.new()


func _init(guts_value: float, seed_value: int) -> void:
	guts = guts_value
	_rng.seed = seed_value


func decide(delta: float, gaze: Gaze, seat: int, stunned: bool) -> bool:
	if stunned:
		_seen = 0.0
		return false

	var watched := gaze.target == seat and gaze.phase != Gaze.Phase.AWAY
	if not watched:
		_seen = 0.0
		if _rest > 0.0:
			_rest = maxf(0.0, _rest - delta)
			if _rest == 0.0 and _rng.randf() < Config.NPC_IDLE_CHANCE:
				_rest = _rng.randf_range(0.8, 1.6)
		return _rest <= 0.0

	if _seen == 0.0:
		_delay = lerpf(Config.NPC_REACTION_MIN, Config.NPC_REACTION_MAX, guts) * _rng.randf_range(0.8, 1.2)
		if _rng.randf() < guts * Config.NPC_GAMBLE:
			_delay += Config.GAZE_WARN
	_seen += delta
	if _seen < _delay:
		return true
	if _rest <= 0.0:
		_rest = _rng.randf_range(0.1, 0.3)
	return false
