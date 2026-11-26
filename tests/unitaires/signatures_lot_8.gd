extends RefCounted
## Les 30 signatures du lot 8 telles que Phil les a validées (T8.14), figées ici : le lot 9 en
## ajoute d'autres à `SignaturesArmes.TABLE`, il ne touche jamais à celles-ci. Chaque ligne :
## [projectile, nom de la couleur de `SignaturesArmes.PALETTE`, traînée, impact, statut].

const LIGNES: Dictionary = {
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
