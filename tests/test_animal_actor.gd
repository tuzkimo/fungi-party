extends TestBase

## 动物本体在进场前必须停在赛道外：否则它是个看不见的碰撞体，正中线跑就会撞上。
func test_body_parked_before_entry() -> void:
	var animal := AnimalActor.new()
	animal.setup(RaceField.BEETLE, 1, 50.0)
	check(absf(animal._body.position.x) > Config.RACE_TRACK_HALF_WIDTH + 1.0,
		"setup 后本体停在赛道外（x=%f）" % animal._body.position.x)
	animal.advance(0.2)
	check(absf(animal._body.position.x) > Config.RACE_TRACK_HALF_WIDTH + 1.0,
		"影子阶段本体仍停在赛道外（x=%f）" % animal._body.position.x)
	animal.advance(Config.RACE_ANIMAL_WARN + RaceField.WALK_IN + 0.4)
	check(absf(animal._body.position.x) < 0.1,
		"进场后本体走到赛道中间（x=%f）" % animal._body.position.x)
	animal.free()
