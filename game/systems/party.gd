class_name Party

## 同屏双人的会话状态：二号位是谁只活这一次运行，不写盘（存档是单人的）。
## 人类固定占 0..count()-1 号座位，人机从 count() 号往后 —— 各小游戏里
## 「座位号 = 数组下标」的老假设因此不用动。

const NAMES: Array[String] = ["你", "2P"]
const MAX := 2

## {} = 单人；{"body": String, "skin": String} = 二号位的体型和皮肤
static var _second := {}


static func joined() -> bool:
	return not _second.is_empty()


static func count() -> int:
	return MAX if joined() else 1


## 这个座位是不是人在玩。座位号 ≥ count() 的都是人机。
static func human(seat: int) -> bool:
	return seat >= 0 and seat < count()


static func name_of(seat: int) -> String:
	return NAMES[clampi(seat, 0, NAMES.size() - 1)]


static func join(body_id: String, skin_id: String) -> void:
	_second = {"body": BodyCatalog.normalize(body_id), "skin": skin_id}


static func leave() -> void:
	_second = {}


## 第 seat 位玩家该长什么样。一号位读存档，二号位读会话状态。
static func look(seat: int) -> Dictionary:
	if seat <= 0:
		var data := Save.read()
		return {"body": str(data["character"]), "skin": str(data["equipped"])}
	return _second.duplicate()
