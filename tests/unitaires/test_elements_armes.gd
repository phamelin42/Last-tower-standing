extends CasDeTest
## Les armes du lot 8 et celles du lot 9 déjà levées (T9.19) ont un élément visuel (D22) ; les
## autres gardent le rendu d'aujourd'hui.

const ATTENDU: Dictionary = {
	"canon_de_cloche": "feu",
	"orbe_de_brume": "glace",
	"bombarde_de_poche": "bombe",
	"cornue_instable": "poison",
	"chaine_d_arcanes": "foudre",
	"etincelle_runique": "arcane",
	"lame_de_fil": "lame",
	"faucille_a_ressort": "faucille",
	"disque_scie": "disque",
	"moulinet_de_cuivre": "moulinet",
	"guillotine_a_vapeur": "guillotine",
	"tourbillon_d_acier": "tourbillon",
	"arbalete_de_bureau": "arbalete",
	"chausse_trape": "chausse_trape",
	"carreau_ricochet": "ricochet",
	"herse_de_ressorts": "herse",
	"baliste_de_guet": "baliste",
	"pluie_d_aiguilles": "pluie",
	"cercle_de_givre": "cercle_givre",
	"nova_d_ambre": "nova",
	"tempete_astrale": "tempete",
	"petard_de_rempart": "petard",
	"mine_de_forge": "mine_forge",
	"trebuchet_de_chambre": "trebuchet",
	"grande_bombarde": "grande_bombe",
	"de_pipe": "de_pipe",
	"sablier_fele": "sablier",
	"miroir_brise": "miroir",
	"vortex_de_verre": "vortex",
	"horloge_folle": "horloge",
	"serpe_de_vigne": "serpe",
	"rasoir_tournoyant": "rasoir",
	"couperet_a_epines": "couperet",
	"lame_de_brume": "brume",
	"faucheuse_double": "faucheuse",
	"fleau_de_rasoirs": "fleau",
}


func test_les_armes_a_element_sont_exactement_celles_attendues() -> void:
	verifier_egal(ElementsArmes.ids().size(), ATTENDU.size(), "pas une arme de plus")
	for id: String in ATTENDU:
		verifier_egal(ElementsArmes.de(id), String(ATTENDU[id]), "élément de %s" % id)


func test_chaque_arme_de_la_table_existe_dans_les_donnees() -> void:
	var donnees: Donnees = Donnees.charger()
	for id: String in ElementsArmes.ids():
		verifier(donnees.armes.has(id), "arme inconnue : %s" % id)


func test_les_elements_sont_distincts_et_tous_employes() -> void:
	var vus: Dictionary = {}
	for id: String in ElementsArmes.ids():
		vus[ElementsArmes.de(id)] = true
	verifier_egal(vus.size(), ATTENDU.size())
	verifier_egal(ElementsArmes.ELEMENTS.size(), ATTENDU.size(), "la liste des éléments")
	for element: String in ElementsArmes.ELEMENTS:
		verifier(vus.has(element), "élément sans arme : %s" % element)


## Les armes en jeu (signatures validées) et les armes à élément sont exactement les mêmes.
func test_toute_arme_en_jeu_a_un_element_et_toute_arme_a_element_est_en_jeu() -> void:
	var donnees: Donnees = Donnees.charger()
	var en_jeu: int = 0
	for id: Variant in donnees.armes:
		var element: String = ElementsArmes.de(String(id))
		verifier_egal(SignaturesArmes.en_jeu(String(id)), element != "", "%s : en jeu" % id)
		if element != "":
			en_jeu += 1
			verifier(AttaquesElementaires.connait(element), "%s : élément sans rendu" % id)
	verifier(en_jeu > 0, "aucune arme en jeu")


func test_toute_autre_arme_garde_son_rendu() -> void:
	var donnees: Donnees = Donnees.charger()
	for id: Variant in donnees.armes:
		if not ATTENDU.has(String(id)):
			verifier_egal(ElementsArmes.de(String(id)), "", "%s doit rester inchangée" % id)
	verifier_egal(ElementsArmes.de("arme_qui_n_existe_pas"), "")
	verifier_egal(ElementsArmes.de(""), "")
