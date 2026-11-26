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

const DOSSIER_RACINE := "res://assets/icones/"
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
	"disque_scie": ["ludicarts/lame_courbe", "brique"],
	"moulinet_de_cuivre": ["ludicarts/lame_feu", "brique"],
	"guillotine_a_vapeur": ["upg_axe", "brique"],
	"tourbillon_d_acier": ["upg_axeDouble", "brique"],
	"serpe_de_vigne": ["axe2", "brique"],
	"rasoir_tournoyant": ["axeDouble", "brique"],
	"couperet_a_epines": ["upg_hammer", "brique"],
	"lame_de_brume": ["ludicarts/fiole_violette", "brique"],
	"faucheuse_double": ["axeDouble2", "brique"],
	"fleau_de_rasoirs": ["upg_dagger", "brique"],
	"hache_de_garde": ["shield", "brique"],
	"scie_a_ruban": ["upg_spear", "brique"],
	"moissonneuse_d_acier": ["swordWood", "brique"],
	# Armes perçantes.
	"arbalete_de_bureau": ["bow", "vert"],
	"chausse_trape": ["swordWood", "vert"],
	"carreau_ricochet": ["ludicarts/fleches_givre", "vert"],
	"herse_de_ressorts": ["ludicarts/bouclier_bois", "vert"],
	"baliste_de_guet": ["upg_bow", "vert"],
	"pluie_d_aiguilles": ["ludicarts/fleches_feu", "vert"],
	"javeline_de_jet": ["upg_spear", "vert"],
	"trait_en_gerbe": ["dagger", "vert"],
	"fleche_marquante": ["upg_dagger", "vert"],
	"arc_de_remparts": ["upg_sword", "vert"],
	"herse_de_pieux": ["axeDouble", "vert"],
	"lance_epineuse": ["sword", "vert"],
	"carquois_en_rafale": ["ludicarts/sac", "vert"],
	"mur_de_pointes": ["upg_shield", "vert"],
	"couronne_de_pointes": ["upg_helmet", "vert"],
	# Armes magiques.
	"etincelle_runique": ["wand", "violet"],
	"orbe_de_brume": ["gemBlue", "violet"],
	"chaine_d_arcanes": ["scroll", "violet"],
	"cercle_de_givre": ["ludicarts/anneau_vert", "violet"],
	"nova_d_ambre": ["upg_wand", "violet"],
	"tempete_astrale": ["ludicarts/cristal_violet", "violet"],
	"rune_de_veille": ["ludicarts/fiole_violette", "violet"],
	"eclat_siphonneur": ["gemRed", "violet"],
	"lueur_vagabonde": ["ludicarts/torche", "violet"],
	"prisme_de_faille": ["ludicarts/cristal_vert", "violet"],
	"orage_en_cage": ["ludicarts/lame_feu", "violet"],
	"couronne_d_etoiles": ["upg_helmet", "violet"],
	"vasque_d_arcanes": ["potionGreen", "violet"],
	"nuee_d_etincelles": ["ludicarts/fiole_jaune", "violet"],
	"nova_celeste": ["upg_shield", "violet"],
	# Armes de siège.
	"bombarde_de_poche": ["hammer", "brun"],
	"petard_de_rempart": ["ludicarts/torche", "brun"],
	"trebuchet_de_chambre": ["tools", "brun"],
	"mine_de_forge": ["gemRed", "brun"],
	"canon_de_cloche": ["upg_helmet", "brun"],
	"grande_bombarde": ["upg_hammer", "brun"],
	"baril_a_retardement": ["potionRed", "brun"],
	"maillet_de_rempart": ["upg_shield", "brun"],
	"catapulte_a_contrepoids": ["upg_axe", "brun"],
	"obusier_de_breche": ["upg_spear", "brun"],
	"braise_de_siege": ["ludicarts/lame_feu", "brun"],
	"ecrasement_de_tour": ["armor", "brun"],
	"champ_de_ruines": ["gemBlue", "brun"],
	"salve_du_rempart": ["ludicarts/fleches_feu", "brun"],
	"colosse_de_pierre": ["upg_armor", "brun"],
	# Armes du chaos.
	"de_pipe": ["gemRed", "pourpre"],
	"sablier_fele": ["ludicarts/fiole_jaune", "pourpre"],
	"cornue_instable": ["potionGreen", "pourpre"],
	"miroir_brise": ["shieldSmall", "pourpre"],
	"vortex_de_verre": ["ludicarts/cristal_vert", "pourpre"],
	"horloge_folle": ["upgShieldSmall", "pourpre"],
	"urne_des_ombres": ["potionBlue", "pourpre"],
	"pacte_de_sang": ["potionRed", "pourpre"],
	"engrenage_jumeau": ["tools", "pourpre"],
	"serment_brise": ["upg_dagger", "pourpre"],
	"archere_fantome": ["ludicarts/fleches_givre", "pourpre"],
	"miroir_de_discorde": ["ludicarts/bouclier_bois", "pourpre"],
	"coupe_d_oubli": ["ludicarts/fiole_rouge", "pourpre"],
	"legion_de_cendre": ["upg_helmet", "pourpre"],
	"tempete_de_malefices": ["tome", "pourpre"],
	# Bonus de dégâts d'un type.
	"affutage_fin": ["sword", "brique"],
	"forge_du_maitre": ["upg_sword", "brique"],
	"pointes_trempees": ["ludicarts/fleches", "vert"],
	"carquois_sans_fond": ["backpack", "vert"],
	"encre_d_arcane": ["ludicarts/parchemin_bleu", "violet"],
	"grimoire_des_cimes": ["tome", "violet"],
	"poudre_noire": ["ludicarts/fiole_rouge", "brun"],
	"poudriere_renforcee": ["ludicarts/sac", "brun"],
	"poussiere_d_entropie": ["ludicarts/fiole_violette", "pourpre"],
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
	"lentille_fixe": ["ludicarts/cristal_vert", "sarcelle"],
	"bourse_de_rebut": ["backpack", "sarcelle"],
	"jeton_de_l_arriere_boutique": ["map", "sarcelle"],
	# Mana : maximale et régénération.
	"fiole_d_azur": ["potionBlue", "sarcelle"],
	"cristal_de_reserve": ["ludicarts/cristal_violet", "sarcelle"],
	"source_vive": ["potionBlue", "violet"],
}

