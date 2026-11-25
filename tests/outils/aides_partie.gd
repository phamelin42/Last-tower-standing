class_name AidesPartie
extends RefCounted
## Aides des tests de `Partie` : données réelles modifiées, parties prêtes à jouer, pas à la
## chaîne. Elles ne servent qu'aux tests (aucune de ces fonctions n'existe dans `sim/`).

const DT := 0.05


## Les JSON de `data/`, tels que `Donnees.depuis_brut` les attend (nombres en flottants).
static func brut() -> Dictionary:
	var out := {}
	var noms: Array[String] = []
	noms.append_array(Donnees.FICHIERS_OBJET)
	noms.append_array(Donnees.FICHIERS_LISTE)
	for nom: String in noms:
		var json := JSON.new()
		json.parse(FileAccess.get_file_as_string(Donnees.DOSSIER_REEL.path_join(nom)))
		out[nom] = json.data
	return out


## Pose `valeur` à `chemin` (suite de clés) dans le fichier `fichier` du brut.
static func regler(
	brut_donnees: Dictionary, fichier: String, chemin: Array, valeur: Variant
) -> void:
	var courant: Variant = brut_donnees[fichier]
	for k: int in chemin.size() - 1:
		var dico: Dictionary = courant
		courant = dico[chemin[k]]
	var dernier: Dictionary = courant
	dernier[chemin[chemin.size() - 1]] = valeur


## Données réelles, avec les réglages `{fichier: [[chemin, valeur], …]}` appliqués.
static func donnees(reglages: Dictionary = {}) -> Donnees:
	var b := brut()
	for fichier: String in reglages:
		var liste: Array = reglages[fichier]
		for entree: Variant in liste:
			var paire: Array = entree
			regler(b, fichier, paire[0], paire[1])
	return Donnees.depuis_brut(b)


static func config(graine: int, facteur: float = 1.0) -> Partie.Config:
	var c := Partie.Config.new()
	c.graine = graine
	c.facteur_duree = facteur
	return c


## Une partie de `n` joueurs d'ids 1..n, démarrée sauf si `lancer` est faux.
static func partie(
	d: Donnees, graine: int, n: int, facteur: float = 1.0, lancer: bool = true
) -> Partie:
	var p := Partie.new(d, config(graine, facteur))
	for i: int in range(1, n + 1):
		p.ajouter_joueur(i, "Joueur %d" % i)
	if lancer:
		p.demarrer()
	return p


## `n` pas de 0,05 s.
static func pas(p: Partie, n: int) -> void:
	for _i: int in n:
		p.avancer(DT)
