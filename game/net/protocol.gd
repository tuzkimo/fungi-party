class_name NetProtocol

## 上下行只有一个信封：{v: 协议版本, t: 消息类型, b: 消息体}。
## 用 Godot 自带的 var_to_bytes / bytes_to_var 序列化，不手写编解码。
## 服务器和客户端共用这一份，VERSION 不一致直接拒连——两边的数据结构差一个字段就会跑出诡异状态。

const VERSION := 5
## 一封存档带 15 顶皮肤 id 大约 1 KB，8 KB 已经是很宽松的天花板
const MAX_PACKET := 8192

enum Msg {
	HELLO, CHALLENGE, PROOF, WELCOME, OP, OP_RESULT, ERROR,
	MOVE,   # 客户端 → 服务器：我在哪、朝哪、长什么样
	WORLD,  # 服务器 → 客户端：这座森林里现在有谁、几点、有没有人邀请我
	SESSION,  # 服务器 → 客户端：我所在那一局的快照（座位、时钟、结算）
	INPUT,    # 客户端 → 服务器：局内输入，只说「我按着」，结果由服务器算
}


static func pack(kind: int, body: Dictionary) -> PackedByteArray:
	var bytes := var_to_bytes({"v": VERSION, "t": kind, "b": body})
	if bytes.size() > MAX_PACKET:
		return PackedByteArray()
	return bytes


## 任何一处不对都返回 ok=false：调用方记一行日志就丢包，不要继续往下解析。
static func unpack(packet: PackedByteArray) -> Dictionary:
	if packet.size() == 0 or packet.size() > MAX_PACKET:
		return {"ok": false, "reason": "size"}
	var raw: Variant = bytes_to_var(packet)
	if typeof(raw) != TYPE_DICTIONARY:
		return {"ok": false, "reason": "garbage"}
	var env := raw as Dictionary
	if not (env.has("v") and env.has("t") and env.has("b")):
		return {"ok": false, "reason": "garbage"}
	if int(env["v"]) != VERSION:
		return {"ok": false, "reason": "version"}
	if typeof(env["b"]) != TYPE_DICTIONARY:
		return {"ok": false, "reason": "garbage"}
	return {"ok": true, "kind": int(env["t"]), "body": env["b"]}
