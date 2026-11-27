extends CasDeTest
## Un ennemi attaque à la cadence de ses données : N attaques en T secondes = cadence × T, à une
## attaque près. Un temps de recharge remis à zéro à chaque coup (au lieu de garder le reste du pas)
## ralentissait l'archer de 4,4 %, le guerrier de 3,1 % et le dynamiteur de 1,4 % sur 60 s.

const DT := 0.05
const RAYON_TOUR := 60.0
const SECONDES := 60.0
const PORTEE_CORPS_A_CORPS := 60.0

var d: Donnees


func avant_chaque() -> void:
	d = AidesPartie.donnees()


## Attaques portées à la tour en `SECONDES` par un ennemi seul, déjà à portée de tir.
func _attaques(portee: float, degats: float, cadence: float) -> int:
	var e := Ennemis.new(d)
	var arret := portee if portee > PORTEE_CORPS_A_CORPS else RAYON_TOUR + portee
	e.ajouter(0, Vector2(arret, 0), 1.0e9, 0.0, degats, portee, cadence, 1, Types.Armure.AUCUNE)
	var attaques := 0
	for _k: int in roundi(SECONDES / DT):
		var r := e.avancer(DT, Vector2.ZERO, RAYON_TOUR, 1.0, 1.0)
		if float(r["degats_tour"]) > 0.0:
			attaques += 1
	return attaques


func test_chaque_famille_attaque_a_la_cadence_de_ses_donnees() -> void:
	verifier(d.familles.size() > 0)
	for famille: Dictionary in d.familles:
		if bool(famille["explose"]):
			continue
		var cadence := float(famille["cadence_attaque"])
		var n := _attaques(float(famille["portee_attaque"]), float(famille["degats"]), cadence)
		verifier(
			absf(float(n) - cadence * SECONDES) <= 1.0,
			(
				"%s : %d attaques en %.0f s, attendu %.1f"
				% [famille["id"], n, SECONDES, cadence * SECONDES]
			)
		)


func test_le_boss_attaque_a_la_cadence_de_ses_donnees() -> void:
	var boss: Dictionary = d.boss
	var cadence := float(boss["cadence_attaque"])
	var n := _attaques(float(boss["portee_attaque"]), float(boss["degats"]), cadence)
	verifier(
		absf(float(n) - cadence * SECONDES) <= 1.0,
		"boss : %d attaques, attendu %.1f" % [n, cadence * SECONDES]
	)


func test_une_cadence_qui_ne_tombe_pas_juste_sur_un_pas_ne_derive_pas() -> void:
	# 1,3 attaque par seconde : 0,769 s d'intervalle, entre quinze et seize pas.
	for cadence: float in [0.7, 1.3, 1.7, 2.3, 3.1]:
		for portee: float in [40.0, 300.0]:
			var n := _attaques(portee, 5.0, cadence)
			verifier(
				absf(float(n) - cadence * SECONDES) <= 1.0,
				(
					"cadence %s, portée %s : %d attaques, attendu %.1f"
					% [cadence, portee, n, cadence * SECONDES]
				)
			)
