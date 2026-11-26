extends CasDeTest
## Vingt-sept armes ont un élément visuel (D22) ; les autres gardent le rendu d'aujourd'hui.

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
}


func test_les_vingt_sept_armes_ont_leur_element() -> void:
	verifier_egal(ElementsArmes.ids().size(), 27, "vingt-sept armes seulement")
	for id: String in ATTENDU:
		verifier_egal(ElementsArmes.de(id), String(ATTENDU[id]), "élément de %s" % id)


func test_chaque_arme_de_la_table_existe_dans_les_donnees() -> void:
	var donnees: Donnees = Donnees.charger()
	for id: String in ElementsArmes.ids():
		verifier(donnees.armes.has(id), "arme inconnue : %s" % id)


func test_les_vingt_sept_elements_sont_distincts_et_tous_employes() -> void:
	var vus: Dictionary = {}
	for id: String in ElementsArmes.ids():
		vus[ElementsArmes.de(id)] = true
	verifier_egal(vus.size(), 27)
	for element: String in ElementsArmes.ELEMENTS:
		verifier(vus.has(element), "élément sans arme : %s" % element)


func test_toute_autre_arme_garde_son_rendu() -> void:
	var donnees: Donnees = Donnees.charger()
	for id: Variant in donnees.armes:
		if not ATTENDU.has(String(id)):
			verifier_egal(ElementsArmes.de(String(id)), "", "%s doit rester inchangée" % id)
	verifier_egal(ElementsArmes.de("arme_qui_n_existe_pas"), "")
	verifier_egal(ElementsArmes.de(""), "")
