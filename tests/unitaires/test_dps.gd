extends CasDeTest
## Dégâts par seconde d'une arène : moyenne glissante des 10 dernières secondes, épines comprises.

const DT := 0.05
const GRAINE := 77
const PV_ENORMES := 1.0e9

var d: Donnees


func avant_chaque() -> void:
	d = Donnees.charger()


# --- Aides -------------------------------------------------------------------------------------


func _avancer(a: Arene, pas: int) -> void:
	for _i: int in pas:
		a.avancer(DT)


## Une lame de 10 dégâts toutes les `recharge` secondes, face à un ennemi immobile, énorme et
## sans armure.
func _arene_avec_lame(recharge: float) -> Arene:
	var a := Arene.new(d, GRAINE)
	var def: Dictionary = (d.armes["lame_de_fil"] as Dictionary).duplicate(true)
	def["degats"] = 10.0
	def["recharge"] = recharge
	a.armes.append(ArmeEquipee.new(def))
	a.ennemis.ajouter(0, Vector2(100, 0), PV_ENORMES, 0.0, 0.0, 0.0, 0.0, 0, Types.Armure.AUCUNE)
	return a


# --- Tests -------------------------------------------------------------------------------------


func test_le_dps_est_la_moyenne_glissante_des_10_dernieres_secondes() -> void:
	var a := _arene_avec_lame(1.0)
	_avancer(a, 200)
	verifier_proche(a.dps(), 10.0, 1.0, "10 dégâts par seconde après 10 s")
	_avancer(a, 200)
	verifier_proche(a.dps(), 10.0, 1.0, "toujours 10 après 20 s : la fenêtre glisse")


func test_avant_10_s_on_divise_par_le_temps_ecoule() -> void:
	var a := _arene_avec_lame(1.0)
	_avancer(a, 100)
	verifier_proche(a.dps(), 10.0, 1.5, "5 s de tir : 10 par seconde, pas 5")


func test_les_degats_hors_de_la_fenetre_ne_comptent_plus() -> void:
	var a := _arene_avec_lame(1000.0)
	_avancer(a, 1)
	verifier(a.dps() > 0.0, "le coup du départ compte")
	_avancer(a, 209)
	verifier_egal(a.dps(), 0.0, "à 10,5 s le coup de t = 0 est sorti de la fenêtre")


func test_les_epines_comptent_dans_le_dps() -> void:
	var a := Arene.new(d, GRAINE)
	a.inventaire.ameliorations["couronne_d_epines"] = 1
	a.synchroniser()
	a.ennemis.ajouter(0, Vector2(100, 0), 1000.0, 0.0, 10.0, 40.0, 1.0, 0, Types.Armure.AUCUNE)
	_avancer(a, 100)
	verifier(a.dps() > 0.0, "un ennemi qui frappe la tour se blesse sur ses épines")


func test_le_dps_vaut_zero_au_depart_et_n_est_jamais_nan() -> void:
	var a := Arene.new(d, GRAINE)
	verifier_egal(a.dps(), 0.0, "avant tout pas")
	_avancer(a, 5)
	verifier_egal(a.dps(), 0.0, "sans arme ni ennemi")
	verifier(is_finite(a.dps()), "fini")


func test_la_vue_globale_porte_le_dps_de_chaque_joueur() -> void:
	var p := AidesPartie.partie(d, GRAINE, 2)
	var a1: Arene = p._joueur(1).arene
	var def: Dictionary = (d.armes["lame_de_fil"] as Dictionary).duplicate(true)
	def["degats"] = 10.0
	def["recharge"] = 1.0
	a1.armes.append(ArmeEquipee.new(def))
	a1.ennemis.ajouter(0, Vector2(100, 0), PV_ENORMES, 0.0, 0.0, 0.0, 0.0, 0, Types.Armure.AUCUNE)
	AidesPartie.pas(p, 120)
	var par_id := {}
	for j: Dictionary in p.vue_globale().joueurs:
		par_id[int(j["id"])] = float(j["dps"])
	verifier(float(par_id[1]) > 5.0, "le joueur armé a un dps")
	verifier_egal(float(par_id[2]), 0.0, "le joueur sans arme n'en a pas")
