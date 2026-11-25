extends CasDeTest
## Le tampon d'événements d'une arène : chaque observateur, avec son propre curseur, reçoit tout ce
## qui est arrivé depuis son dernier envoi, dans l'ordre, par lots d'au plus 64, quelle que soit la
## fréquence à laquelle il vient les chercher ; le tampon reste borné sous une rafale.

const GRAINE := 20261125


func _evenements(n: int, debut: int = 0) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: int in n:
		out.append({"k": "tir", "t": debut + i})
	return out


func _numeros(lot: TamponEvenements.Lot) -> Array[int]:
	var out: Array[int] = []
	for e: Dictionary in lot.evenements:
		out.append(int(e["t"]))
	return out


func test_un_lot_rend_les_evenements_dans_l_ordre_puis_plus_rien() -> void:
	var t := TamponEvenements.new()
	t.ajouter(_evenements(5))
	var lot := t.prendre(0, 64)
	verifier_egal(_numeros(lot), [0, 1, 2, 3, 4] as Array[int])
	verifier_egal(lot.curseur, 5)
	verifier_egal(t.prendre(lot.curseur, 64).evenements.size(), 0, "rien de neuf")
	verifier_egal(t.prendre(lot.curseur, 64).curseur, 5, "le curseur ne bouge pas")


func test_chaque_observateur_recoit_tout_quelle_que_soit_sa_frequence() -> void:
	for observateurs: int in range(2, 9):
		var rng := RandomNumberGenerator.new()
		rng.seed = GRAINE + observateurs
		var t := TamponEvenements.new()
		var curseurs: Array[int] = []
		var recus: Array[int] = []
		var rythmes: Array[int] = []
		for k: int in observateurs:
			curseurs.append(0)
			recus.append(0)
			rythmes.append(1 + k * 3)
		var total := 0
		for pas: int in 400:
			var n := rng.randi_range(0, 2)
			t.ajouter(_evenements(n, total))
			total += n
			for k: int in observateurs:
				if pas % rythmes[k] != 0:
					continue
				var lot := t.prendre(curseurs[k], TamponEvenements.PAR_ENVOI)
				recus[k] += lot.evenements.size()
				curseurs[k] = lot.curseur
		for k: int in observateurs:
			var reste := t.prendre(curseurs[k], 1 << 20)
			verifier_egal(
				recus[k] + reste.evenements.size(),
				total,
				(
					"%d observateurs, rythme %d : tout est reçu, rien en double"
					% [observateurs, rythmes[k]]
				)
			)
		verifier(total > 0)


func test_un_lot_ne_depasse_pas_64_et_le_reste_vient_a_l_envoi_suivant() -> void:
	var t := TamponEvenements.new()
	t.ajouter(_evenements(200))
	var curseur := 0
	var tailles: Array[int] = []
	var vus: Array[int] = []
	while true:
		var lot := t.prendre(curseur, Protocole.MAX_EVENEMENTS)
		if lot.evenements.is_empty():
			break
		tailles.append(lot.evenements.size())
		vus.append_array(_numeros(lot))
		curseur = lot.curseur
	verifier_egal(tailles, [64, 64, 64, 8] as Array[int])
	var attendus: Array[int] = []
	for i: int in 200:
		attendus.append(i)
	verifier_egal(vus, attendus, "dans l'ordre, sans trou")


func test_un_nouvel_observateur_ne_recoit_pas_l_ancien() -> void:
	var t := TamponEvenements.new()
	t.ajouter(_evenements(30))
	var curseur := t.dernier
	verifier_egal(t.prendre(curseur, 64).evenements.size(), 0, "rien d'ancien")
	t.ajouter(_evenements(3, 100))
	verifier_egal(_numeros(t.prendre(curseur, 64)), [100, 101, 102] as Array[int])


func test_le_tampon_reste_borne_sous_une_rafale_et_garde_le_plus_recent() -> void:
	var t := TamponEvenements.new()
	for lot: int in 50:
		t.ajouter(_evenements(1000, lot * 1000))
		verifier(t.taille() <= TamponEvenements.CAPACITE, "taille %d" % t.taille())
	verifier_egal(t.dernier, 50000)
	var lot := t.prendre(0, 1 << 20)
	verifier_egal(lot.evenements.size(), TamponEvenements.CAPACITE)
	verifier_egal(int(lot.evenements[lot.evenements.size() - 1]["t"]), 49999, "le plus récent")
	verifier_egal(lot.curseur, 50000)
	# Un curseur resté très en arrière repart du plus ancien conservé, sans trou ni doublon.
	var suite := t.prendre(lot.curseur, 64)
	verifier_egal(suite.evenements.size(), 0)
