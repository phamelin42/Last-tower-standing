extends CasDeTest
## Retour de partie de Phil (27/11) : « le boss ne se déplaçait pas et n'arrivait pas à
## m'atteindre ».
## Cause mesurée : un étourdissement se prolongeait à chaque coup et un gel revenait après huit
## coups, sans rien qui laisse le boss respirer ; verrouillé, il n'avançait pas et n'attaquait pas.
## Après un étourdissement ou un gel, le boss est immunisé aux deux pendant
## `partie.json` `controle_boss.immunite_s`. Un ennemi ordinaire reste verrouillable.

const DT := 0.05
const ENNEMIS_AUTOUR := 700
const RAYON_TOUR := 60.0
## Un boss libre arrive en (1300 − portée) / vitesse ≈ 23 s. Ici le givre le ralentit sans cesse
## (jusqu'à 56 %) en plus des contrôles : il doit arriver en moins de quatre fois ce temps, alors
## que verrouillé il n'arrivait jamais.
const DELAI_MAX_S := 90.0
## Résistance au contrôle des dernières manches (`difficulte.json`, plancher 0,1).
const RESISTANCE := 0.52

var _d: Donnees


func avant_chaque() -> void:
	_d = AidesPartie.donnees()


func _boss(e: Ennemis, x: float = 1300.0) -> int:
	var b: Dictionary = _d.boss
	return e.ajouter(
		_d.familles.size() + 1,
		Vector2(x, 0.0),
		float(b["pv"]),
		float(b["vitesse"]),
		float(b["degats"]),
		float(b["portee_attaque"]),
		float(b["cadence_attaque"]),
		0,
		Types.Armure.BOSS
	)


func _ordinaire(e: Ennemis, x: float = 1300.0) -> int:
	return e.ajouter(0, Vector2(x, 0.0), 1.0e9, 52.5, 10.0, 45.0, 1.0, 1, Types.Armure.LEGERE)


func _immunite() -> float:
	return float((_d.partie["controle_boss"] as Dictionary)["immunite_s"])


## Secondes avant que `i` soit à portée de la tour, ou -1.0 : les armes étourdissent toutes les
## demi-secondes et givrent deux fois par seconde, comme la partie qui a donné l'alerte, avec la
## résistance au contrôle de la manche du boss (0,52 à la manche 31).
func _arrivee(e: Ennemis, i: int) -> float:
	var portee: float = e.portee[i]
	for pas: int in int(120.0 / DT):
		if pas % 10 == 0:
			e.etourdir(i, 0.6, RESISTANCE)
		if pas % 10 == 5:
			for _k: int in 2:
				e.givrer(i, RESISTANCE)
		e.avancer(DT, Vector2.ZERO, RAYON_TOUR, 1.0, 1.0)
		if e.pos[i].length() <= portee + 0.5:
			return float(pas + 1) * DT
	return -1.0


func test_le_boss_arrive_a_portee_de_la_tour_malgre_700_ennemis_et_des_controles_sans_cesse_renouveles(
) -> void:
	var e := Ennemis.new(_d)
	var boss := _boss(e)
	for k: int in ENNEMIS_AUTOUR:
		var angle := TAU * float(k) / float(ENNEMIS_AUTOUR)
		e.ajouter(
			0,
			Vector2.from_angle(angle) * 150.0,
			1.0e9,
			52.5,
			1.0,
			45.0,
			1.0,
			1,
			Types.Armure.LEGERE
		)
	var arrivee := _arrivee(e, e.indice_de(boss))
	verifier(arrivee > 0.0, "le boss n'arrive jamais à portée en 120 s")
	verifier(
		arrivee <= DELAI_MAX_S,
		"le boss arrive après %.1f s (limite %.0f s)" % [arrivee, DELAI_MAX_S]
	)


