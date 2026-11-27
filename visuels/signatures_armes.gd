class_name SignaturesArmes
extends RefCounted
## Signature visuelle de chaque arme : forme et couleur du projectile, traînée, impact, statut.
## Seules les signatures de `TABLE` (lot 8, validées) servent en jeu (`en_jeu`) ; celles de
## `TABLE_LOT_9` attendent la validation de Phil sur `docs/planche_signatures.png`.
## La table se lit par identifiant d'arme et ne fige aucun effectif : une arme ajoutée à
## `data/armes.json` reçoit sa ligne ici, sinon `de()` rend `{}` et `test_signatures_armes` échoue.
##
## Grammaire : 12 formes × 10 couleurs × 6 traînées × 8 impacts. Chaque type de dégâts garde ses
## deux couleurs (on reconnaît le type de loin) ; la forme du projectile départage les armes d'une
## même couleur, la traînée et l'impact départagent le reste. Deux armes diffèrent toujours par
## deux éléments au moins parmi les quatre (`ELEMENTS`).

const ELEMENTS: Array[String] = ["projectile", "couleur", "trainee", "impact"]

const PROJECTILES: Array[String] = [
	"trait",
	"fleche",
	"disque",
	"dynamite",
	"losange",
	"croissant",
	"shuriken",
	"goutte",
	"carre",
	"triangle",
	"hexagone",
	"spirale",
]
const TRAINEES: Array[String] = ["filet", "ondule", "zigzag", "pointille", "etincelles", "double"]
const IMPACTS: Array[String] = [
	"entaille",
	"pointes",
	"halo",
	"explosion",
	"etoile",
	"anneau",
	"croix",
	"eclaboussure",
]
## Formes des statuts (`kind` de `data/armes.json`) : un soin vert qui monte pour le vol de vie.
const STATUTS: Dictionary = {
	"givre": "flocon",
	"poison": "bulles",
	"etourdissement": "croix_plus",
	"brulure": "feu",
	"vol_de_vie": "soin",
	"vulnerabilite": "cible_brisee",
	"malediction_toucher": "voile",
	"malediction_degats": "voile_fendu",
	"repoussement": "recul",
	"siphon": "siphon",
	"mana_au_coup": "cristal",
}

## Ce que la marque d'une mécanique propre montre d'un coup d'œil (`de()["marque"]`, `""` sans).
const MARQUES: Array[String] = [
	"",
	"rayon_tournant",
	"disque_au_sol",
	"bombe",
	"allie",
	"vulnerabilite",
]

## Libellé affiché d'un statut (la planche, plus tard l'interface) : avec ses accents.
const LIBELLES_STATUTS: Dictionary = {
	"givre": "givre",
	"poison": "poison",
	"etourdissement": "étourdissement",
	"brulure": "brûlure",
	"vol_de_vie": "vol de vie",
	"vulnerabilite": "vulnérabilité",
	"malediction_toucher": "malédiction",
	"malediction_degats": "affaiblissement",
	"repoussement": "repoussement",
	"siphon": "siphon",
	"mana_au_coup": "mana au coup",
}

## Deux couleurs par type de dégâts, toutes vives (valeur ≥ 0,6) pour se lire au dézoom.
const PALETTE: Dictionary = {
	"acier": Color(0.7, 0.8, 1.0),
	"turquoise": Color(0.22, 0.95, 0.83),
	"paille": Color(0.98, 0.84, 0.29),
	"vert": Color(0.4, 0.85, 0.34),
	"bleu": Color(0.35, 0.5, 1.0),
	"indigo": Color(0.6, 0.5, 1.0),
	"rouge": Color(0.95, 0.27, 0.25),
	"orange": Color(1.0, 0.6, 0.12),
	"violet": Color(0.76, 0.38, 0.95),
	"magenta": Color(1.0, 0.35, 0.78),
}

