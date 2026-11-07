extends TestBase

## 启动菜单两件纯事：服务器地址怎么拆、口令不落盘的凭据怎么带。

func test_parse_host_with_port() -> void:
	var parts := StartMenu.parse_host("127.0.0.1:7100")
	check_eq(str(parts[0]), "127.0.0.1", "地址")
	check_eq(int(parts[1]), 7100, "端口")
	check_eq(str(StartMenu.parse_host("  127.0.0.1:7100 ")[0]), "127.0.0.1", "两头空格不算地址")


func test_parse_host_without_port() -> void:
	var parts := StartMenu.parse_host("fungi.example.com")
	check_eq(str(parts[0]), "fungi.example.com", "只写地址")
	check_eq(int(parts[1]), Config.SERVER_PORT, "端口用缺省值")
