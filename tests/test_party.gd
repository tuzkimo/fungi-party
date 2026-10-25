extends TestBase

## Party 是会话静态状态：每个用例自己收尾，别把二号位漏给下一个用例。

func test_starts_solo() -> void:
	Party.leave()
	check(not Party.joined(), "默认单人")
	check_eq(Party.count(), 1, "一个人")
	check(Party.human(0), "0 号座是人")
	check(not Party.human(1), "1 号座是人机")


func test_join_makes_two_humans() -> void:
	Party.leave()
	Party.join("seafood", "hero")
	check(Party.joined(), "加入了")
	check_eq(Party.count(), 2, "两个人")
	check(Party.human(1), "1 号座是人")
	check(not Party.human(2), "2 号座还是人机")
	check_eq(Party.name_of(0), "你", "一号位叫「你」")
	check_eq(Party.name_of(1), "2P", "二号位叫「2P」")
	Party.leave()


func test_look_reads_the_right_source() -> void:
	Party.leave()
	Party.join("seafood", "")
	var second := Party.look(1)
	check_eq(second["body"], "seafood", "二号位用自己选的体型")
	check_eq(second["skin"], "", "没选皮肤就是原色")
	var first := Party.look(0)
	check(first.has("body") and first.has("skin"), "一号位读存档")


func test_join_clamps_unknown_body() -> void:
	Party.leave()
	Party.join("不存在", "")
	check_eq(Party.look(1)["body"], BodyCatalog.DEFAULT_ID, "查不到的体型回落默认")
	Party.leave()


func test_leave_restores_solo() -> void:
	Party.join("red", "")
	Party.leave()
	check(not Party.joined(), "离队回单人")
	check_eq(Party.count(), 1, "又只剩一个人")