## id → [projectile, couleur, trainee, impact, statut]. Les signatures validées par Phil (lot 8),
## celles que le jeu utilise.
const TABLE: Dictionary = {
	"lame_de_fil": ["trait", "acier", "filet", "entaille", ""],
	"faucille_a_ressort": ["croissant", "acier", "ondule", "entaille", ""],
	"disque_scie": ["disque", "turquoise", "pointille", "pointes", "poison"],
	"moulinet_de_cuivre": ["shuriken", "acier", "double", "etoile", ""],
	"guillotine_a_vapeur": ["triangle", "turquoise", "double", "croix", ""],
	"tourbillon_d_acier": ["spirale", "turquoise", "etincelles", "anneau", "vol_de_vie"],
	"arbalete_de_bureau": ["fleche", "paille", "filet", "pointes", ""],
	"chausse_trape": ["shuriken", "paille", "pointille", "croix", ""],
	"carreau_ricochet": ["losange", "vert", "zigzag", "pointes", ""],
	"herse_de_ressorts": ["carre", "paille", "double", "etoile", "etourdissement"],
	"baliste_de_guet": ["fleche", "vert", "etincelles", "eclaboussure", "poison"],
	"pluie_d_aiguilles": ["trait", "vert", "pointille", "anneau", ""],
	"etincelle_runique": ["losange", "bleu", "etincelles", "halo", ""],
	"orbe_de_brume": ["disque", "indigo", "ondule", "anneau", "givre"],
	"chaine_d_arcanes": ["hexagone", "bleu", "zigzag", "etoile", ""],
	"cercle_de_givre": ["hexagone", "indigo", "pointille", "croix", "givre"],
	"nova_d_ambre": ["goutte", "bleu", "double", "explosion", "brulure"],
	"tempete_astrale": ["spirale", "indigo", "zigzag", "eclaboussure", "etourdissement"],
	"bombarde_de_poche": ["disque", "rouge", "filet", "explosion", ""],
	"petard_de_rempart": ["dynamite", "orange", "pointille", "explosion", ""],
	"trebuchet_de_chambre": ["carre", "rouge", "ondule", "eclaboussure", ""],
	"mine_de_forge": ["hexagone", "orange", "filet", "pointes", ""],
	"canon_de_cloche": ["goutte", "rouge", "etincelles", "halo", "brulure"],
	"grande_bombarde": ["dynamite", "rouge", "double", "anneau", "etourdissement"],
	"de_pipe": ["carre", "violet", "filet", "halo", "vol_de_vie"],
	"sablier_fele": ["triangle", "magenta", "ondule", "entaille", ""],
	"cornue_instable": ["goutte", "violet", "zigzag", "eclaboussure", "poison"],
	"miroir_brise": ["losange", "magenta", "etincelles", "etoile", ""],
	"vortex_de_verre": ["spirale", "violet", "double", "explosion", "vol_de_vie"],
	"horloge_folle": ["croissant", "magenta", "pointille", "croix", "brulure"],
}

## Les signatures proposées du lot 9 (T9.18), des 75 armes moins les 30 du lot 8 : même forme de
## ligne que `TABLE`. Elles s'affichent sur la planche mais pas en jeu (voir `en_jeu`).
const TABLE_LOT_9: Dictionary = {
	"serpe_de_vigne": ["croissant", "turquoise", "zigzag", "entaille", "vulnerabilite"],
	"rasoir_tournoyant": ["shuriken", "turquoise", "etincelles", "croix", ""],
	"couperet_a_epines": ["carre", "acier", "zigzag", "croix", ""],
	"lame_de_brume": ["trait", "turquoise", "ondule", "halo", "malediction_toucher"],
	"faucheuse_double": ["losange", "acier", "double", "pointes", "poison"],
	"fleau_de_rasoirs": ["triangle", "acier", "filet", "anneau", "vulnerabilite"],
	"hache_de_garde": ["hexagone", "acier", "pointille", "halo", "malediction_toucher"],
	"scie_a_ruban": ["disque", "acier", "ondule", "etoile", "poison"],
	"moissonneuse_d_acier": ["carre", "turquoise", "double", "entaille", "vulnerabilite"],
	"javeline_de_jet": ["trait", "paille", "ondule", "croix", "repoussement"],
	"trait_en_gerbe": ["triangle", "vert", "zigzag", "etoile", ""],
	"fleche_marquante": ["hexagone", "paille", "etincelles", "halo", "vulnerabilite"],
	"arc_de_remparts": ["croissant", "vert", "ondule", "anneau", "vulnerabilite"],
	"herse_de_pieux": ["triangle", "paille", "pointille", "explosion", "repoussement"],
	"lance_epineuse": ["shuriken", "vert", "double", "croix", "poison"],
	"carquois_en_rafale": ["disque", "paille", "zigzag", "eclaboussure", "vulnerabilite"],
	"mur_de_pointes": ["carre", "vert", "filet", "etoile", "repoussement"],
	"couronne_de_pointes": ["spirale", "paille", "ondule", "anneau", "repoussement"],
	"rune_de_veille": ["carre", "indigo", "pointille", "halo", ""],
	"eclat_siphonneur": ["goutte", "indigo", "filet", "eclaboussure", "siphon"],
	"lueur_vagabonde": ["disque", "bleu", "ondule", "halo", ""],
	"prisme_de_faille": ["triangle", "bleu", "etincelles", "croix", "vulnerabilite"],
	"orage_en_cage": ["carre", "bleu", "zigzag", "explosion", "brulure"],
	"couronne_d_etoiles": ["shuriken", "indigo", "double", "explosion", "mana_au_coup"],
	"vasque_d_arcanes": ["croissant", "bleu", "filet", "anneau", "siphon"],
	"nuee_d_etincelles": ["trait", "bleu", "pointille", "pointes", "mana_au_coup"],
	"nova_celeste": ["spirale", "bleu", "zigzag", "halo", "vulnerabilite"],
	# Siège.
	"baril_a_retardement": ["carre", "orange", "ondule", "explosion", ""],
	"maillet_de_rempart": ["triangle", "rouge", "pointille", "pointes", ""],
	"catapulte_a_contrepoids": ["goutte", "orange", "zigzag", "croix", ""],
	"obusier_de_breche": ["triangle", "orange", "double", "etoile", "vulnerabilite"],
	"braise_de_siege": ["spirale", "orange", "double", "halo", "brulure"],
	"ecrasement_de_tour": ["hexagone", "rouge", "etincelles", "pointes", "etourdissement"],
	"champ_de_ruines": ["losange", "orange", "pointille", "anneau", "vulnerabilite"],
	"salve_du_rempart": ["losange", "rouge", "double", "explosion", "brulure"],
	"colosse_de_pierre": ["disque", "orange", "etincelles", "croix", "vulnerabilite"],
	# Chaos.
	"urne_des_ombres": ["hexagone", "violet", "pointille", "anneau", ""],
	"pacte_de_sang": ["goutte", "magenta", "filet", "croix", "siphon"],
	"engrenage_jumeau": ["shuriken", "violet", "etincelles", "etoile", ""],
	"serment_brise": ["losange", "violet", "zigzag", "croix", "malediction_degats"],
	"archere_fantome": ["fleche", "violet", "ondule", "eclaboussure", ""],
	"miroir_de_discorde": ["triangle", "violet", "ondule", "pointes", "vulnerabilite"],
	"coupe_d_oubli": ["croissant", "violet", "etincelles", "halo", "siphon"],
	"legion_de_cendre": ["disque", "violet", "zigzag", "anneau", ""],
	"tempete_de_malefices":
	["shuriken", "magenta", "pointille", "eclaboussure", "malediction_degats"],
}

