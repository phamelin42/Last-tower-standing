class_name SignaturesArmes
extends RefCounted
## Signature visuelle de chaque arme : forme et couleur du projectile, traînée, impact, statut.
## Table seule : rien ici n'est encore branché sur le jeu (l'intégration attend la validation de
## Phil sur `docs/planche_signatures.png`). La table se lit par identifiant d'arme et ne fige
## aucun effectif : une arme ajoutée à `data/armes.json` reçoit sa ligne ici, un test l'exige.
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
]  # gdlint: ignore=max-line-length
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

## id → [projectile, couleur, trainee, impact, statut].
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


static func ids() -> PackedStringArray:
	var liste: PackedStringArray = []
	for id: Variant in TABLE:
		liste.append(String(id))
	return liste


## `{}` pour une arme inconnue.
static func de(id_arme: String) -> Dictionary:
	if not TABLE.has(id_arme):
		return {}
	var ligne: Array = TABLE[id_arme]
	return {
		"projectile": ligne[0],
		"couleur": PALETTE[ligne[1]],
		"trainee": ligne[2],
		"impact": ligne[3],
		"statut": ligne[4],
		"son": "tir_" + id_arme,
	}
