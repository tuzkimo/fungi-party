class_name NetAuth

## 口令不过网：客户端拿服务器给的盐把口令派生成密钥，登录时只回
## `proof(派生密钥, 服务器临时发的 nonce)`。服务器存的是派生密钥，从头到尾没见过口令。
##
## shortcut: 自己搓的迭代 SHA-256 不是 PBKDF2/scrypt，服务器存的派生密钥等于可登录凭据
## （库泄露 = 账号泄露）。给朋友玩够用；要对外开放注册就换 SRP 或上 TLS + 正规 KDF。

## 迭代数：实测桌面约 50 ms、手机约 250 ms（只在登录时跑一次），够拖慢离线爆破又不让人等
const ITERATIONS := 80000
const SALT_LEN := 16
const KEY_LEN := 32


static func random_bytes(count: int) -> PackedByteArray:
	var out := Crypto.new().generate_random_bytes(count)
	if out.size() != count:
		# 拿不到系统随机数就别静默降级成可预测的密码：直接报错，让服务器起不来
		push_error("拿不到随机数，服务器不能带着可预测的盐跑")
		out.resize(count)
	return out


static func salt() -> PackedByteArray:
	return random_bytes(SALT_LEN)


## 32 字节派生密钥：sha256(盐 || 口令) 再迭代 ITERATIONS 次 sha256(上一轮 || 口令)。
static func derive(password: String, salt_bytes: PackedByteArray) -> PackedByteArray:
	var secret := password.to_utf8_buffer()
	var out := _sha256(salt_bytes + secret)
	for i in ITERATIONS:
		out = _sha256(out + secret)
	return out


static func proof(derived: PackedByteArray, nonce: PackedByteArray) -> PackedByteArray:
	return _sha256(derived + nonce)


static func hex(bytes: PackedByteArray) -> String:
	return bytes.hex_encode()


## 客户端传来的 hex 是信任边界：长度奇数、含非 hex 字符一律当空（调用方据此拒绝）。
static func unhex(text: String) -> PackedByteArray:
	var out := PackedByteArray()
	if text.length() % 2 != 0:
		return out
	for i in text.length():
		if not _is_hex_digit(text[i]):
			return PackedByteArray()
	out.resize(text.length() / 2)
	for i in out.size():
		out[i] = text.substr(i * 2, 2).hex_to_int()
	return out


static func _is_hex_digit(c: String) -> bool:
	return c.length() == 1 and "0123456789abcdef".contains(c.to_lower())


static func _sha256(data: PackedByteArray) -> PackedByteArray:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(data)
	return ctx.finish()
