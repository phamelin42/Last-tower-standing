class_name Arguments
extends RefCounted
## Lecture de la ligne de commande (`--serveur`, `--annuaire`, `--autoriser-prive`,
## `--port N`, `--graine N`, `--vitesse X`, `--solo-auto`). Une valeur invalide donne la valeur
## par défaut et un message dans `messages` : un lancement mal écrit ne doit jamais empêcher de
## jouer.

const PORT_DEFAUT := 7777
const PORT_MAX := 65535
## Une graine absente vaut -1 : la partie en tire une au hasard.
const GRAINE_DEFAUT := -1
const VITESSE_DEFAUT := 1.0
const VITESSES: Array[float] = [1.0, 0.5, 0.25]
const ENTIER_MAX_CHIFFRES := 15


## Renvoie `{serveur: bool, annuaire: bool, autoriser_prive: bool, port: int, port_donne: bool,
## graine: int, vitesse: float, solo_auto: bool, messages: Array[String]}`. `port_donne` vaut vrai
## si un `--port` valide est là : l'annuaire a un autre port par défaut que le jeu.
static func lire(args: PackedStringArray) -> Dictionary:
	var messages: Array[String] = []
	var sortie: Dictionary = {
		"serveur": false,
		"annuaire": false,
		"autoriser_prive": false,
		"port": PORT_DEFAUT,
		"port_donne": false,
		"graine": GRAINE_DEFAUT,
		"vitesse": VITESSE_DEFAUT,
		"solo_auto": false,
		"messages": messages,
	}
	var i := 0
	while i < args.size():
		var option := args[i]
		var valeur := ""
		var a_valeur := false
		var egal := option.find("=")
		if option.begins_with("--") and egal > 0:
			valeur = option.substr(egal + 1)
			option = option.substr(0, egal)
			a_valeur = true
		match option:
			"--serveur":
				sortie["serveur"] = true
			"--annuaire":
				sortie["annuaire"] = true
			"--autoriser-prive":
				sortie["autoriser_prive"] = true
			"--solo-auto":
				sortie["solo_auto"] = true
			"--port", "--graine", "--vitesse":
				if not a_valeur:
					if i + 1 < args.size() and not args[i + 1].begins_with("--"):
						i += 1
						valeur = args[i]
					else:
						messages.append("Argument sans valeur : %s (valeur par défaut)" % option)
						_defaut(sortie, option)
						i += 1
						continue
				_ecrire(sortie, option, valeur, messages)
			_:
				messages.append("Argument inconnu : %s (ignoré)" % args[i])
		i += 1
	return sortie


static func _defaut(sortie: Dictionary, option: String) -> void:
	match option:
		"--port":
			sortie["port"] = PORT_DEFAUT
			sortie["port_donne"] = false
		"--graine":
			sortie["graine"] = GRAINE_DEFAUT
		_:
			sortie["vitesse"] = VITESSE_DEFAUT


static func _ecrire(
	sortie: Dictionary, option: String, valeur: String, messages: Array[String]
) -> void:
	var invalide := false
	match option:
		"--port":
			var port := _entier(valeur)
			invalide = port < 1 or port > PORT_MAX
			sortie["port"] = PORT_DEFAUT if invalide else port
			sortie["port_donne"] = not invalide
		"--graine":
			var graine := _entier(valeur)
			invalide = graine < 0
			sortie["graine"] = GRAINE_DEFAUT if invalide else graine
		_:
			var vitesse := _vitesse(valeur)
			invalide = vitesse <= 0.0
			sortie["vitesse"] = VITESSE_DEFAUT if invalide else vitesse
	if invalide:
		messages.append("Valeur invalide pour %s : « %s » (valeur par défaut)" % [option, valeur])


## -1 si `texte` n'est pas un entier décimal positif ou nul d'au plus 15 chiffres.
static func _entier(texte: String) -> int:
	if texte.is_empty() or texte.length() > ENTIER_MAX_CHIFFRES or not texte.is_valid_int():
		return -1
	if texte.begins_with("-") or texte.begins_with("+"):
		return -1
	return texte.to_int()


## 0 si `texte` n'est pas l'une des trois vitesses de partie.
static func _vitesse(texte: String) -> float:
	if not texte.is_valid_float():
		return 0.0
	var v := texte.to_float()
	for permise: float in VITESSES:
		if is_equal_approx(v, permise):
			return permise
	return 0.0
