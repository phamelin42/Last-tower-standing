class_name ProtocolePoses
extends RefCounted
## Alliés, zones posées et bombes dans l'état d'arène (protocole version 6), sortis de
## `Protocole` pour qu'il tienne sous la limite de lignes de gdlint.
##
## Allié : position (2 × i16) et index d'unité (u8). Zone : position, rayon (u8, par pas de 4),
## temps restant (u8, quarts de seconde), index d'arme du catalogue (u8). Bombe : position,
## rayon, temps restant. Un allié n'a pas d'identifiant sur le réseau : le décodeur lui donne son
## rang dans la liste.
const OCTETS_ALLIE: int = 5
const OCTETS_ZONE: int = 7
const OCTETS_BOMBE: int = 6
const PAS_RAYON_POSE: float = 4.0


## Octets que prennent les alliés, zones et bombes de `v` (les trois compteurs sont dans
## `Protocole.TAILLE_FIXE`).
static func octets(v: VueArene) -> int:
	return (
		OCTETS_ALLIE * v.allies.size()
		+ OCTETS_ZONE * v.zones.size()
		+ OCTETS_BOMBE * v.bombes.size()
	)


## Écrit les trois listes, chacune précédée de son compteur.
static func ecrire(e: Protocole._Ecrivain, v: VueArene) -> void:
	e.u8(v.allies.size())
	for a: Dictionary in v.allies:
		var pos_allie: Vector2 = a["pos"]
		e.i16(Protocole.quantifier(pos_allie.x))
		e.i16(Protocole.quantifier(pos_allie.y))
		e.u8(int(a["unite"]))
	e.u8(v.zones.size())
	for z: Dictionary in v.zones:
		var pos_zone: Vector2 = z["pos"]
		e.i16(Protocole.quantifier(pos_zone.x))
		e.i16(Protocole.quantifier(pos_zone.y))
		e.u8(rayon_pose(float(z["rayon"])))
		e.u8(quarts_u8(float(z["reste"])))
		e.u8(int(z["arme"]))
	e.u8(v.bombes.size())
	for b: Dictionary in v.bombes:
		var pos_bombe: Vector2 = b["pos"]
		e.i16(Protocole.quantifier(pos_bombe.x))
		e.i16(Protocole.quantifier(pos_bombe.y))
		e.u8(rayon_pose(float(b["rayon"])))
		e.u8(quarts_u8(float(b["reste"])))


## Vrai si les alliés, zones et bombes de `v` tiennent dans le format : positions et durées finies,
## index d'unité et d'arme dans leur plage.
static func encodables(v: VueArene, nb_catalogue: int, nb_unites: int) -> bool:
	for a: Dictionary in v.allies:
		var unite := int(a.get("unite", -1))
		if unite < 0 or unite > 255 or (nb_unites >= 0 and unite >= nb_unites):
			return false
		if not _position_finie(a.get("pos")):
			return false
	for z: Dictionary in v.zones:
		var arme := int(z.get("arme", -1))
		if arme < 0 or arme > 255 or arme >= nb_catalogue:
			return false
		if not _pose_finie(z):
			return false
	for b: Dictionary in v.bombes:
		if not _pose_finie(b):
			return false
	return true


static func _position_finie(valeur: Variant) -> bool:
	if typeof(valeur) != TYPE_VECTOR2:
		return false
	var p: Vector2 = valeur
	return is_finite(p.x) and is_finite(p.y)


static func _pose_finie(pose: Dictionary) -> bool:
	if not _position_finie(pose.get("pos")):
		return false
	for cle: String in ["rayon", "reste"]:
		var x: Variant = pose.get(cle)
		if typeof(x) != TYPE_FLOAT or not is_finite(float(x)) or float(x) < 0.0:
			return false
	return true


## Rayon d'une zone ou d'une bombe : un octet, par pas de `PAS_RAYON_POSE`.
static func rayon_pose(x: float) -> int:
	return clampi(roundi(x / PAS_RAYON_POSE), 0, 255)


## Temps restant d'une pose : un octet en quarts de seconde, borné à 63,75 s.
static func quarts_u8(x: float) -> int:
	return clampi(roundi(x * 4.0), 0, 255)


## Lit les alliés, zones et bombes dans `v` ; faux si un compteur dépasse son plafond ou les octets
## restants, ou si un index sort de sa plage.
static func lire(
	l: Protocole.LecteurOctets, v: VueArene, nb_catalogue: int, nb_unites: int
) -> bool:
	var n_allies := l.u8()
	if n_allies > Protocole.MAX_ALLIES or not l.exiger(OCTETS_ALLIE * n_allies):
		return false
	for rang in n_allies:
		var pos := Vector2(l.i16(), l.i16()) / Protocole.ECHELLE_POS
		var unite := l.u8()
		if nb_unites >= 0 and unite >= nb_unites:
			return false
		v.allies.append({"id": rang, "pos": pos, "unite": unite})
	var n_zones := l.u8()
	if n_zones > Protocole.MAX_ZONES or not l.exiger(OCTETS_ZONE * n_zones):
		return false
	for _z in n_zones:
		var pos := Vector2(l.i16(), l.i16()) / Protocole.ECHELLE_POS
		var rayon := float(l.u8()) * PAS_RAYON_POSE
		var reste := float(l.u8()) / 4.0
		var arme := l.u8()
		if arme >= nb_catalogue:
			return false
		v.zones.append({"pos": pos, "rayon": rayon, "reste": reste, "arme": arme})
	var n_bombes := l.u8()
	if n_bombes > Protocole.MAX_BOMBES or not l.exiger(OCTETS_BOMBE * n_bombes):
		return false
	for _b in n_bombes:
		var pos := Vector2(l.i16(), l.i16()) / Protocole.ECHELLE_POS
		var rayon := float(l.u8()) * PAS_RAYON_POSE
		var reste := float(l.u8()) / 4.0
		v.bombes.append({"pos": pos, "rayon": rayon, "reste": reste})
	return l.ok
