class_name Config

const WALK_SPEED := 3.0
const RUN_SPEED := 6.0
const ACCEL := 20.0
const DECEL := 25.0
const GRAVITY := 24.0
const JUMP_HEIGHT := 1.5
const AIR_CONTROL := 0.35
const SQUASH_MAX := 0.2
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
## 0/1 号座给玩家（同屏双人时正好占中间两张课桌），2/3 号座给人机
const SEAT_POSITIONS := [
	Vector3(-1.2, 0.0, 0.6), Vector3(1.6, 0.0, 0.6), Vector3(-4.0, 0.0, 1.2), Vector3(4.2, 0.0, 1.2)
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
# v4 皮肤抽卡（下标 = 档位：0 拉完了 / 1 NPC / 2 人上人 / 3 顶级 / 4 夯）
const GACHA_PRICE_ONE := 50
const GACHA_PRICE_TEN := 450
const GACHA_PITY := 50
const GACHA_WEIGHTS: Array[int] = [30, 30, 23, 12, 5]
const GACHA_REFUND: Array[int] = [10, 20, 40, 80, 150]
const RARITY_NAMES: Array[String] = ["拉完了", "NPC", "人上人", "顶级", "夯"]
const RARITY_COLORS: Array[Color] = [
	Color(0.55, 0.55, 0.58),
	Color(0.62, 0.72, 0.60),
	Color(0.42, 0.66, 0.88),
	Color(0.78, 0.45, 0.88),
	Color(0.98, 0.78, 0.26),
]
const CLASSROOM_PATH := "res://game/minigame/classroom.tscn"
const FOREST_PATH := "res://game/main.tscn"

# v6 同屏双人：森林里谁推摇杆谁带队，另一个跟在侧后方
const PARTY_FOLLOW_GAP := 1.2     # 目标点在一号位身后多远
## 侧面让开这么多：正后方会夹在相机和一号位中间，被拍成一张糊满屏的大脸
const PARTY_FOLLOW_SIDE := 1.1
const PARTY_FOLLOW_STOP := 0.45   # 离目标点这么近就停下，免得原地抖
const PARTY_FOLLOW_RUN := 3.5     # 被甩开这么远就改成跑

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
## 五名：同屏双人时场上两个人类 + 三个人机
const RACE_RANK_COINS := [70, 50, 35, 20, 20]
const RACE_HIT_PENALTY := 5
const RACE_TIME_LIMIT := 120.0
const RACE_PATH := "res://game/minigame/race.tscn"

# v3 体力与一天
const STAMINA_MAX := 100
const STAMINA_MIN_COST := 12
const STAMINA_COST_CLASSROOM := 12
const STAMINA_COST_RACE := 20
const STAMINA_COST_BOMB := 25
const STAMINA_COST_OWL := 30
const MEAL_COINS := 20
const MEAL_STAMINA := 25
const MEALS_PER_DAY := 3
const MORNING_TIME := 0.28
const DAYTIME_MAX_T := 0.80
const NIGHT_TIME := 0.86
const DAY_SAVE_INTERVAL := 5.0
const MEAL_ANIMATION_SECONDS := 1.2
const TENT_POS := Vector3(-8.0, 0.0, 2.0)
const RESTAURANT_POS := Vector3(8.0, 0.0, 2.0)
const OWL_TREE_POS := Vector3(-8.0, 0.0, 10.0)
## 七个 POI 的位置（和 forest.tscn 里摆的一致）：树和石头不往它们跟前长
const POI_SPOTS: Array[Vector3] = [
	Vector3(0.0, 0.0, -14.0), Vector3(7.0, 0.0, -11.0), Vector3(-7.0, 0.0, -11.0),
	Vector3(0.0, 0.0, 11.0), TENT_POS, RESTAURANT_POS, OWL_TREE_POS,
]
const SUN_DISTANCE := 120.0
const SUN_RADIUS := 4.5
const MOON_RADIUS := 3.2
const SKY_BODY_MIN_ELEVATION := -0.15
# v3 天空：低多边形云 + 会闪的星星（见 docs/superpowers/specs/2026-10-18-v3-sky-design.md）
const CLOUD_COUNT := 10
const CLOUD_PUFFS := 4
const CLOUD_DISTANCE := 210.0
const CLOUD_HEIGHT_MIN := 95.0
const CLOUD_HEIGHT_MAX := 160.0
const CLOUD_DRIFT := 0.004
const STAR_COUNT := 150
const STAR_GROUPS := 3
const STAR_DISTANCE := 300.0
const STAR_TWINKLE_SPEED := 2.4

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

# v4 猫头鹰喂食
## 三关：越长、越快、屎越多。下落时长是主难度旋钮——它就是你认出来再松手的反应窗口。
const OWL_SECONDS := [45.0, 50.0, 55.0]
## 投喂节奏：平时隔得开，时不时来一串「连珠」——两秒一串三颗 = 心跳
const OWL_GAP := [Vector2(0.9, 1.6), Vector2(0.7, 1.3), Vector2(0.5, 1.0)]
const OWL_BURST_CHANCE := [0.3, 0.4, 0.5]
const OWL_BURST_GAP := [Vector2(0.25, 0.45), Vector2(0.22, 0.40), Vector2(0.20, 0.35)]
const OWL_FALL := [1.1, 0.9, 0.7]
const OWL_POOP := [0.25, 0.33, 0.40]
const OWL_RANK_COINS := [70, 50, 35, 20]
## 玩家出局后本关剩下一段：快进跑完，人机分数照实累加
const OWL_FAST_FORWARD := 2.5
const OWL_BREAK_SECONDS := 1.6
const OWL_COUNTDOWN := 3.0
## 0/1 号座给玩家（双人时占中间两个），2/3 号座给人机
const OWL_SEAT_X := [-0.9, 0.9, -2.7, 2.7]
## 三个 NPC：敢吃糖的概率 / 会误吞屎的概率 / 张嘴提前量（下落时长的倍数）
const OWL_NPC_EAT := [0.9, 0.97, 0.75]
const OWL_NPC_GREED := [0.05, 0.28, 0.02]
const OWL_NPC_LEAD := [Vector2(0.15, 0.8), Vector2(0.15, 0.8), Vector2(0.35, 1.0)]
const OWL_PATH := "res://game/minigame/owl.tscn"
