class_name DonneesEfficacite
extends RefCounted
## Validation de `data/efficacite.json` (matrice type de dégâts × armure). Séparé de `Donnees` pour
## tenir sous la limite de taille d'un fichier ; les briques de validation sont celles de `Donnees`.


static func valider(e: Dictionary, err: Array[String]) -> void:
	var f := "efficacite.json"
	Donnees._noms_ordonnes(e, "lignes", Types.NOMS_TYPES, f, err)
	Donnees._noms_ordonnes(e, "colonnes", Types.NOMS_ARMURES, f, err)
	if not Donnees._tableau(e, "valeurs", f, "", err):
		return
	var valeurs: Array = e["valeurs"]
	if valeurs.size() != Types.NOMS_TYPES.size():
		var raison := "%d lignes attendues, reçu %d" % [Types.NOMS_TYPES.size(), valeurs.size()]
		Donnees._err(err, f, "valeurs", raison)
	for i in valeurs.size():
		var chemin := "valeurs[%d]" % i
		var ligne: Variant = valeurs[i]
		if not ligne is Array:
			Donnees._err(err, f, chemin, "attendu un tableau, reçu %s" % Donnees._decrire(ligne))
			continue
		var cases: Array = ligne
		if cases.size() != Types.NOMS_ARMURES.size():
			var raison := (
				"%d colonnes attendues, reçu %d" % [Types.NOMS_ARMURES.size(), cases.size()]
			)
			Donnees._err(err, f, chemin, raison)
		for j in cases.size():
			var valeur: Variant = cases[j]
			if not Donnees._est_nombre(valeur) or float(valeur) < 0.0:
				Donnees._err(
					err,
					f,
					"%s[%d]" % [chemin, j],
					"nombre ≥ 0 attendu, reçu %s" % Donnees._decrire(valeur)
				)
