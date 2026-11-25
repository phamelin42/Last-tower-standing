class_name ImagesOffres
extends RefCounted
## Correspondance offre → objet dessiné sur une case : pour chacune des 70 offres de la boutique,
## l'icône du pack peint de Ravenmore (CC BY 3.0, `assets/icones/ravenmore/`) et la couleur de la
## case. Les cases sont composées par `tools/composer_images_offres.gd` dans
## `assets/icones/cases/<id>.png`. La couleur dit le type de dégâts d'une arme ou la famille d'une
## amélioration ; le texte de la carte le dit aussi, la couleur ne porte jamais seule l'information.
## Deux offres n'ont jamais à la fois la même icône et la même couleur (test).
##
## Rapprochements faibles : aucune icône du pack ne colle vraiment au nom ou à l'effet (pas de
## trébuchet, de sablier ni de tirelire parmi les 41). L'icône la plus proche est reprise, et
## l'offre figure dans `RAPPROCHEMENTS_FAIBLES` pour que Phil tranche sur la planche.

const DOSSIER_ICONES := "res://assets/icones/ravenmore/"
const DOSSIER_CASES := "res://assets/icones/cases/"

## Couleur de case : [centre du dégradé, bord du dégradé].
const COULEURS: Dictionary = {
	# Types de dégâts.
	"brique": [Color("a8453a"), Color("4a1a1c")],
	"vert": [Color("4f9a4a"), Color("1c4220")],
	"violet": [Color("6f60c8"), Color("2a2060")],
	"brun": [Color("b9702f"), Color("4e2c10")],
	"pourpre": [Color("9a4aa8"), Color("3c1648")],
	# Familles d'amélioration : bonus général, défense et survie, économie, utilitaire.
	"dore": [Color("ece0a8"), Color("7a6a2a")],
	"acier": [Color("5f86ad"), Color("1f3a58")],
	"or": [Color("d0a22e"), Color("5c4210")],
	"sarcelle": [Color("2f9a9a"), Color("0f4446")],
}

