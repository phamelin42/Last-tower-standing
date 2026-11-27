extends CasDeTest
## Phil (D23, 27/11/2026) : « no selling in game ». La vente disparaît de la simulation, du réseau,
## de l'interface, des textes, des données et du robot de test ; son numéro d'intention reste
## réservé et refusé, et le protocole change de version.

## Identifiants et clés de la vente, écrits en deux morceaux : ce fichier ne les contient pas.
const MOTS: Array[String] = [
	"vend" + "re(", "prix_" + "vente", "vente_" + "ratio", "intention_" + "vendre"
]
const DOSSIERS: Array[String] = [
	"res://sim",
	"res://reseau",
	"res://app",
	"res://ui",
	"res://i18n",
	"res://data",
	"res://tests/outils"
]


static func _fichiers(dossier: String) -> Array[String]:
	var sortie: Array[String] = []
	for sous: String in DirAccess.get_directories_at(dossier):
		sortie.append_array(_fichiers(dossier.path_join(sous)))
	for f: String in DirAccess.get_files_at(dossier):
		if f.get_extension() in ["gd", "json", "csv"]:
			sortie.append(dossier.path_join(f))
	return sortie


func test_aucun_fichier_ne_cite_la_vente() -> void:
	var examines := 0
	for dossier: String in DOSSIERS:
		for chemin: String in _fichiers(dossier):
			examines += 1
			var texte := FileAccess.get_file_as_string(chemin)
			for mot: String in MOTS:
				verifier_faux(texte.contains(mot), "%s cite encore « %s »" % [chemin, mot])
	verifier(examines > 50, "aucun fichier examiné")


func test_on_ne_peut_plus_vendre() -> void:
	var d := Donnees.charger()
	var nom := "vend" + "re"
	var arene := Arene.new(d, 1)
	verifier_faux(arene.has_method(nom), "Arene")
	verifier_faux(arene.boutique.has_method(nom), "Boutique")
	verifier_faux(arene.inventaire.has_method("retirer_arme"), "Inventaire")
	verifier_faux(Partie.new(d, AidesPartie.config(1)).has_method("intention_" + nom), "Partie")
	verifier_faux(SourceLocale.new().has_method(nom), "SourceLocale")
	verifier_faux(Client.new().has_method(nom), "Client")
	verifier_faux(d.partie.has("vente_" + "ratio"), "partie.json")


func test_le_numero_de_la_vente_est_reserve_et_refuse_par_le_protocole() -> void:
	var retiree := Protocole.Intention.VENDRE_RETIREE
	verifier_egal(retiree, 3, "le numéro ne change pas")
	for arg: int in [0, 4, -1]:
		verifier_egal(Protocole.encoder_intention(retiree, arg), PackedByteArray())
	for code: int in range(Types.Resultat.OK, Types.Resultat.ARMES_AU_MAXIMUM + 1):
		verifier_egal(Protocole.encoder_resultat(retiree, code), PackedByteArray())
	# Un octet forgé à la main est refusé comme n'importe quel genre inconnu.
	var forge := PackedByteArray([Protocole.Msg.INTENTION, retiree, 0, 0, 0, 0, 0])
	verifier_egal(Protocole.decoder_intention(forge), {})
	var forge_resultat := PackedByteArray([Protocole.Msg.RESULTAT, retiree, 0])
	verifier_egal(Protocole.decoder_resultat(forge_resultat), {})


func test_les_autres_intentions_restent_encodables() -> void:
	for genre: int in range(Protocole.Intention.ACHETER, Protocole.Intention.SKIN + 1):
		if genre == Protocole.Intention.VENDRE_RETIREE or genre == Protocole.Intention.REGARDER:
			continue
		verifier_faux(Protocole.encoder_intention(genre, 0).is_empty(), "genre %d" % genre)


func test_la_version_du_protocole_a_monte_et_les_precedentes_sont_refusees() -> void:
	verifier(Protocole.VERSION >= 11, "plus de vente : version 11 au moins")
	for v: int in range(1, Protocole.VERSION):
		var b := PackedByteArray([Protocole.Msg.BONJOUR, v])
		verifier_egal(Protocole.decoder_bonjour(b), {}, "version %d" % v)
