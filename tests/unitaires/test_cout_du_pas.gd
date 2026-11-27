extends CasDeTest
## Coût d'un pas de simulation avec le catalogue complet (S27). Une partie de huit joueurs avance
## huit arènes dans les 50 ms d'un pas à 20 Hz : chacune vise moins de 5 ms au 10e centile
## (`MesurePas`), même avec toutes les armes et améliorations, mille ennemis et 64 alliés. Le profil
## du 27/11/2026 a trouvé l'essentiel du coût dans le contexte de tir reconstruit pour chaque arme
## prête, à chaque pas, même sans ennemi à sa portée.

const DT := 0.05
const GRAINE := 5
## Le budget se juge au rapport entre le coût du pas et celui d'un étalon mesuré dans la même
## exécution (`_etalon_ms`) : une machine chargée ralentit l'un comme l'autre, le rapport garde son
## sens, alors qu'un plafond en millisecondes a échoué sous la charge de quatre sessions (7,05 ms
## pour 7,0). Rapports mesurés le 27/11/2026 avec 90 armes, au repos et sous cinq boucles qui
## saturent les quatre cœurs : sans ennemi 2,7 à 2,8 ; 500 ennemis 22 à 27 ; mille ennemis 36 à 42 ;
## mille ennemis et 64 alliés 38 à 42. Les plafonds valent environ 1,5 à 1,8 fois ces valeurs : une
## marge réelle, et le coût d'avant S27 (rapports de 57 sans ennemi, 70 et 76 avec mille ennemis)
## les dépasse.
const RAPPORT_SANS_ENNEMI_MAX := 5.0
const RAPPORT_500_ENNEMIS_MAX := 40.0
## Mille ennemis à portée de toutes les armes, ou mille ennemis et 64 alliés : le pire cas de la
## manche 31 (10,1 et 11,0 ms avant S27, 5,3 et 5,6 ms après). Le plan en vise 5 : voir T12.9.
const RAPPORT_EXTREME_MAX := 65.0
## Plafond en millisecondes, très large : il ne sert que si l'étalon lui-même se déréglait.
const PLAFOND_ABSOLU_MS := 20.0

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


## Le coût d'un travail fixe, de même nature que la simulation (boucle GDScript sur des vecteurs,
## comparaisons et sommes), au 10e centile de 60 blocs : l'unité dans laquelle on juge le pas.
func _etalon_ms() -> float:
	var positions := PackedVector2Array()
	for i: int in 1000:
		positions.append(Vector2(fmod(float(i) * 0.37, 211.0), fmod(float(i) * 0.91, 197.0)))
	var blocs := PackedInt32Array()
	var somme := 0.0
	for _b: int in 60:
		var debut := Time.get_ticks_usec()
		for _p: int in 4:
			for i: int in 1000:
				var d2 := positions[i].distance_squared_to(Vector2.ZERO)
				if d2 < 20000.0:
					somme += d2 * 0.5
		blocs.append(Time.get_ticks_usec() - debut)
	verifier(somme > 0.0, "l'étalon a travaillé")
	return MesurePas.centile_bas_ms(blocs, 1)


## Mesure puis juge un scénario : le pas, divisé par l'étalon de la même exécution, reste sous
## `rapport_max` ; le plafond absolu n'est qu'une alarme large.
func _juger(a: Arene, rapport_max: float, titre: String) -> void:
	var etalon := _etalon_ms()
	var ms := _mesurer(a, 200)
	var rapport := ms / etalon
	print(
		(
			"  [mesure] %s : %.3f ms par pas (10e centile), étalon %.3f ms, rapport %.2f"
			% [titre, ms, etalon, rapport]
		)
	)
	verifier(
		rapport < rapport_max,
		"%s : rapport %.2f au pas / étalon (plafond %.2f)" % [titre, rapport, rapport_max]
	)
	verifier(
		ms < PLAFOND_ABSOLU_MS, "%s : %.3f ms par pas (alarme %s)" % [titre, ms, PLAFOND_ABSOLU_MS]
	)


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


func test_le_catalogue_complet_sans_ennemi_reste_dans_son_budget_relatif() -> void:
	var a := _arene()
	verifier_egal(a.armes.size(), d.armes.size(), "toutes les armes sont montées")
	_juger(a, RAPPORT_SANS_ENNEMI_MAX, "%d armes, aucun ennemi" % a.armes.size())


func test_le_catalogue_complet_contre_500_ennemis_reste_dans_son_budget_relatif() -> void:
	var a := _arene()
	_monter_a(a, 500)
	_juger(
		a, RAPPORT_500_ENNEMIS_MAX, "%d armes, %d ennemis" % [a.armes.size(), a.nombre_ennemis()]
	)


func test_le_catalogue_complet_contre_mille_ennemis_reste_dans_son_budget_relatif() -> void:
	var a := _arene()
	_monter_a(a, 1000)
	_juger(a, RAPPORT_EXTREME_MAX, "%d armes, %d ennemis" % [a.armes.size(), a.nombre_ennemis()])


func test_le_catalogue_complet_contre_mille_ennemis_et_64_allies_reste_dans_son_budget_relatif(
) -> void:
	var a := _arene()
	_monter_a(a, 1000)
	for _k: int in 64:
		a.allies.invoquer(0, Vector2.ZERO, 1000.0, 1.0, Types.TypeDegats.CHAOS, 0, 1, 0)
	verifier_egal(a.allies.ids.size(), 64, "64 alliés")
	_juger(
		a,
		RAPPORT_EXTREME_MAX,
		"%d armes, %d ennemis, 64 alliés" % [a.armes.size(), a.nombre_ennemis()]
	)