## id → marque de la mécanique propre de l'arme (voir `MARQUES`) ; une arme absente n'en a pas.
const MARQUES_ARMES: Dictionary = {
	"serpe_de_vigne": "vulnerabilite",
	"rasoir_tournoyant": "rayon_tournant",
	"faucheuse_double": "rayon_tournant",
	"fleau_de_rasoirs": "vulnerabilite",
	"moissonneuse_d_acier": "rayon_tournant",
	"fleche_marquante": "vulnerabilite",
	"arc_de_remparts": "vulnerabilite",
	"carquois_en_rafale": "vulnerabilite",
	"couronne_de_pointes": "vulnerabilite",
	"rune_de_veille": "disque_au_sol",
	"lueur_vagabonde": "rayon_tournant",
	"prisme_de_faille": "vulnerabilite",
	"orage_en_cage": "disque_au_sol",
	"couronne_d_etoiles": "rayon_tournant",
	"nova_celeste": "vulnerabilite",
	"baril_a_retardement": "bombe",
	"obusier_de_breche": "bombe",
	"salve_du_rempart": "bombe",
	"braise_de_siege": "disque_au_sol",
	"champ_de_ruines": "disque_au_sol",
	"colosse_de_pierre": "vulnerabilite",
	"urne_des_ombres": "allie",
	"archere_fantome": "allie",
	"miroir_de_discorde": "vulnerabilite",
	"tempete_de_malefices": "vulnerabilite",
}


## Libellé d'un statut, ou `""` pour un statut inconnu.
static func libelle_statut(statut: String) -> String:
	return String(LIBELLES_STATUTS.get(statut, ""))


## Toutes les armes signées, validées ou proposées.
static func ids() -> PackedStringArray:
	var liste: PackedStringArray = []
	for id: Variant in TABLE:
		liste.append(String(id))
	for id: Variant in TABLE_LOT_9:
		liste.append(String(id))
	return liste


## Vrai pour les signatures validées par Phil (`TABLE`) et pour les armes du lot 9 qui ont reçu leur
## élément (`ElementsArmes`) : `Effets` n'utilise que celles-là, une arme dont la signature est
## seulement proposée garde le rendu par type de dégâts. T9.19 lève la garde famille par famille.
static func en_jeu(id_arme: String) -> bool:
	return TABLE.has(id_arme) or ElementsArmes.de(id_arme) != ""


## `{}` pour une arme inconnue.
static func de(id_arme: String) -> Dictionary:
	var ligne: Array = TABLE.get(id_arme, TABLE_LOT_9.get(id_arme, []))
	if ligne.is_empty():
		return {}
	return {
		"projectile": ligne[0],
		"couleur": PALETTE[ligne[1]],
		"trainee": ligne[2],
		"impact": ligne[3],
		"statut": ligne[4],
		"marque": String(MARQUES_ARMES.get(id_arme, "")),
		"son": "tir_" + id_arme,
	}