const OFFRES: Dictionary = {
	# Armes tranchantes.
	"lame_de_fil": ["dagger", "brique"],
	"faucille_a_ressort": ["axe", "brique"],
	"disque_scie": ["axeDouble", "brique"],
	"moulinet_de_cuivre": ["axeDouble2", "brique"],
	"guillotine_a_vapeur": ["upg_axe", "brique"],
	"tourbillon_d_acier": ["upg_axeDouble", "brique"],
	# Armes perçantes.
	"arbalete_de_bureau": ["bow", "vert"],
	"chausse_trape": ["swordWood", "vert"],
	"carreau_ricochet": ["dagger", "vert"],
	"herse_de_ressorts": ["shield", "vert"],
	"baliste_de_guet": ["upg_bow", "vert"],
	"pluie_d_aiguilles": ["upg_spear", "vert"],
	# Armes magiques.
	"etincelle_runique": ["wand", "violet"],
	"orbe_de_brume": ["gemBlue", "violet"],
	"chaine_d_arcanes": ["scroll", "violet"],
	"cercle_de_givre": ["potionBlue", "violet"],
	"nova_d_ambre": ["upg_wand", "violet"],
	"tempete_astrale": ["upg_spear", "violet"],
	# Armes de siège.
	"bombarde_de_poche": ["hammer", "brun"],
	"petard_de_rempart": ["potionRed", "brun"],
	"trebuchet_de_chambre": ["tools", "brun"],
	"mine_de_forge": ["gemRed", "brun"],
	"canon_de_cloche": ["upg_helmet", "brun"],
	"grande_bombarde": ["upg_hammer", "brun"],
	# Armes du chaos.
	"de_pipe": ["gemRed", "pourpre"],
	"sablier_fele": ["x", "pourpre"],
	"cornue_instable": ["potionGreen", "pourpre"],
	"miroir_brise": ["shieldSmall", "pourpre"],
	"vortex_de_verre": ["gemGreen", "pourpre"],
	"horloge_folle": ["upgShieldSmall", "pourpre"],
	# Bonus de dégâts d'un type.
	"affutage_fin": ["sword", "brique"],
	"forge_du_maitre": ["upg_sword", "brique"],
	"pointes_trempees": ["potionGreen", "vert"],
	"carquois_sans_fond": ["backpack", "vert"],
	"encre_d_arcane": ["map", "violet"],
	"grimoire_des_cimes": ["tome", "violet"],
	"poudre_noire": ["backpack", "brun"],
	"poudriere_renforcee": ["armor", "brun"],
	"poussiere_d_entropie": ["potionBlue", "pourpre"],
	"coeur_du_desordre": ["heart", "pourpre"],
	# Bonus général de dégâts.
	"etincelle_d_ame": ["gemBlue", "dore"],
	"couronne_de_rouages": ["upg_helmet", "dore"],
	# Défense et survie.
	"renfort_de_poutres": ["swordWood", "acier"],
	"fondations_de_pierre": ["shield", "acier"],
	"mousse_de_guerison": ["potionGreen", "acier"],
	"seve_d_ambre": ["heart", "acier"],
	"plaques_de_laiton": ["armor", "acier"],
	"cuirasse_de_bronze": ["upg_armor", "acier"],
	"meurtrieres_biaisees": ["shieldSmall", "acier"],
	"herisson_de_fer": ["helmet", "acier"],
	"couronne_d_epines": ["upg_helmet", "acier"],
	"gorgee_de_sang": ["potionRed", "acier"],
	"calice_des_vaincus": ["upgShieldSmall", "acier"],
	# Économie.
	"cagnotte_du_guet": ["coin", "or"],
	"atelier_de_tisserands": ["tools", "or"],
	"placement_de_rente": ["scroll", "or"],
	"livre_de_comptes": ["tome", "or"],
	"fonderie_de_pieces": ["upg_hammer", "or"],
	"prime_du_guet": ["envelope", "or"],
	"chasse_aux_trophees": ["upg_helmet", "or"],
	"tirelire_d_honneur": ["backpack", "or"],
	# Utilitaire : critique, cadence, tirs, éclaboussure, focalisation, relance, marché noir.
	"oeil_de_lynx": ["gemGreen", "sarcelle"],
	"de_de_fortune": ["gemRed", "sarcelle"],
	"balancier_rapide": ["hammer", "sarcelle"],
	"engrenage_affole": ["tools", "sarcelle"],
	"double_encoche": ["bow", "sarcelle"],
	"eclats_multiples": ["gemBlue", "sarcelle"],
	"lentille_fixe": ["wand", "sarcelle"],
	"bourse_de_rebut": ["backpack", "sarcelle"],
	"jeton_de_l_arriere_boutique": ["map", "sarcelle"],
}

## Offres dont l'icône n'est qu'un rapprochement faible, à faire valider par Phil.
const RAPPROCHEMENTS_FAIBLES: PackedStringArray = [
	"disque_scie",
	"moulinet_de_cuivre",
	"chausse_trape",
	"carreau_ricochet",
	"herse_de_ressorts",
	"cercle_de_givre",
	"tempete_astrale",
	"petard_de_rempart",
	"trebuchet_de_chambre",
	"mine_de_forge",
	"canon_de_cloche",
	"de_pipe",
	"sablier_fele",
	"miroir_brise",
	"vortex_de_verre",
	"horloge_folle",
	"pointes_trempees",
	"carquois_sans_fond",
	"encre_d_arcane",
	"poudre_noire",
	"poudriere_renforcee",
	"poussiere_d_entropie",
	"calice_des_vaincus",
	"lentille_fixe",
	"bourse_de_rebut",
	"jeton_de_l_arriere_boutique",
	"tirelire_d_honneur",
	"atelier_de_tisserands",
	"placement_de_rente",
	"fonderie_de_pieces",
	"chasse_aux_trophees",
	"de_de_fortune",
]


## Tous les identifiants d'offre de la table, dans l'ordre de déclaration.
static func ids() -> PackedStringArray:
	var liste: PackedStringArray = []
	for id: Variant in OFFRES:
		liste.append(String(id))
	return liste


## `{icone, couleur}` de l'offre, ou un dictionnaire vide si elle est inconnue.
static func entree(id: String) -> Dictionary:
	if not OFFRES.has(id):
		return {}
	var brut: Array = OFFRES[id]
	return {"icone": brut[0], "couleur": brut[1]}


static func chemin_icone(icone: String) -> String:
	return DOSSIER_ICONES + icone + ".png"


static func chemin_case(id: String) -> String:
	return DOSSIER_CASES + id + ".png"


static func est_rapprochement_faible(id: String) -> bool:
	return RAPPROCHEMENTS_FAIBLES.has(id)
