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
const GAZE_RANGE := 8.5
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

# v3 森林赛跑
const RACE_TRACK_LENGTH := 220.0
const RACE_TRACK_HALF_WIDTH := 4.5
const RACE_BASE_SPEED := 6.0
const RACE_DASH_SPEED := 12.0
const RACE_DASH_SECONDS := 0.3
const RACE_DASH_COOLDOWN := 3.0
const RACE_HIT_PUSH := 1.5
const RACE_HIT_FREEZE := 0.6
const RACE_GROUP_MIN_GAP := 16.5
const RACE_GROUP_MAX_GAP := 18.0
const RACE_TALL_CHANCE := 0.7
const RACE_LOW_CHANCE := 0.2
const RACE_TALL_WIDTH := 2.6
const RACE_LOW_WIDTH := 3.4
const RACE_ANIMAL_COUNT := 6
const RACE_ANIMAL_WARN := 1.0
const RACE_ANIMAL_CLEAR := 8.0
const RACE_RANK_COINS := [70, 50, 35, 20]
const RACE_HIT_PENALTY := 5
const RACE_TIME_LIMIT := 120.0
const RACE_PATH := "res://game/minigame/race.tscn"

# v3 体力与一天
const STAMINA_MAX := 100
const STAMINA_MIN_COST := 12
const STAMINA_COST_CLASSROOM := 12
const STAMINA_COST_RACE := 20
const STAMINA_COST_BOMB := 25
const MEAL_COINS := 20
const MEAL_STAMINA := 25
const MEALS_PER_DAY := 3
const MORNING_TIME := 0.28
const DAYTIME_MAX_T := 0.80
const NIGHT_TIME := 0.86
const DAY_SAVE_INTERVAL := 5.0
const TENT_POS := Vector3(-8.0, 0.0, 2.0)
const RESTAURANT_POS := Vector3(8.0, 0.0, 2.0)
const SUN_DISTANCE := 120.0
const SUN_RADIUS := 4.5
const MOON_RADIUS := 3.2
const SKY_BODY_MIN_ELEVATION := -0.15

# v3 传炸弹
const BOMB_SEAT_RADIUS := 2.2
const BOMB_FUSE_4 := Vector2(10.0, 16.0)
const BOMB_FUSE_3 := Vector2(8.0, 13.0)
const BOMB_FUSE_2 := Vector2(5.0, 9.0)
const BOMB_FUSE_JITTER := 0.15
const BOMB_THROW_SECONDS := 0.2
const BOMB_CATCH_LOCK := 0.3
const BOMB_COUNTDOWN := 3.0
const BOMB_TIER_WARN := 2.6
const BOMB_TIER_HOT := 1.2
const BOMB_RANK_COINS := [70, 50, 35, 20]
const BOMB_PATH := "res://game/minigame/bomb.tscn"
const BOMB_NPC_ERROR := [0.5, 1.2, 0.7]
const BOMB_NPC_THROW_AT := [1.2, 0.5, 0.9]
# 人机每次接住打算抱多久（蓝 / 红 / 紫）：引信还长的时候也照这个节奏往外扔，
# 不然炸弹会一直在一个人手里，玩家没得玩
const BOMB_NPC_HOLD := [Vector2(0.6, 1.3), Vector2(1.2, 2.6), Vector2(0.8, 1.8)]
