extends CasDeTest
## Qui attaque au contact (Phil, 27/11/2026) : la classe de portée des données (`corps_a_corps`,
## `moyenne`, `longue`), pas un seuil de portée. Le boss, de portée 80, est un corps à corps : les
## épines le touchent comme les autres. Chaque famille et le boss sont éprouvés, en boucle.

const DT := 0.05
const GRAINE := 11
const PV := 100.0
const EPINES := 0.5

var d: Donnees


func avant_chaque() -> void:
	d = Donnees.charger()
	(d.partie["tour"] as Dictionary)["pv"] = 1.0e12


func _arene_avec_epines() -> Arene:
	var a := Arene.new(d, GRAINE)
	d.ameliorations["essai_epines"] = {
		"id": "essai_epines",
		"nom": "essai",
		"description": "essai",
		"rarete": Types.Rarete.COMMUNE,
		"prix": 1,
		"categorie": Types.Categorie.AMELIORATION,
		"famille": "epines",
		"effets": [{"stat": "epines", "valeur": EPINES}],
	}
	a.inventaire.ameliorations["essai_epines"] = 1
	a.synchroniser()
	return a


func _mult() -> Dictionary:
	return {"pv": PV, "degats": 20.0, "vitesse": 0.0, "resistance_controle": 1.0}


## L'ennemi seul de la famille `f` (ou du boss si `f` est l'index suivant le convoi), vivant.
func _faire_venir(a: Arene, f: int) -> int:
	if f > d.familles.size():
		a.demarrer_boss(_mult())
	else:
		a.demarrer_manche(1, Composition.unique(f), _mult())
		for _i: int in 2000:
			if a.nombre_ennemis() > 0:
				break
			a.avancer(DT)
	verifier_egal(a.nombre_ennemis(), 1, "un seul ennemi est venu")
	return a.ennemis.ids[0]


func _classe(f: int) -> int:
	if f > d.familles.size():
		return Types.NOMS_CLASSES_PORTEE.find(String(d.boss["classe_portee"]))
	return int((d.familles[f] as Dictionary)["classe_portee"])


func _portee(f: int) -> float:
	if f > d.familles.size():
		return float(d.boss["portee_attaque"])
	return float((d.familles[f] as Dictionary)["portee_attaque"])


func _explose(f: int) -> bool:
	return f <= d.familles.size() and bool((d.familles[f] as Dictionary).get("explose", false))


func _rayon_tour() -> float:
	return float((d.partie["tour"] as Dictionary)["rayon"])


func test_le_boss_est_un_corps_a_corps_dans_les_donnees() -> void:
	verifier_egal(String(d.boss["classe_portee"]), "corps_a_corps", "classe du boss")
	verifier(
		float(d.boss["portee_attaque"]) > Ennemis.PORTEE_CORPS_A_CORPS,
		"contrôle : sa portée dépasse le seuil des autres corps à corps"
	)


func test_chaque_ennemi_se_comporte_selon_sa_classe_de_portee() -> void:
	# Familles, puis boss (l'index du convoi est sauté).
	var types: Array[int] = []
	for f: int in d.familles.size():
		types.append(f)
	types.append(d.familles.size() + 1)
	var au_contact := 0
	for f: int in types:
		var classe := _classe(f)
		verifier(classe >= 0, "type %d : classe lue dans les données" % f)
		var a := _arene_avec_epines()
		var id := _faire_venir(a, f)
		var i := a.ennemis.indice_de(id)
		var attendu_contact := classe == Types.ClassePortee.CORPS_A_CORPS
		verifier_egal(a.ennemis.contact[i] != 0, attendu_contact, "type %d : classe retenue" % f)
		if attendu_contact:
			au_contact += 1
		var arret := _rayon_tour() + _portee(f) if attendu_contact else _portee(f)
		a.ennemis.pos[i] = Vector2(arret, 0.0)
		for _k: int in 3:
			a.avancer(DT)
		if _explose(f):
			continue
		i = a.ennemis.indice_de(id)
		var subi := a.ennemis.pv_max[i] - a.ennemis.pv[i]
		if attendu_contact:
			verifier(subi > 0.0, "type %d : les épines le touchent" % f)
		else:
			verifier_egal(subi, 0.0, "type %d : de loin, les épines ne le touchent pas" % f)
	verifier(au_contact > 1, "des corps à corps parmi les familles et le boss")


func test_le_boss_s_arrete_au_bord_de_la_tour_comme_un_corps_a_corps() -> void:
	var a := _arene_avec_epines()
	var id := _faire_venir(a, d.familles.size() + 1)
	a.ennemis.pos[a.ennemis.indice_de(id)] = Vector2(1300.0, 0.0)
	a.ennemis.vitesse[a.ennemis.indice_de(id)] = 5000.0
	for _k: int in 200:
		a.avancer(DT)
	var distance := a.ennemis.pos[a.ennemis.indice_de(id)].length()
	verifier_proche(
		distance, _rayon_tour() + float(d.boss["portee_attaque"]), Ennemis.TOLERANCE_ARRET, "arrêt"
	)
