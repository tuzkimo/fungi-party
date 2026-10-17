class_name Config

const WALK_SPEED := 3.0
const RUN_SPEED := 6.0
const ACCEL := 20.0
const DECEL := 25.0
const GRAVITY := 24.0
const JUMP_HEIGHT := 1.5
const AIR_CONTROL := 0.35
const SQUASH_MAX := 0.2
const DAY_LENGTH_SECONDS := 600.0
const CAM_MIN_LENGTH := 1.2

# v2 教室偷吃
const SEAT_COUNT := 4
const ROUND_SECONDS := 90.0
const BITES_TO_WIN := 20
const BITE_SECONDS := 1.6
const CATCH_GRACE := 0.1
const STUN_SECONDS := 3.0
const MAX_CAUGHT := 3
const GAZE_AWAY_MIN := 2.0
const GAZE_AWAY_MAX := 5.0
const GAZE_WARN := 0.3
const GAZE_WATCH := 2.0
const GAZE_HALF_ANGLE := 14.0
const GAZE_RANGE := 5.5
const SEAT_POSITIONS := [
	Vector3(-1.2, 0.0, 1.2), Vector3(-4.0, 0.0, 0.6), Vector3(1.6, 0.0, 0.6), Vector3(4.2, 0.0, 1.2)
]
const TEACHER_POS := Vector3(0.0, 0.0, -5.5)
# v2 人机
const NPC_GUTS := [0.15, 0.35, 0.55]
const NPC_REACTION_MIN := 0.15
const NPC_REACTION_MAX := 0.60
const NPC_GAMBLE := 0.25
const NPC_IDLE_CHANCE := 0.25
# v2 蘑菇币
const COIN_BASE := 10
const COIN_PER_BITE := 3
const COIN_WIN_BONUS := 40
const COIN_PER_CATCH := 5
const SKIN_PRICE := 200
const SKIN_PATH := "res://game/skins/blueberry.tres"
const CLASSROOM_PATH := "res://game/minigame/classroom.tscn"
const FOREST_PATH := "res://game/main.tscn"
