extends CasDeTest
## Ce que le joueur lit pour une rareté ou une armure existe dans le fichier de textes : une
## clé renvoyée par `Apparence` sans ligne dans le CSV afficherait le nom brut de la clé.

const CHEMIN := "res://i18n/textes_communs.csv"


func test_entete_du_csv_est_keys_fr() -> void:
	var fichier := FileAccess.open(CHEMIN, FileAccess.READ)
	verifier_non_nul(fichier, "le CSV doit s'ouvrir")
	if fichier == null:
		return
	verifier_egal(fichier.get_line(), "keys,fr")


func test_chaque_rarete_a_un_libelle_dans_le_csv() -> void:
	var textes := CsvTextes.lire(CHEMIN)
	for r: int in Types.Rarete.size():
		var cle := Apparence.cle_libelle_rarete(r)
		verifier(not cle.is_empty(), "rareté %d sans clé" % r)
		verifier(textes.has(cle), "clé absente du CSV : %s" % cle)
		verifier(not String(textes.get(cle, "")).is_empty(), "texte vide pour %s" % cle)


func test_chaque_armure_a_un_libelle_dans_le_csv() -> void:
	var textes := CsvTextes.lire(CHEMIN)
	for a: int in Types.Armure.size():
		var cle := Apparence.cle_libelle_armure(a)
		verifier(not cle.is_empty(), "armure %d sans clé" % a)
		verifier(textes.has(cle), "clé absente du CSV : %s" % cle)
		verifier(not String(textes.get(cle, "")).is_empty(), "texte vide pour %s" % cle)


func test_un_texte_avec_virgule_est_entre_guillemets_et_lu_en_entier() -> void:
	verifier_egal(CsvTextes._champs('a,"b, c"'), PackedStringArray(["a", "b, c"]))