func test_un_boss_etourdi_ne_peut_pas_l_etre_de_nouveau_pendant_l_immunite() -> void:
	var e := Ennemis.new(_d)
	var i := e.indice_de(_boss(e))
	e.etourdir(i, 0.6, 1.0)
	verifier(e.etourdi[i] > 0.0, "le premier étourdissement porte")
	# L'étourdissement s'éteint, puis l'immunité court : aucun nouveau coup n'y change rien.
	for _k: int in int(0.7 / DT):
		e.avancer(DT, Vector2.ZERO, RAYON_TOUR, 1.0, 1.0)
	verifier_faux((e.statuts[i] & Types.STATUT_ETOURDI) != 0, "l'étourdissement est fini")
	var t := 0.0
	while t < _immunite() - 0.2:
		e.etourdir(i, 0.6, 1.0)
		verifier_faux((e.statuts[i] & Types.STATUT_ETOURDI) != 0, "étourdi à t=%.2f" % t)
		e.avancer(DT, Vector2.ZERO, RAYON_TOUR, 1.0, 1.0)
		t += DT


func test_un_boss_gele_est_immunise_a_l_etourdissement_et_au_gel_ensuite() -> void:
	var e := Ennemis.new(_d)
	var i := e.indice_de(_boss(e))
	for _k: int in 8:
		e.givrer(i, 1.0)
	verifier((e.statuts[i] & Types.STATUT_GELE) != 0, "huit coups gèlent le boss")
	var pas := 0
	while (e.statuts[i] & Types.STATUT_GELE) != 0 and pas < 400:
		e.avancer(DT, Vector2.ZERO, RAYON_TOUR, 1.0, 1.0)
		pas += 1
	verifier_faux((e.statuts[i] & Types.STATUT_GELE) != 0, "le gel s'éteint")
	e.etourdir(i, 0.6, 1.0)
	for _k: int in 8:
		e.givrer(i, 1.0)
	e.avancer(DT, Vector2.ZERO, RAYON_TOUR, 1.0, 1.0)
	verifier_faux((e.statuts[i] & (Types.STATUT_ETOURDI | Types.STATUT_GELE)) != 0, "immunisé")


func test_apres_l_immunite_le_boss_peut_de_nouveau_etre_controle() -> void:
	var e := Ennemis.new(_d)
	var i := e.indice_de(_boss(e))
	e.etourdir(i, 0.6, 1.0)
	for _k: int in int((0.7 + _immunite() + 0.2) / DT):
		e.avancer(DT, Vector2.ZERO, RAYON_TOUR, 1.0, 1.0)
	e.etourdir(i, 0.6, 1.0)
	verifier(
		(e.statuts[i] & Types.STATUT_ETOURDI) != 0, "le contrôle revient une fois l'immunité finie"
	)


func test_un_ennemi_ordinaire_reste_etourdi_tant_qu_on_le_renouvelle() -> void:
	var e := Ennemis.new(_d)
	var i := e.indice_de(_ordinaire(e))
	for pas: int in int(10.0 / DT):
		if pas % 10 == 0:
			e.etourdir(i, 0.6, 1.0)
		e.avancer(DT, Vector2.ZERO, RAYON_TOUR, 1.0, 1.0)
		verifier((e.statuts[i] & Types.STATUT_ETOURDI) != 0, "libre à t=%.2f" % (float(pas) * DT))
	verifier_proche(e.pos[i].x, 1300.0, 0.001, "il n'a pas bougé")


func test_l_immunite_du_boss_est_une_donnee_positive_validee() -> void:
	verifier(_immunite() > 0.0, "l'immunité est positive")
	for mauvaise: Variant in [0.0, -1.0, 1.0e9, "2", null]:
		var brut := AidesPartie.brut()
		AidesPartie.regler(brut, "partie.json", ["controle_boss", "immunite_s"], mauvaise)
		var messages := Donnees.valider(brut)
		verifier(
			_cite(messages, "controle_boss"), "immunite_s = %s : %s" % [str(mauvaise), messages]
		)
	var brut := AidesPartie.brut()
	(brut["partie.json"] as Dictionary).erase("controle_boss")
	var absent := Donnees.valider(brut)
	verifier(_cite(absent, "controle_boss"), "bloc absent : %s" % [absent])


func _cite(messages: Array[String], bloc: String) -> bool:
	for m: String in messages:
		if m.contains("partie.json") and m.contains(bloc):
			return true
	return false
