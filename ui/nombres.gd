class_name Nombres
extends RefCounted
## Mise en forme des nombres affichés : une seule fonction pour le HUD, les scores et la boutique.

## Espace fine insécable : séparateur des milliers à la française, sans rupture de ligne.
const SEPARATEUR_MILLIERS := " "


## Groupe les milliers : 999 999, et jamais de séparateur sous mille.
static func groupe(valeur: int) -> String:
	var chiffres := str(absi(valeur))
	var sortie := ""
	var compte := 0
	for i: int in range(chiffres.length() - 1, -1, -1):
		if compte > 0 and compte % 3 == 0:
			sortie = SEPARATEUR_MILLIERS + sortie
		sortie = chiffres[i] + sortie
		compte += 1
	return "-" + sortie if valeur < 0 else sortie
