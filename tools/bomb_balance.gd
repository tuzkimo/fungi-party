extends SceneTree

## 平衡校准工具：无头跑整局，看玩家胜率与局长。跑完留着当以后的校准工具。
##
## 玩家有两种自动打法，都是「硬直一结束就能扔」：
##   稳妥：收到就立刻扔（从不抱着）——这是下限，输了不代表游戏太难
##   读火花：拖到剩 0.5 秒才扔——设计文档里说的「敢抱多久」，这是玩家该有的打法
##
## 用法：godot --headless --path . --script res://tools/bomb_balance.gd

const ROUNDS := 200
const STEP := 1.0 / 60.0
const SEAT_NAMES := ["你", "蓝", "红", "紫"]
const TIME_LIMIT := 120.0
## noise：每次接住重掷的「看火花估剩余时间」误差（秒）。完美读秒是神仙打法，真人看火花只能估个大概。
const STRATEGIES := [
	{"name": "稳妥（收到就扔）", "throw_at": 99.0, "noise": 0.0},
	{"name": "读火花（拖到 0.5 秒，完美读秒）", "throw_at": 0.5, "noise": 0.0},
	{"name": "读火花（拖到 0.5 秒，估计误差 ±0.4 秒）", "throw_at": 0.5, "noise": 0.4},
]


func _initialize() -> void:
	for strategy in STRATEGIES:
		_run(strategy["name"], float(strategy["throw_at"]), float(strategy["noise"]))
	quit()


func _run(label: String, player_throw_at: float, noise: float) -> void:
	var first_deaths := [0, 0, 0, 0]
	var wins := [0, 0, 0, 0]
	var in_hand := [0, 0, 0, 0]
	var in_flight := [0, 0, 0, 0]
	var total := 0.0
	var capped := 0
	for i in ROUNDS:
		var round := BombRound.new(1000 + i)
		var side := -1
		var elapsed := 0.0
		var last_holder := -2
		var estimate := 0.0
		while not round.over and elapsed < TIME_LIMIT:
			if round.holder != last_holder:
				last_holder = round.holder
				estimate = randf_range(-noise, noise)
			if round.holder == BombRound.PLAYER and round.lock <= 0.0 and round.fuse + estimate <= player_throw_at:
				round.request_throw(side)
				side = -side
			round.tick(STEP)
			elapsed += STEP
		if elapsed >= TIME_LIMIT:
			capped += 1
		total += elapsed
		for event in round.events:
			if event.get("kind") == "explode":
				if bool(event["in_flight"]):
					in_flight[int(event["seat"])] += 1
				else:
					in_hand[int(event["seat"])] += 1
		first_deaths[int(round.death_order[0])] += 1
		if round.alive.size() == 1:
			wins[int(round.alive[0])] += 1

	print("== %s：%d 局，超时 %d 局" % [label, ROUNDS, capped])
	print("玩家胜率 %.1f%%，平均局长 %.1f 秒" % [
		100.0 * float(wins[BombRound.PLAYER]) / float(ROUNDS), total / float(ROUNDS),
	])
	for seat in 4:
		print("%s：首个死亡 %d 次，胜率 %.1f%%，致死 手上 %d / 空中 %d" % [
			SEAT_NAMES[seat], first_deaths[seat],
			100.0 * float(wins[seat]) / float(ROUNDS), in_hand[seat], in_flight[seat],
		])
