class_name Reglages
extends RefCounted
## Réglages locaux du joueur, conservés entre les parties. Le fichier est lu une fois au
## démarrage : absent, illisible, tronqué, trop gros ou de types faux, il donne les valeurs par
## défaut, sans exception et sans rien effacer. Une valeur hors bornes est ramenée dans ses
## bornes. L'écriture passe par un fichier temporaire renommé : un échec garde l'ancien réglage.

const CHEMIN_DEFAUT := "user://reglages.cfg"
const SECTION := "reglages"
## Dernière ligne de chaque fichier écrit. Un fichier tronqué ne se termine jamais par elle :
## il est refusé avant d'atteindre le lecteur, qui sinon lirait une valeur coupée (« 0. »).
const FIN := "; fin\n"
## Au-delà, le fichier n'est pas lu : une copie gonflée ne doit pas coûter de la mémoire.
const TAILLE_MAX_FICHIER := 65536
const NOM_MAX := 24
const ADRESSE_MAX := 255
## L'annuaire des parties en ligne (ADR 001, décision 16). Vide, il est désactivé.
const ANNUAIRE_DEFAUT := "annuaire-lts.phamelin.fr:7779"
const ECHELLES: Array[float] = [1.0, 1.25, 1.5]
const TAILLE_TEXTE_BASE := 16
const SENSIBILITE_MIN := 0.5
const SENSIBILITE_MAX := 2.0

var volume_general: float = 1.0
var echelle_ui: float = 1.0
var plein_ecran: bool = false
var sensibilite_zoom: float = 1.0
var nom_joueur: String = ""
var derniere_adresse: String = ""
var annuaire_adresse: String = ANNUAIRE_DEFAUT
## Case « Partie publique » de la création d'un salon, cochée par défaut (décision de Phil).
var salon_public: bool = true
## Compteur d'images par seconde (T5.1b) : éteint tant que la joueuse ne le demande pas.
var afficher_ips: bool = false


## Renvoie toujours un réglage utilisable : les valeurs absentes ou invalides prennent leur
## défaut. Ne lève jamais d'exception, même sur un fichier arbitraire.
static func charger(chemin: String = CHEMIN_DEFAUT) -> Reglages:
	var r := Reglages.new()
	var texte := _lire_borne(chemin)
	if not texte.ends_with(FIN):
		return r
	var cfg := ConfigFile.new()
	if cfg.parse(texte) != OK:
		return r
	r.volume_general = _nombre(cfg, "volume_general", r.volume_general)
	r.echelle_ui = _nombre(cfg, "echelle_ui", r.echelle_ui)
	r.plein_ecran = _booleen(cfg, "plein_ecran", r.plein_ecran)
	r.sensibilite_zoom = _nombre(cfg, "sensibilite_zoom", r.sensibilite_zoom)
	r.nom_joueur = _texte(cfg, "nom_joueur", r.nom_joueur)
	r.derniere_adresse = _texte(cfg, "derniere_adresse", r.derniere_adresse)
	r.annuaire_adresse = _texte(cfg, "annuaire_adresse", r.annuaire_adresse)
	r.salon_public = _booleen(cfg, "salon_public", r.salon_public)
	r.afficher_ips = _booleen(cfg, "afficher_ips", r.afficher_ips)
	r.normaliser()
	return r


## Écrit le fichier temporaire, puis le renomme sur le réglage. Renvoie vrai seulement si le
## renommage a réussi : en cas d'échec, l'ancien fichier reste tel quel.
func sauver(chemin: String = CHEMIN_DEFAUT) -> bool:
	normaliser()
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, "volume_general", volume_general)
	cfg.set_value(SECTION, "echelle_ui", echelle_ui)
	cfg.set_value(SECTION, "plein_ecran", plein_ecran)
	cfg.set_value(SECTION, "sensibilite_zoom", sensibilite_zoom)
	cfg.set_value(SECTION, "nom_joueur", nom_joueur)
	cfg.set_value(SECTION, "derniere_adresse", derniere_adresse)
	cfg.set_value(SECTION, "annuaire_adresse", annuaire_adresse)
	cfg.set_value(SECTION, "salon_public", salon_public)
	cfg.set_value(SECTION, "afficher_ips", afficher_ips)
	var temporaire := chemin + ".tmp"
	var fichier := FileAccess.open(temporaire, FileAccess.WRITE)
	if fichier == null:
		return false
	fichier.store_string(cfg.encode_to_text() + FIN)
	var ecriture_ok := fichier.get_error() == OK
	fichier.close()
	if not ecriture_ok:
		_supprimer_si_fichier(temporaire)
		return false
	if DirAccess.rename_absolute(temporaire, chemin) != OK:
		_supprimer_si_fichier(temporaire)
		return false
	return true


## Ramène chaque valeur dans ses bornes. Appelé à la lecture et avant chaque écriture.
func normaliser() -> void:
	volume_general = clampf(volume_general, 0.0, 1.0)
	echelle_ui = echelle_valide(echelle_ui)
	sensibilite_zoom = clampf(sensibilite_zoom, SENSIBILITE_MIN, SENSIBILITE_MAX)
	nom_joueur = texte_propre(nom_joueur, NOM_MAX)
	derniere_adresse = texte_propre(derniere_adresse, ADRESSE_MAX)
	annuaire_adresse = texte_propre(annuaire_adresse, ADRESSE_MAX)


## Un niveau d'échelle prend la valeur permise la plus proche (1,0, 1,25 ou 1,5).
static func echelle_valide(valeur: float) -> float:
	var bornee := clampf(valeur, ECHELLES[0], ECHELLES[ECHELLES.size() - 1])
	var meilleure: float = ECHELLES[0]
	for niveau: float in ECHELLES:
		if absf(niveau - bornee) < absf(meilleure - bornee):
			meilleure = niveau
	return meilleure


## Taille de texte de l'interface : 16 px au niveau 1,0, jamais en dessous.
static func taille_texte_pour(echelle: float) -> int:
	return roundi(TAILLE_TEXTE_BASE * echelle_valide(echelle))


## Retire les caractères de contrôle (C0, DEL, C1) et tronque à `maximum` caractères.
static func texte_propre(brut: String, maximum: int) -> String:
	var sortie := ""
	for i: int in brut.length():
		var code: int = brut.unicode_at(i)
		if code < 0x20 or (code >= 0x7F and code <= 0x9F):
			continue
		sortie += brut[i]
	return sortie.strip_edges().left(maximum)


static func _lire_borne(chemin: String) -> String:
	var fichier := FileAccess.open(chemin, FileAccess.READ)
	if fichier == null:
		return ""
	if fichier.get_length() > TAILLE_MAX_FICHIER:
		return ""
	return fichier.get_as_text()


static func _nombre(cfg: ConfigFile, cle: String, defaut: float) -> float:
	var valeur: Variant = cfg.get_value(SECTION, cle, defaut)
	if valeur is float:
		return valeur
	if valeur is int:
		return float(valeur)
	return defaut


static func _booleen(cfg: ConfigFile, cle: String, defaut: bool) -> bool:
	var valeur: Variant = cfg.get_value(SECTION, cle, defaut)
	if valeur is bool:
		return valeur
	return defaut


static func _texte(cfg: ConfigFile, cle: String, defaut: String) -> String:
	var valeur: Variant = cfg.get_value(SECTION, cle, defaut)
	if valeur is String:
		return valeur
	return defaut


static func _supprimer_si_fichier(chemin: String) -> void:
	if FileAccess.file_exists(chemin):
		DirAccess.remove_absolute(chemin)
