extends CasDeTest
## Ce que la joueuse lit : un nombre groupé par milliers à la française (espace fine insécable),
## jamais de séparateur sous mille, le signe devant. Le HUD, le tableau des scores et la boutique
## partagent cette seule fonction.

const ESPACE := " "


func test_nombre_sans_separateur_jusqu_a_999() -> void:
	for n: int in range(0, 1000):
		verifier_egal(Nombres.groupe(n), str(n), "pour %d" % n)


func test_nombre_groupe_par_milliers_avec_espace_fine() -> void:
	verifier_egal(Nombres.groupe(1000), "1" + ESPACE + "000")
	verifier_egal(Nombres.groupe(999999), "999" + ESPACE + "999")
	verifier_egal(Nombres.groupe(1234567), "1" + ESPACE + "234" + ESPACE + "567")


func test_nombre_negatif_garde_son_signe_devant() -> void:
	verifier_egal(Nombres.groupe(-5), "-5")
	verifier_egal(Nombres.groupe(-1500), "-1" + ESPACE + "500")
