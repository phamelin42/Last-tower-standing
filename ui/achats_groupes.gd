class_name AchatsGroupes
extends RefCounted
## Les achats groupés de la boutique (S28, Phil 27/11) : le choix de « Tout acheter » et la touche
## affichée sur chaque bouton. Pure lecture d'une `VueArene` : l'achat lui-même passe par les
## intentions de la simulation, une par offre.


## Les indices d'offres que « Tout acheter » achète : celles qui ne sont pas vendues, par prix
## croissant (à prix égal, l'ordre d'affichage), tant que l'or restant les paie. Une arme nouvelle
## est écartée quand les huit emplacements sont pleins : la simulation la refuserait, et son prix
## ne doit pas réduire l'or compté pour les suivantes.
static func ordre_tout_acheter(vue: VueArene) -> Array[int]:
	var candidates: Array[int] = []
	for i: int in vue.offres.size():
		var offre: Dictionary = vue.offres[i]
		if offre.is_empty() or bool(offre["vendu"]):
			continue
		if int(offre["genre"]) == Types.Genre.ARME and vue.armes.size() >= Inventaire.ARMES_MAX:
			var porte := false
			for arme: Dictionary in vue.armes:
				porte = porte or str(arme["id"]) == str(offre["id"])
			if not porte:
				continue
		candidates.append(i)
	candidates.sort_custom(
		func(a: int, b: int) -> bool:
			var pa: int = vue.offres[a]["prix"]
			var pb: int = vue.offres[b]["prix"]
			return pa < pb or (pa == pb and a < b)
	)
	var achats: Array[int] = []
	var reste: int = vue.argent
	for i: int in candidates:
		var prix: int = vue.offres[i]["prix"]
		if prix <= reste:
			reste -= prix
			achats.append(i)
	return achats


## La touche liée à `action`, lue dans la table d'entrées (la lectrice peut la changer) ; vide
## quand l'action n'a pas de touche.
static func touche_de(action: String) -> String:
	if not InputMap.has_action(action):
		return ""
	for evenement: InputEvent in InputMap.action_get_events(action):
		if evenement is InputEventKey:
			return (evenement as InputEventKey).as_text_physical_keycode()
	return ""
