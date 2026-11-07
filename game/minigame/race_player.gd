class_name RacePlayer
extends RacerVisual

## 这台机器上的玩家那一格：体型 + 皮肤来自座位，转向和走路上下颠跟着模型走。

const TURN := 0.6

var _walk_phase := 0.0


func setup_player(look: Dictionary) -> void:
	setup(Color.WHITE, look)


func apply(racer: RaceRacer, delta: float) -> void:
	super.apply(racer, delta)
	rotation.y = lerp_angle(rotation.y, -racer.steer * TURN, minf(1.0, 12.0 * delta))
	if racer.freeze > 0.0 or racer.y > 0.0:
		_visual.position.y = 0.0
	else:
		_walk_phase += delta * Config.RACE_BASE_SPEED * 3.0
		_visual.position.y = absf(sin(_walk_phase)) * 0.06
