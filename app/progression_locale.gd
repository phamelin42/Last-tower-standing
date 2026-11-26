class_name ProgressionLocale
extends RefCounted
## Relie la fin d'une partie à la progression du joueur (D20, B2, B4) : ajoute le bilan à son
## profil, évalue les défis, puis écrit le tout en un seul enregistrement (T11.3). Chaque poste
## évalue **son** bilan, en solo comme en multijoueur ; un serveur dédié n'a pas de joueur et
## n'écrit jamais de fichier.


## Défis nouvellement réussis par cette partie, dans l'ordre du fichier de données. Vide quand il
## n'y a rien à faire (serveur dédié, bilan vide, données absentes) ou quand le profil n'a pas pu
## être écrit : un défi n'est annoncé qu'une fois en place dans le fichier. `nb_joueurs` : joueurs
## de la partie, deux ou plus = multijoueur.
static func enregistrer_fin(
	bilan: Dictionary,
	nb_joueurs: int,
	donnees: Donnees,
	chemin: String = Sauvegarde.CHEMIN_DEFAUT,
	serveur_dedie: bool = false
) -> Array[String]:
	var aucun: Array[String] = []
	if serveur_dedie or bilan.is_empty() or donnees == null:
		return aucun
	var profil := Sauvegarde.charger(chemin)
	if profil.verrouille:
		return aucun
	var nouveaux := Defis.evaluer(bilan, profil, donnees, nb_joueurs >= 2)
	if not Sauvegarde.enregistrer(profil, chemin):
		return aucun
	return nouveaux
