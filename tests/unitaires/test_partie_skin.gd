extends CasDeTest
## Le skin de tour dans la simulation (T11.5) : un entier opaque rangé avec le joueur. `sim/` ne
## sait pas ce qu'est un skin : il le borne au catalogue (hors catalogue : le skin par défaut,
## index 0), ne le laisse changer qu'au salon, et il ne change rien à la partie.

const GRAINE := 20261126
const NB_SKINS := 5


func _donnees_skins(n: int = NB_SKINS) -> Donnees:
	var brut := AidesPartie.brut()
	var skins: Dictionary = brut["skins_tour.json"]
	for i: int in range(1, n):
		skins["essai_%d" % i] = (skins["defaut"] as Dictionary).duplicate(true)
	return Donnees.depuis_brut(brut)


func _skin_de(p: Partie, id: int) -> int:
	for j: Dictionary in p.vue_globale().joueurs:
		if int(j["id"]) == id:
			return int(j["skin"])
	return -99


func test_les_identifiants_de_skin_suivent_l_ordre_du_fichier() -> void:
	var d := _donnees_skins()
	var ids := d.ids_skins()
	verifier_egal(ids.size(), NB_SKINS)
	verifier_egal(ids[0], "defaut", "le skin par défaut est l'index 0")
	var cles: Array = d.skins_tour.keys()
	for i: int in ids.size():
		verifier_egal(ids[i], String(cles[i]), "index %d" % i)
	verifier_egal(Donnees.charger().ids_skins(), ["defaut"] as Array[String])


func test_un_index_de_skin_hors_catalogue_vaut_le_skin_par_defaut() -> void:
	var d := _donnees_skins()
	var n := d.ids_skins().size()
	for index: int in [-1, 0, n, n + 1, 2147483647]:
		var p := AidesPartie.partie(d, GRAINE, 1, 1.0, false)
		verifier(p.definir_skin(1, index), "index %d accepté" % index)
		verifier_egal(_skin_de(p, 1), 0, "index %d vaut le skin par défaut" % index)


func test_chaque_skin_du_catalogue_est_rendu_tel_quel_dans_la_vue_globale() -> void:
	var d := _donnees_skins()
	for index: int in d.ids_skins().size():
		var p := AidesPartie.partie(d, GRAINE, 2, 1.0, false)
		verifier(p.definir_skin(2, index), "skin %d" % index)
		verifier_egal(_skin_de(p, 2), index, "skin %d rendu" % index)
		verifier_egal(_skin_de(p, 1), 0, "l'autre joueur garde le skin par défaut")


func test_un_joueur_inconnu_est_refuse_et_un_nouveau_a_le_skin_par_defaut() -> void:
	var d := _donnees_skins()
	var p := AidesPartie.partie(d, GRAINE, 1, 1.0, false)
	verifier_faux(p.definir_skin(99, 1), "joueur inconnu")
	verifier_egal(_skin_de(p, 1), 0, "par défaut tant qu'il n'en choisit pas")


func test_le_skin_ne_change_qu_au_salon() -> void:
	var d := _donnees_skins()
	var p := AidesPartie.partie(d, GRAINE, 1, 1.0, false)
	verifier(p.definir_skin(1, 2))
	p.demarrer()
	verifier_faux(p.definir_skin(1, 3), "refusé une fois la partie lancée")
	verifier_egal(_skin_de(p, 1), 2, "le skin choisi au salon reste")


func test_le_skin_ne_change_pas_la_simulation() -> void:
	var d := _donnees_skins()
	var a := AidesPartie.partie(d, GRAINE, 2, 1.0, false)
	var b := AidesPartie.partie(d, GRAINE, 2, 1.0, false)
	a.definir_skin(1, 0)
	a.definir_skin(2, 1)
	b.definir_skin(1, 3)
	b.definir_skin(2, 4)
	a.demarrer()
	b.demarrer()
	AidesPartie.pas(a, 600)
	AidesPartie.pas(b, 600)
	for id: int in [1, 2]:
		var va := a.vue_arene(id, id)
		var vb := b.vue_arene(id, id)
		verifier_non_nul(va)
		verifier_non_nul(vb)
		if va != null and vb != null:
			verifier_egal(va.to_dict(), vb.to_dict(), "arène %d identique" % id)
	var ga := a.vue_globale().to_dict()
	var gb := b.vue_globale().to_dict()
	for g: Dictionary in [ga, gb]:
		for j: Dictionary in g["joueurs"]:
			j.erase("skin")
	verifier_egal(ga, gb, "hors skin, la vue globale est identique")


func test_les_skins_des_defis_ont_chacun_un_identifiant_distinct_du_skin_par_defaut() -> void:
	var d := Donnees.charger()
	var vus: Dictionary = {}
	for id: String in d.defis:
		var skin := String((d.defis[id] as Dictionary)["skin"])
		verifier(not skin.is_empty() and skin != "defaut", "défi %s : skin %s" % [id, skin])
		verifier(not vus.has(skin), "skin %s pris une seule fois" % skin)
		vus[skin] = true
