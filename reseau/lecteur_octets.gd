class_name LecteurOctets
extends RefCounted
## Lecteur à curseur : toute lecture hors des octets disponibles passe `ok` à faux et renvoie 0,
## sans jamais appeler `decode_*` hors bornes.
var b: PackedByteArray
var p: int = 0
var ok: bool = true


func _init(octets: PackedByteArray) -> void:
	b = octets


func reste() -> int:
	return b.size() - p


func exiger(n: int) -> bool:
	if n < 0 or n > reste():
		ok = false
		return false
	return true


func u8() -> int:
	if not exiger(1):
		return 0
	p += 1
	return b[p - 1]


func i8() -> int:
	if not exiger(1):
		return 0
	p += 1
	return b.decode_s8(p - 1)


func u16() -> int:
	if not exiger(2):
		return 0
	p += 2
	return b.decode_u16(p - 2)


func i16() -> int:
	if not exiger(2):
		return 0
	p += 2
	return b.decode_s16(p - 2)


func u32() -> int:
	if not exiger(4):
		return 0
	p += 4
	return b.decode_u32(p - 4)


func i32() -> int:
	if not exiger(4):
		return 0
	p += 4
	return b.decode_s32(p - 4)


func i64() -> int:
	if not exiger(8):
		return 0
	p += 8
	return b.decode_s64(p - 8)


## Flottant 32 bits ; NaN et infinis sont refusés.
func f32() -> float:
	if not exiger(4):
		return 0.0
	p += 4
	var x := b.decode_float(p - 4)
	if is_nan(x) or is_inf(x):
		ok = false
		return 0.0
	return x


## `n` octets UTF-8 valides, sans caractère de contrôle, d'au plus `max_caracteres`.
func texte(n: int, max_caracteres: int) -> String:
	if not exiger(n):
		return ""
	var brut := b.slice(p, p + n)
	p += n
	# Un octet de contrôle (dont NUL, que le décodeur de Godot prendrait pour une fin).
	for c in brut:
		if c < 32 or c == 127:
			ok = false
			return ""
	if not Protocole._utf8_valide(brut):
		ok = false
		return ""
	var s := brut.get_string_from_utf8()
	if s.length() > max_caracteres or not Protocole._texte_sain(s):
		ok = false
		return ""
	return s
