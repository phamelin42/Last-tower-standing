class_name Defis
extends RefCounted
## Évaluation des défis à la fin d'une partie (`docs/defis.md`, D20) : le bilan s'ajoute d'abord
## aux cumuls du profil, puis chaque défi pas encore réussi lit un compteur du bilan ou du profil.
## Cosmétique et non vérifié (B2) : rien ici ne touche à la simulation.


## Ajoute `bilan` (nom → valeur, `BilanPartie`) au `profil`, puis rend les identifiants des défis
## **nouvellement** réussis, dans l'ordre du fichier. Chacun est ajouté au profil avec son skin ;
## un défi déjà réussi ne l'est jamais deux fois. `multijoueur` : la partie a compté au moins
## deux joueurs ; un défi « multijoueur » ne se valide pas en solo.
static func evaluer(
	bilan: Dictionary, profil: Profil, donnees: Donnees, multijoueur: bool = false
) -> Array[String]:
	profil.ajouter_bilan(bilan, multijoueur)
	var valeurs := bilan.duplicate()
	valeurs["parties"] = profil.parties
	for cle: String in Profil.BORNES_CUMULS:
		valeurs[cle] = profil.get(cle)
	var nouveaux: Array[String] = []
	for id: String in donnees.defis:
		var defi: Dictionary = donnees.defis[id]
		if profil.defis_reussis.has(id):
			continue
		if defi["mode"] == "multijoueur" and not multijoueur:
			continue
		var termes: Array[Dictionary] = []
		termes.assign(defi["termes"] as Array)
		if not DonneesProgression.condition_tenue(termes, valeurs):
			continue
		profil.defis_reussis.append(id)
		if not profil.skins_debloques.has(defi["skin"]):
			profil.skins_debloques.append(defi["skin"])
		nouveaux.append(id)
	profil.normaliser()
	return nouveaux
