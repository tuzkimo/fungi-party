extends TestBase

## 口令派生是登录的唯一凭据来源：同口令同盐必须一样，换一样就不一样。

var SALT_A := PackedByteArray([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16])
var SALT_B := PackedByteArray([9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9])
var NONCE := PackedByteArray([7, 7, 7, 7])


func test_derive_is_stable() -> void:
	var a := NetAuth.derive("mushroom", SALT_A)
	var b := NetAuth.derive("mushroom", SALT_A)
	check_eq(a, b, "同口令同盐派生相同")
	check_eq(a.size(), NetAuth.KEY_LEN, "派生密钥 32 字节")


func test_salt_and_password_both_matter() -> void:
	check(NetAuth.derive("mushroom", SALT_A) != NetAuth.derive("mushroom", SALT_B), "换盐要变")
	check(NetAuth.derive("mushroom", SALT_A) != NetAuth.derive("mushroom!", SALT_A), "换口令要变")
	check(NetAuth.derive("", SALT_A) != NetAuth.derive("mushroom", SALT_A), "空口令也要算出一个值")


func test_proof_depends_on_nonce() -> void:
	var key := NetAuth.derive("mushroom", SALT_A)
	var p := NetAuth.proof(key, NONCE)
	check_eq(p, NetAuth.proof(key, NONCE), "同 nonce 同 proof")
	check(p != NetAuth.proof(key, PackedByteArray([7, 7, 7, 8])), "换 nonce 换 proof")
	check(p != NetAuth.proof(NetAuth.derive("other", SALT_A), NONCE), "换密钥换 proof")


func test_hex_roundtrip() -> void:
	var bytes := NetAuth.derive("菌子", SALT_A)
	var text := NetAuth.hex(bytes)
	check_eq(text.length(), NetAuth.KEY_LEN * 2, "hex 长度是字节的两倍")
	check_eq(NetAuth.unhex(text), bytes, "hex 往返一致")
	check_eq(NetAuth.unhex(""), PackedByteArray(), "空串解出空")
	check_eq(NetAuth.unhex("abc"), PackedByteArray(), "奇数长度拒绝")
	check_eq(NetAuth.unhex("zz"), PackedByteArray(), "非 hex 拒绝")
	check_eq(NetAuth.unhex("0g"), PackedByteArray(), "半 hex 拒绝")
	check_eq(NetAuth.unhex("0A"), PackedByteArray([10]), "大写也认")


func test_random_bytes_shape() -> void:
	check_eq(NetAuth.salt().size(), NetAuth.SALT_LEN, "盐 16 字节")
	check(NetAuth.salt() != NetAuth.salt(), "两次盐不一样")
