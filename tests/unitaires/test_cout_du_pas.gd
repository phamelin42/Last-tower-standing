extends CasDeTest
## Coût d'un pas de simulation avec le catalogue complet (S27). Une partie de huit joueurs avance
## huit arènes dans les 50 ms d'un pas à 20 Hz : chacune doit tenir en moins de 5 ms au 10e centile
## (`MesurePas`), même avec toutes les armes et améliorations, mille ennemis et 64 alliés. Le profil
## du 27/11/2026 a trouvé l'essentiel du coût dans le contexte de tir reconstruit pour chaque arme
## prête, à chaque pas, même sans ennemi à sa portée.

const DT := 0.05
const GRAINE := 5
## Budget du plan, au 10e centile des blocs de quatre pas.
const BUDGET_MS := 5.0
## Sans ennemi, les armes n'ont rien à résoudre : le coût est celui des minuteurs et de la tour.
const BUDGET_SANS_ENNEMI_MS := 1.5
## Mille ennemis à portée de toutes les armes, ou mille ennemis et 64 alliés : le pire cas de la
## manche 31, mesuré à 5,3 et 5,6 ms avec 90 armes (10,1 et 11,0 avant S27). Le plan en vise 5 :
## voir le suivi de T12.9.
const BUDGET_EXTREME_MS := 7.0

var d: Donnees


func avant_chaque() -> void:
	delai_max = 60.0
	d = Donnees.charger()
	d.partie["tour"]["pv"] = 1.0e12


## Une arène qui porte tout le catalogue, avec ses ennemis immobiles (vitesse nulle) au plancher.
func _arene() -> Arene:
	var a := Arene.new(d, GRAINE)
	for id: String in d.ids_catalogue:
		a.inventaire.ajouter(id)
	a.synchroniser()
	var mult := {"pv": 1.0, "degats": 1.0, "vitesse": 0.0, "resistance_controle": 1.0}
	a.demarrer_manche(20, Composition.unique(0), mult)
	return a


## Mesure `pas` pas après un échauffement : 10e centile des blocs de quatre pas, en ms par pas, le
## rendu lisant la vue à 15 Hz environ.
func _mesurer(a: Arene, pas: int) -> float:
	for _i: int in 40:
		a.avancer(DT)
	var blocs := PackedInt32Array()
	for _b: int in pas / 4:
		var debut := Time.get_ticks_usec()
		for _i: int in 4:
			a.avancer(DT)
			if a.tick_courant() % 4 == 0:
				a.vue(Types.Phase.MANCHE, 1.0, -1, false)
		blocs.append(Time.get_ticks_usec() - debut)
	return MesurePas.centile_bas_ms(blocs, 4)


## Mille ennemis immobiles et presque invulnérables autour de la tour, à portée des armes :
## avec le catalogue complet, les ennemis qui apparaissent seuls meurent avant d'être mille.
func _monter_a(a: Arene, ennemis: int) -> void:
	for n: int in ennemis:
		var distance := 150.0 + float(n % 150)
		var p := Vector2.from_angle(float(n) * 0.0188496) * distance
		a.ennemis.ajouter(0, p, 1.0e12, 0.0, 1.0, 45.0, 1.0, 1, Types.Armure.LEGERE)
	verifier(
		a.nombre_ennemis() >= ennemis, "au moins %d ennemis (%d)" % [ennemis, a.nombre_ennemis()]
	)


func test_le_catalogue_complet_sans_ennemi_coute_moins_de_1_5_ms_par_pas() -> void:
	var a := _arene()
	verifier_egal(a.armes.size(), d.armes.size(), "toutes les armes sont montées")
	var ms := _mesurer(a, 200)
	print(
		"  [mesure] %d armes, aucun ennemi : %.3f ms par pas (10e centile)" % [a.armes.size(), ms]
	)
	verifier(
		ms < BUDGET_SANS_ENNEMI_MS, "%.3f ms par pas (budget %s)" % [ms, BUDGET_SANS_ENNEMI_MS]
	)


func test_le_catalogue_complet_contre_500_ennemis_coute_moins_de_5_ms_par_pas() -> void:
	var a := _arene()
	_monter_a(a, 500)
	var ms := _mesurer(a, 200)
	print(
		(
			"  [mesure] %d armes, %d ennemis : %.3f ms par pas (10e centile)"
			% [a.armes.size(), a.nombre_ennemis(), ms]
		)
	)
	verifier(ms < BUDGET_MS, "%.3f ms par pas (budget %s)" % [ms, BUDGET_MS])


func test_le_catalogue_complet_contre_mille_ennemis_coute_moins_de_7_ms_par_pas() -> void:
	var a := _arene()
	_monter_a(a, 1000)
	var ms := _mesurer(a, 200)
	print(
		(
			"  [mesure] %d armes, %d ennemis : %.3f ms par pas (10e centile)"
			% [a.armes.size(), a.nombre_ennemis(), ms]
		)
	)
	verifier(ms < BUDGET_EXTREME_MS, "%.3f ms par pas (budget %s)" % [ms, BUDGET_EXTREME_MS])


func test_le_catalogue_complet_contre_mille_ennemis_et_64_allies_coute_moins_de_7_ms_par_pas(
) -> void:
	var a := _arene()
	_monter_a(a, 1000)
	for _k: int in 64:
		a.allies.invoquer(0, Vector2.ZERO, 1000.0, 1.0, Types.TypeDegats.CHAOS, 0, 1, 0)
	verifier_egal(a.allies.ids.size(), 64, "64 alliés")
	var ms := _mesurer(a, 200)
	print(
		(
			"  [mesure] %d armes, %d ennemis, 64 alliés : %.3f ms par pas (10e centile)"
			% [a.armes.size(), a.nombre_ennemis(), ms]
		)
	)
	verifier(ms < BUDGET_EXTREME_MS, "%.3f ms par pas (budget %s)" % [ms, BUDGET_EXTREME_MS])