## Offres dont l'icône n'est qu'un rapprochement faible, à faire valider par Phil.
const RAPPROCHEMENTS_FAIBLES: PackedStringArray = [
	"chausse_trape",
	"trait_en_gerbe",
	"orage_en_cage",
	"urne_des_ombres",
	"engrenage_jumeau",
	"archere_fantome",
	"miroir_de_discorde",
	"legion_de_cendre",
	"baril_a_retardement",
	"maillet_de_rempart",
	"catapulte_a_contrepoids",
	"obusier_de_breche",
	"braise_de_siege",
	"champ_de_ruines",
	"salve_du_rempart",
	"couronne_d_etoiles",
	"nova_celeste",
	"herse_de_pieux",
	"carquois_en_rafale",
	"mur_de_pointes",
	"couronne_de_pointes",
	"couperet_a_epines",
	"lame_de_brume",
	"scie_a_ruban",
	"moissonneuse_d_acier",
	"trebuchet_de_chambre",
	"mine_de_forge",
	"canon_de_cloche",
	"de_pipe",
	"sablier_fele",
	"miroir_brise",
	"horloge_folle",
	"carquois_sans_fond",
	"calice_des_vaincus",
	"bourse_de_rebut",
	"jeton_de_l_arriere_boutique",
	"tirelire_d_honneur",
	"atelier_de_tisserands",
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


## Une icône sans préfixe vient de Ravenmore ; `pack/nom` désigne `assets/icones/<pack>/<nom>.png`.
static func chemin_icone(icone: String) -> String:
	if icone.contains("/"):
		return DOSSIER_RACINE + icone + ".png"
	return DOSSIER_ICONES + icone + ".png"


static func chemin_case(id: String) -> String:
	return DOSSIER_CASES + id + ".png"


static func est_rapprochement_faible(id: String) -> bool:
	return RAPPROCHEMENTS_FAIBLES.has(id)
