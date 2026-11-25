extends SceneTree
## Lanceur de tests.
## godot --headless --path . --script res://tests/lanceur.gd -- \
##     [--filtre motif] [--dossier res://tests] [--controle]


## Les tests attendent que l'arbre tourne : `_ready`, RPC, `await process_frame` n'existent pas
## avant la première image.
func _initialize() -> void:
	process_frame.connect(_demarrer, CONNECT_ONE_SHOT)


func _demarrer() -> void:
	quit(await _lancer(OS.get_cmdline_user_args()))


func _lancer(args: PackedStringArray) -> int:
	var filtre := ""
	var dossier := "res://tests"
	var controle := false
	var i := 0
	while i < args.size():
		match args[i]:
			"--controle":
				controle = true
			"--filtre", "--dossier":
				if i + 1 >= args.size():
					printerr("Argument sans valeur : %s" % args[i])
					return 1
				i += 1
				if args[i - 1] == "--filtre":
					filtre = args[i]
				else:
					dossier = args[i]
			_:
				printerr("Argument inconnu : %s" % args[i])
				return 1
		i += 1

	var moteur := MoteurDeTests.new()
	var chemins := moteur.decouvrir(dossier, filtre, controle)
	var bilan := await moteur.executer(chemins, filtre, self)
	var lignes: PackedStringArray = bilan["lignes"]
	for ligne in lignes:
		print(ligne)
	print(
		(
			"%d tests, %d échecs, %d assertions"
			% [bilan["tests"], bilan["echecs"], bilan["assertions"]]
		)
	)
	return moteur.code_de_sortie(bilan, controle)
