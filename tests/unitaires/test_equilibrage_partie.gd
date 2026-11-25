extends CasDeTest
## Garde de l'équilibrage : un joueur qui ne fait rien doit tomber tôt, un joueur raisonnable doit
## aller loin. Les seuils sont bien en deçà de la cible mesurée par `tools/equilibrage.gd` (passif
## vers la manche 5, raisonnable vers la 19) : ils attrapent une régression franche, pas un réglage
## fin. Le détail chiffré est dans `docs/equilibrage.md`.

const GRAINES: Array[int] = [1, 2, 3, 4, 5]
const MANCHE_MEDIANE_RAISONNABLE_MIN := 12
const MANCHE_PASSIVE_MAX := 8


func _manches(strategie: String) -> Array[int]:
	var d := AidesPartie.donnees()
	var manches: Array[int] = []
	for graine: int in GRAINES:
		var r := SimulationEquilibrage.jouer(d, graine, strategie, MANCHE_MEDIANE_RAISONNABLE_MIN)
		manches.append(int(r["manche"]))
	manches.sort()
	return manches


func test_un_joueur_passif_tombe_avant_la_manche_huit_sur_chaque_graine() -> void:
	var manches := _manches(StrategiesJoueur.PASSIVE)
	for manche: int in manches:
		verifier(
			manche < MANCHE_PASSIVE_MAX, "le joueur passif a tenu jusqu'à la manche %d" % manche
		)


func test_un_joueur_raisonnable_atteint_au_moins_la_manche_douze_en_mediane() -> void:
	var manches := _manches(StrategiesJoueur.RAISONNABLE)
	var mediane := manches[manches.size() / 2]
	verifier(
		mediane >= MANCHE_MEDIANE_RAISONNABLE_MIN,
		"médiane %d (manches %s) sous %d" % [mediane, manches, MANCHE_MEDIANE_RAISONNABLE_MIN]
	)
