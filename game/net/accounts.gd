class_name Accounts

## 服务器上的账号：存档目录下一个账号一个 JSON。口令只以派生密钥的形式存在。
## 写盘一律先写 .tmp 再 rename —— 半截文件等于账号报废。
## 昵称直接进文件名，所以它是信任边界：不合法的名字一律拒，别指望上层过滤。

const MIN_NAME := 1
const MAX_NAME := 16
const MIN_PASSWORD := 4
const BAD_CHARS := ["/", "\\", ":", "*", "?", "\"", "<", ">", "|", "\n", "\r", "\t", " "]


static func valid_name(name: String) -> bool:
	if name.length() < MIN_NAME or name.length() > MAX_NAME:
		return false
	if name.begins_with("."):
		return false
	for c in BAD_CHARS:
		if name.contains(c):
			return false
	return true


static func path_for(dir: String, name: String) -> String:
	return dir.path_join("%s.json" % name)


static func exists(dir: String, name: String) -> bool:
	return FileAccess.file_exists(path_for(dir, name))


## 读整条记录（含 salt / key，别发给客户端）。不存在或文件坏了都返回空字典。
static func load_record(dir: String, name: String) -> Dictionary:
	var file := FileAccess.open(path_for(dir, name), FileAccess.READ)
	if file == null:
		return {}
	var raw: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	return raw as Dictionary


## 登录第一步：这个名字存在吗？不存在就发一份新盐让客户端注册。
static func challenge(dir: String, name: String) -> Dictionary:
	if not valid_name(name):
		return {"ok": false, "error": "name"}
	var record := load_record(dir, name)
	if record.is_empty():
		return {"ok": true, "exists": false, "salt": NetAuth.hex(NetAuth.salt())}
	return {"ok": true, "exists": true, "salt": str(record.get("salt", ""))}


## 注册：盐和派生密钥都是刚刚这条连接上握手换来的，服务器只负责存。
static func register(dir: String, name: String, salt_hex: String, key_hex: String) -> Dictionary:
	if not valid_name(name):
		return {"ok": false, "error": "name"}
	if NetAuth.unhex(salt_hex).is_empty() or NetAuth.unhex(key_hex).is_empty():
		return {"ok": false, "error": "auth"}
	if exists(dir, name):
		return {"ok": false, "error": "taken"}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var record := {"salt": salt_hex, "key": key_hex, "save": Save.defaults()}
	_store(dir, name, record)
	return {"ok": true}


## 登录验证：拿服务器存的派生密钥和这次连接的 nonce 重算一遍 proof。
static func verify(dir: String, name: String, proof_hex: String, nonce_hex: String) -> bool:
	var record := load_record(dir, name)
	if record.is_empty():
		return false
	var key := NetAuth.unhex(str(record.get("key", "")))
	var nonce := NetAuth.unhex(nonce_hex)
	var got := NetAuth.unhex(proof_hex)
	if key.is_empty() or nonce.is_empty() or got.is_empty():
		return false
	return NetAuth.proof(key, nonce) == got


## 存档字典。账号不存在时回一份缺省值，客户端不至于因为读了空档崩掉。
static func read(dir: String, name: String) -> Dictionary:
	var record := load_record(dir, name)
	if record.is_empty():
		return Save.defaults()
	return Save.normalize(record.get("save", {}))


static func write(dir: String, name: String, data: Dictionary) -> void:
	var record := load_record(dir, name)
	if record.is_empty():
		return
	# 只改传入的键：和本地存档一样，别让一次买皮肤顺手把体力和天色抹回缺省
	var save := Save.normalize(record.get("save", {}))
	for key in data:
		save[key] = data[key]
	record["save"] = Save.normalize(save)
	_store(dir, name, record)


static func _store(dir: String, name: String, record: Dictionary) -> void:
	var path := ProjectSettings.globalize_path(path_for(dir, name))
	var tmp := path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		push_error("账号文件写不进去：%s" % tmp)
		return
	file.store_string(JSON.stringify(record))
	file.close()
	DirAccess.rename_absolute(tmp, path)


## 只给测试和运维用：把口令变成一条记录所需的两段 hex。
static func credentials(password: String, salt_hex: String) -> Dictionary:
	var salt_bytes := NetAuth.unhex(salt_hex)
	var key := NetAuth.derive(password, salt_bytes)
	return {"salt": salt_hex, "key": NetAuth.hex(key), "key_bytes": key}
