class_name Sauvegarde
extends RefCounted
## Lecture et écriture du profil dans un fichier local versionné, avec une copie de secours (D20,
## B1). Aucune perte : l'écriture passe par un fichier temporaire relu et contrôlé, puis renommé sur
## le fichier ; l'ancien fichier devient la copie de secours. Un fichier absent, tronqué, corrompu
## ou trop gros se remplace par la copie de secours, jamais par un profil vide tant qu'elle vaut
## quelque chose ; un fichier corrompu est mis de côté (`.corrompu`), jamais écrasé. Un fichier
## d'une version plus récente n'est ni lu ni écrasé. Ne lève jamais d'exception, même sur un fichier
## arbitraire (entrée d'un tiers).

const CHEMIN_DEFAUT := "user://progression.json"
## Version du format écrit. Une version plus ancienne se migre par `_migrer`.
const VERSION := 1
## Au-delà, le fichier n'est pas lu : un profil plein pèse moins de 40 Ko.
const TAILLE_MAX_FICHIER := 65536
const EXTENSION_SECOURS := ".bak"
const EXTENSION_CORROMPU := ".corrompu"
## Nombre de fichiers corrompus gardés côte à côte ; au-delà, le dernier est remplacé.
const CORROMPUS_MAX := 10
## Étapes de l'écriture où `simuler_echec` fait échouer l'enregistrement (tests).
const ETAPES: Array[String] = ["temporaire", "ecriture", "controle", "secours", "renommage"]

## Étape à faire échouer ; vide en jeu. Réservé aux tests de non-perte.
static var _echec_simule: String = ""


## Profil du fichier, sinon de sa copie de secours, sinon un profil vide (premier lancement).
## Jamais `null`. Un fichier de version plus récente donne un profil vide `verrouille`.
static func charger(chemin: String = CHEMIN_DEFAUT) -> Profil:
	var principal := _lire(chemin)
	if principal["etat"] == "ok":
		return principal["profil"]
	if principal["etat"] == "future":
		return _verrouille()
	if principal["etat"] == "corrompu":
		_mettre_de_cote(chemin)
	var secours := _lire(chemin + EXTENSION_SECOURS)
	if secours["etat"] == "ok":
		return secours["profil"]
	if secours["etat"] == "future":
		return _verrouille()
	if secours["etat"] == "corrompu":
		_mettre_de_cote(chemin + EXTENSION_SECOURS)
	return Profil.new()


## Écrit le profil. Renvoie vrai seulement si le fichier est en place et contrôlé ; en cas d'échec,
## le fichier et la copie de secours restent tels quels. Refuse d'écraser un fichier d'une version
## plus récente.
static func enregistrer(profil: Profil, chemin: String = CHEMIN_DEFAUT) -> bool:
	if profil.verrouille:
		return false
	var actuel := _lire(chemin)
	if actuel["etat"] == "future":
		return false
	var attendu := profil.a_dict()
	var temporaire := chemin_temporaire(chemin)
	if not _ecrire_temporaire(attendu, temporaire):
		return false
	if actuel["etat"] == "corrompu":
		_mettre_de_cote(chemin)
	elif actuel["etat"] == "ok" and not _copier_en_secours(chemin):
		_supprimer_si_fichier(temporaire)
		return false
	if _echec_simule == "renommage" or DirAccess.rename_absolute(temporaire, chemin) != OK:
		_supprimer_si_fichier(temporaire)
		return false
	return true


## Fait échouer l'étape `etape` (une de `ETAPES`) des prochains enregistrements ; vide : plus
## d'échec simulé. Pour les tests.
static func simuler_echec(etape: String) -> void:
	_echec_simule = etape


## Nom du fichier temporaire d'un processus : deux processus n'écrivent jamais le même.
static func chemin_temporaire(chemin: String, processus: int = OS.get_process_id()) -> String:
	return "%s.tmp%d" % [chemin, processus]


# --- Écriture ----------------------------------------------------------------------------------


