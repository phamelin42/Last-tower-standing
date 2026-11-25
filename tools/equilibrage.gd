extends SceneTree
## Mesure de l'équilibrage : simule des parties complètes d'un joueur seul, sans rendu, et résume
## les manches atteintes, le taux de victoire sur le boss, les causes de mort et les achats.
##   godot --headless --path . --script res://tools/equilibrage.gd -- \
##       [--graines 50] [--strategie raisonnable|passive|bonne|toutes] [--graine-depart 1]

const OBJETS_AFFICHES := 6


func _initialize() -> void:
	quit(_lancer(OS.get_cmdline_user_args()))


func _lancer(args: PackedStringArray) -> int:
	var graines := 50
	var depart := 1
	var strategies: Array[String] = StrategiesJoueur.TOUTES.duplicate()
	var i := 0
	while i < args.size():
		if i + 1 >= args.size():
			printerr("Argument sans valeur : %s" % args[i])
			return 1
		match args[i]:
			"--graines":
				graines = maxi(int(args[i + 1]), 1)
			"--graine-depart":
				depart = int(args[i + 1])
			"--strategie":
				if args[i + 1] != "toutes":
					if not StrategiesJoueur.TOUTES.has(args[i + 1]):
						printerr("Stratégie inconnue : %s" % args[i + 1])
						return 1
					strategies = [args[i + 1]]
			_:
				printerr("Argument inconnu : %s" % args[i])
				return 1
		i += 2
	var donnees := AidesPartie.donnees()
	for nom: String in strategies:
		_mesurer(donnees, nom, graines, depart)
	return 0


func _mesurer(d: Donnees, nom: String, graines: int, depart: int) -> void:
	var debut := Time.get_ticks_msec()
	var manches: Array[int] = []
	var victoires := 0
	var degats_cumules := {}
	var morts := {}
	var achats := {}
	for graine: int in range(depart, depart + graines):
		var r := SimulationEquilibrage.jouer(d, graine, nom)
		var manche: int = r["manche"]
		manches.append(manche)
		if bool(r["victoire"]):
			victoires += 1
		else:
			var familles: Dictionary = r["famille_par_manche"]
			var libelle := _libelle_famille(d, int(familles.get(manche, -1)), manche)
			morts[libelle] = int(morts.get(libelle, 0)) + 1
		var degats: Dictionary = r["degats_par_manche"]
		for m: int in degats:
			degats_cumules[m] = float(degats_cumules.get(m, 0.0)) + float(degats[m])
		var a: Dictionary = r["achats"]
		for id: String in a:
			achats[id] = int(achats.get(id, 0)) + int(a[id])
	manches.sort()
	var duree := float(Time.get_ticks_msec() - debut) / 1000.0
	print("=== %s (%d graines, %.1f s) ===" % [nom, graines, duree])
	print(
		(
			"manches : min %d, médiane %d, max %d | victoires sur le boss : %d/%d (%.0f %%)"
			% [
				manches[0],
				manches[manches.size() / 2],
				manches[manches.size() - 1],
				victoires,
				graines,
				100.0 * victoires / graines
			]
		)
	)
	print("morts par famille de la manche fatale : %s" % _classer(morts, true, 99))
	var lignes := PackedStringArray()
	var cles: Array = degats_cumules.keys()
	cles.sort()
	for m: int in cles:
		lignes.append("M%d:%.0f" % [m, float(degats_cumules[m]) / graines])
	print("dégâts reçus moyens par manche : %s" % " ".join(lignes))
	print("objets les plus achetés : %s" % _classer(achats, true, OBJETS_AFFICHES))
	print("objets les moins achetés : %s" % _moins_achetes(d, achats))


func _libelle_famille(d: Donnees, f: int, manche: int) -> String:
	if manche >= int(d.partie["manche_boss"]):
		return "boss"
	if f < 0:
		return "?"
	if f >= d.familles.size():
		return "convoi"
	return str(d.familles[f]["id"])


func _classer(dico: Dictionary, decroissant: bool, limite: int) -> String:
	var paires: Array = []
	for k: Variant in dico:
		paires.append([str(k), int(dico[k])])
	paires.sort_custom(
		func(a: Array, b: Array) -> bool:
			return int(a[1]) > int(b[1]) if decroissant else int(a[1]) < int(b[1])
	)
	var morceaux := PackedStringArray()
	for k: int in mini(limite, paires.size()):
		var paire: Array = paires[k]
		morceaux.append("%s×%d" % [paire[0], paire[1]])
	return ", ".join(morceaux)


## Les objets du catalogue jamais achetés comptent à zéro : ce sont eux les moins achetés.
func _moins_achetes(d: Donnees, achats: Dictionary) -> String:
	var tous := {}
	for id: String in d.armes:
		tous[id] = int(achats.get(id, 0))
	for id: String in d.ameliorations:
		tous[id] = int(achats.get(id, 0))
	return _classer(tous, false, OBJETS_AFFICHES)
