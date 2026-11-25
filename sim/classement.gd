class_name Classement
extends RefCounted
## Classement de fin de partie et mention « Dernier rempart », en fonctions pures.
##
## Une entrée : {id, manche (atteinte), degats (infligés), pas_fin (pas global où le joueur est
## sorti), cause}. L'appelant ne passe que les joueurs qui ont atteint une manche.

enum Cause { DEFAITE, DECONNEXION, VICTOIRE }


## Manche atteinte (la plus haute d'abord), puis victoire, puis dégâts infligés, puis identifiant :
## deux joueurs tombés au même pas se classent donc toujours de la même façon.
static func ordonner(entrees: Array[Dictionary]) -> Array[int]:
	var copie := entrees.duplicate()
	copie.sort_custom(_avant)
	var ids: Array[int] = []
	for e: Variant in copie:
		var entree: Dictionary = e
		ids.append(int(entree["id"]))
	return ids


## Le dernier à tomber, s'il est tombé seul (pas d'ex æquo au dernier pas), sous les coups de
## l'ennemi (pas parti de lui-même), après au moins un autre joueur, et si personne n'a vaincu le
## boss (le survivant est alors le vainqueur, pas un rempart). Sinon −1.
static func dernier_rempart(entrees: Array[Dictionary]) -> int:
	if entrees.size() < 2:
		return -1
	var dernier_pas := -1
	var nb_au_dernier_pas := 0
	var candidat: Dictionary = {}
	for entree: Dictionary in entrees:
		if int(entree["cause"]) == Cause.VICTOIRE:
			return -1
		var pas := int(entree["pas_fin"])
		if pas > dernier_pas:
			dernier_pas = pas
			nb_au_dernier_pas = 1
			candidat = entree
		elif pas == dernier_pas:
			nb_au_dernier_pas += 1
	if nb_au_dernier_pas != 1 or int(candidat["cause"]) != Cause.DEFAITE:
		return -1
	return int(candidat["id"])


static func _avant(a: Dictionary, b: Dictionary) -> bool:
	var ma := int(a["manche"])
	var mb := int(b["manche"])
	if ma != mb:
		return ma > mb
	# À la manche du boss, celui qui l'a vaincu passe devant celui qui y est tombé, quels que
	# soient les dégâts.
	var va := int(a["cause"]) == Cause.VICTOIRE
	var vb := int(b["cause"]) == Cause.VICTOIRE
	if va != vb:
		return va
	var da := float(a["degats"])
	var db := float(b["degats"])
	if da != db:
		return da > db
	return int(a["id"]) < int(b["id"])
