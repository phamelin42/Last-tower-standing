extends CasDeTest
## Contrat de `SourceVue` tel que le voit le reste du jeu : chaque intention atteint la
## source avec ses arguments, chaque signal parvient à qui l'écoute, et la base seule ne
## fait rien (ni effet, ni erreur) : une implémentation qui oublie une intention n'est
## pas silencieuse.

## Interface du plan (« Source de vue »), intentions et requêtes confondues.
const METHODES_INTERFACE := [
	"id_local",
	"cible_observee",
	"acheter",
	"relancer",
	"vendre",
	"choisir_marche_noir",
	"observer",
	"continuer_sans_fin",
	"quitter_partie",
]
const SIGNAUX_INTERFACE := [
	"vue_arene_recue",
	"vue_globale_recue",
	"resultat_intention",
	"connexion_perdue",
]
## Intentions avec un exemple d'arguments qui n'est pas la valeur par défaut.
const INTENTIONS := {
	"acheter": [2],
	"relancer": [],
	"vendre": [4],
	"choisir_marche_noir": ["aiguisage_de_rivière"],
	"observer": [3],
	"continuer_sans_fin": [],
	"quitter_partie": [],
}


func _methodes_de_l_interface(source: SourceVue) -> PackedStringArray:
	var trouvees := PackedStringArray()
	for methode: Dictionary in source.get_method_list():
		var nom: String = methode["name"]
		if nom in METHODES_INTERFACE and not nom in trouvees:
			trouvees.append(nom)
	return trouvees


func test_interface_du_plan_est_complete() -> void:
	var base: SourceVue = SourceVue.new()
	var trouvees := _methodes_de_l_interface(base)
	trouvees.sort()
	var attendues := PackedStringArray(METHODES_INTERFACE)
	attendues.sort()
	verifier_egal(trouvees, attendues, "méthodes de SourceVue")
	for nom: String in SIGNAUX_INTERFACE:
		verifier(base.has_signal(nom), "signal absent : %s" % nom)
	base.free()


func test_chaque_intention_arrive_a_la_source_avec_ses_arguments() -> void:
	var source: SourceFactice = SourceFactice.new()
	for nom: String in INTENTIONS:
		var args: Array = INTENTIONS[nom]
		var avant := source.appels.size()
		source.callv(nom, args)
		verifier_egal(source.appels.size(), avant + 1, "une seule entrée pour %s" % nom)
		verifier_egal(source.appels[-1], {"nom": nom, "args": args}, "appel de %s" % nom)
	verifier_egal(source.appels.size(), INTENTIONS.size(), "nombre d'intentions notées")
	source.free()


func test_chaque_intention_du_plan_est_couverte_par_la_boucle() -> void:
	var source: SourceFactice = SourceFactice.new()
	var trouvees := _methodes_de_l_interface(source)
	for nom: String in trouvees:
		if nom in ["id_local", "cible_observee"]:
			continue
		verifier(INTENTIONS.has(nom), "intention sans cas de test : %s" % nom)
	source.free()


func test_identite_locale_et_cible_se_reglent() -> void:
	var source: SourceFactice = SourceFactice.new()
	source.regler(3, 2)
	verifier_egal(source.id_local(), 3, "id local réglé")
	verifier_egal(source.cible_observee(), 2, "cible observée réglée")
	source.free()


func test_chaque_signal_parvient_a_son_auditeur() -> void:
	var source: SourceFactice = SourceFactice.new()
	var vue := VueArene.new()
	vue.tick = 7
	var globale := VueGlobale.new()
	var recus_arene: Array = []
	var recus_globale: Array = []
	var recus_resultats: Array = []
	var recus_connexions: Array = []
	source.vue_arene_recue.connect(func(v: VueArene) -> void: recus_arene.append(v))
	source.vue_globale_recue.connect(func(v: VueGlobale) -> void: recus_globale.append(v))
	source.resultat_intention.connect(
		func(genre: String, code: int) -> void: recus_resultats.append([genre, code])
	)
	source.connexion_perdue.connect(func(motif: String) -> void: recus_connexions.append(motif))

	source.emettre_arene(vue)
	source.emettre_globale(globale)
	source.emettre_resultat("acheter", Types.Resultat.OR_INSUFFISANT)
	source.emettre_connexion_perdue("serveur coupé")

	verifier_egal(recus_arene.size(), 1, "vue d'arène reçue une fois")
	verifier(is_same(recus_arene[0], vue), "la vue d'arène reçue est celle qui est émise")
	verifier_egal(recus_globale.size(), 1, "vue globale reçue une fois")
	verifier(is_same(recus_globale[0], globale), "la vue globale reçue est celle qui est émise")
	verifier_egal(
		recus_resultats,
		[["acheter", Types.Resultat.OR_INSUFFISANT]],
		"résultat d'intention reçu avec son genre et son code",
	)
	verifier_egal(recus_connexions, ["serveur coupé"], "connexion perdue reçue avec son motif")
	source.free()


func test_la_base_seule_ne_fait_rien_et_ne_leve_pas_d_erreur() -> void:
	var base: SourceVue = SourceVue.new()
	var signaux_recus: Array = []
	base.resultat_intention.connect(func(_g: String, _c: int) -> void: signaux_recus.append(1))
	base.vue_arene_recue.connect(func(_v: VueArene) -> void: signaux_recus.append(1))

	verifier_egal(base.id_local(), -1, "id local de la base")
	verifier_egal(base.cible_observee(), -1, "cible de la base")
	for nom: String in INTENTIONS:
		var args: Array = INTENTIONS[nom]
		base.callv(nom, args)
	verifier_egal(signaux_recus.size(), 0, "aucun signal émis par la base")
	base.free()
