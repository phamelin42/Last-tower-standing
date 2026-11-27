class_name EcrivainOctets
extends RefCounted
## Écrivain à curseur sur un tampon dimensionné une fois ; les valeurs sont bornées au type.
var b: PackedByteArray = PackedByteArray()
var p: int = 0


func _init(capacite: int) -> void:
	b.resize(capacite)


func u8(v: int) -> void:
	b.encode_u8(p, clampi(v, 0, 255))
	p += 1


func i8(v: int) -> void:
	b.encode_s8(p, clampi(v, -128, 127))
	p += 1


func u16(v: int) -> void:
	b.encode_u16(p, clampi(v, 0, 65535))
	p += 2


func i16(v: int) -> void:
	b.encode_s16(p, clampi(v, -32768, 32767))
	p += 2


func u32(v: int) -> void:
	b.encode_u32(p, v & 0xFFFFFFFF)
	p += 4


func i32(v: int) -> void:
	b.encode_s32(p, clampi(v, -2147483648, 2147483647))
	p += 4


func i64(v: int) -> void:
	b.encode_s64(p, v)
	p += 8


func f32(v: float) -> void:
	b.encode_float(p, v)
	p += 4


func octets(brut: PackedByteArray) -> void:
	for i in brut.size():
		b[p + i] = brut[i]
	p += brut.size()


func fin() -> PackedByteArray:
	b.resize(p)
	return b
