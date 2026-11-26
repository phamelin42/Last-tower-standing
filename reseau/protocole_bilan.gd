class_name ProtocoleBilan
extends RefCounted
## Bilan de partie sur le réseau (protocole version 8) : `u8 type · u16 n · n × f64`, les `n`
## compteurs de `BilanPartie.noms()` dans cet ordre. Un flottant double garde exactement les
## entiers d'or jusqu'à 2⁵³. Tout octet reçu vient d'un tiers : taille, compteur et valeurs sont
## vérifiés avant de rendre quoi que ce soit.


## Les octets du bilan, ou un tableau vide si `bilan` n'est pas un bilan valide (compteur manquant
## ou de trop, valeur non finie ou négative).
static func encoder(bilan: Dictionary) -> PackedByteArray:
	if BilanPartie.depuis_dict(bilan) == null:
		return PackedByteArray()
	var noms := BilanPartie.noms()
	var b := PackedByteArray()
	b.resize(3 + 8 * noms.size())
	b[0] = Protocole.Msg.BILAN
	b.encode_u16(1, noms.size())
	for i: int in noms.size():
		b.encode_double(3 + 8 * i, float(bilan[noms[i]]))
	return b


## Le bilan décodé (nom → valeur), ou `{}` si le paquet est invalide : mauvais type, taille ou
## compteur qui ne correspondent pas, valeur non finie ou négative.
static func decoder(b: PackedByteArray) -> Dictionary:
	var noms := BilanPartie.noms()
	if b.size() != 3 + 8 * noms.size() or b[0] != Protocole.Msg.BILAN:
		return {}
	if b.decode_u16(1) != noms.size():
		return {}
	var bilan: Dictionary = {}
	for i: int in noms.size():
		var x := b.decode_double(3 + 8 * i)
		if not is_finite(x) or x < 0.0:
			return {}
		bilan[noms[i]] = x
	return bilan