static func _ecrire_temporaire(attendu: Dictionary, temporaire: String) -> bool:
	var fichier: FileAccess = null
	if _echec_simule != "temporaire":
		fichier = FileAccess.open(temporaire, FileAccess.WRITE)
	if fichier == null:
		return false
	fichier.store_string(JSON.stringify(attendu, "\t", true) + "\n")
	var ecriture_ok := fichier.get_error() == OK and _echec_simule != "ecriture"
	fichier.close()
	if not ecriture_ok:
		_supprimer_si_fichier(temporaire)
		return false
	# Le fichier relu doit redonner exactement ce qu'on voulait écrire.
	var relu := _lire(temporaire)
	var controle_ok: bool = relu["etat"] == "ok" and _echec_simule != "controle"
	if controle_ok:
		var profil: Profil = relu["profil"]
		controle_ok = profil.a_dict() == attendu
	if not controle_ok:
		_supprimer_si_fichier(temporaire)
	return controle_ok


## Le fichier valide devient la copie de secours, par un temporaire renommé : une copie qui échoue
## en route ne laisse jamais une copie de secours tronquée.
static func _copier_en_secours(chemin: String) -> bool:
	var secours := chemin + EXTENSION_SECOURS
	var temporaire := chemin_temporaire(secours)
	var ok := _echec_simule != "secours" and DirAccess.copy_absolute(chemin, temporaire) == OK
	if ok:
		ok = DirAccess.rename_absolute(temporaire, secours) == OK
	if not ok:
		_supprimer_si_fichier(temporaire)
	return ok


# --- Lecture -----------------------------------------------------------------------------------


## État d'un fichier : `absent`, `ok` (avec son `profil`), `future` (version plus récente) ou
## `corrompu` (illisible, tronqué, trop gros, de mauvais types ou de version inconnue).
static func _lire(chemin: String) -> Dictionary:
	if not FileAccess.file_exists(chemin):
		return {"etat": "absent"}
	var fichier := FileAccess.open(chemin, FileAccess.READ)
	if fichier == null or fichier.get_length() > TAILLE_MAX_FICHIER:
		return {"etat": "corrompu"}
	# `JSON.new().parse` rend un code d'erreur ; `parse_string` imprimerait une erreur du moteur.
	var analyseur := JSON.new()
	if analyseur.parse(fichier.get_as_text()) != OK or not analyseur.data is Dictionary:
		return {"etat": "corrompu"}
	var donnees: Dictionary = analyseur.data
	var version: Variant = Profil._entier(donnees.get("version"))
	if version == null or int(version) < 1:
		return {"etat": "corrompu"}
	if int(version) > VERSION:
		return {"etat": "future"}
	donnees = _migrer(donnees, int(version))
	var profil := Profil.depuis_dict(donnees)
	if profil == null:
		return {"etat": "corrompu"}
	profil.version = VERSION
	return {"etat": "ok", "profil": profil}


## Amène un fichier d'une version précédente au format courant, une version à la fois. Aucune
## ancienne version n'existe encore : chaque format abandonné ajoutera ici son étape.
static func _migrer(donnees: Dictionary, version: int) -> Dictionary:
	var courant := donnees
	for v: int in range(version, VERSION):
		courant = _migrer_depuis(courant, v)
	return courant


## L'étape qui fait passer de la version `v` à `v + 1` (aucune à ce jour : voir `_migrer`).
static func _migrer_depuis(donnees: Dictionary, _v: int) -> Dictionary:
	return donnees


static func _verrouille() -> Profil:
	var p := Profil.new()
	p.verrouille = true
	return p


## Met un fichier illisible à côté (`.corrompu`, puis `.corrompu.1`…) au lieu de l'écraser.
static func _mettre_de_cote(chemin: String) -> void:
	if not FileAccess.file_exists(chemin):
		return
	var cible := chemin + EXTENSION_CORROMPU
	var rang := 0
	while FileAccess.file_exists(cible) and rang < CORROMPUS_MAX - 1:
		rang += 1
		cible = "%s%s.%d" % [chemin, EXTENSION_CORROMPU, rang]
	DirAccess.rename_absolute(chemin, cible)


static func _supprimer_si_fichier(chemin: String) -> void:
	if FileAccess.file_exists(chemin):
		DirAccess.remove_absolute(chemin)
