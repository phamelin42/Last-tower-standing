extends RefCounted
## Ce que la planche des signatures (`tools/planche_signatures.gd`) montre de chaque arme : la
## planche de son projectile, celle de son impact, une teinte quand l'arme varie un élément déjà
## dessiné, et la planche de sa marque quand celle-ci n'est pas toujours la même (disque au sol).
## Une arme sans fiche est montrée par les formes de `SignaturesArmes`, en attendant son dessin.
## Les noms sont ceux de `tools/dessin/dessin_commun.gd` (`PLANCHES`).

const SANS: Color = Color(1.0, 1.0, 1.0)

## id d'arme → {projectile, impact, teinte (facultative), disque (facultatif)}.
const FICHES: Dictionary = {
	# Lot 8, déjà en jeu (les planches que lisent les fichiers de `visuels/attaques/`).
	"lame_de_fil": {"projectile": "lame_croissant", "impact": "entaille"},
	"faucille_a_ressort": {"projectile": "faucille", "impact": "balayage"},
	"disque_scie": {"projectile": "disque_scie", "impact": "eclat_acier"},
	"moulinet_de_cuivre": {"projectile": "lame_cuivre", "impact": "eclat_acier"},
	"guillotine_a_vapeur": {"projectile": "arc_lame", "impact": "vapeur"},
	"tourbillon_d_acier": {"projectile": "lame_tournante", "impact": "eclat_acier"},
	"arbalete_de_bureau": {"projectile": "carreau", "impact": "gerbe"},
	"chausse_trape": {"projectile": "chausse_trape", "impact": "pointes_sol"},
	"carreau_ricochet": {"projectile": "carreau", "impact": "gerbe"},
	"herse_de_ressorts": {"projectile": "pique", "impact": "gerbe"},
	"baliste_de_guet": {"projectile": "carreau_baliste", "impact": "gerbe"},
	"pluie_d_aiguilles": {"projectile": "aiguille", "impact": "plante"},
	"etincelle_runique": {"projectile": "rune", "impact": "eclat_rune"},
	"orbe_de_brume": {"projectile": "eclat_glace", "impact": "brisure_glace"},
	"chaine_d_arcanes": {"projectile": "", "impact": "etincelle"},
	"cercle_de_givre": {"projectile": "", "impact": "givre_sol"},
	"nova_d_ambre": {"projectile": "vague_ambre", "impact": "braise"},
	"tempete_astrale": {"projectile": "etoile_astrale", "impact": "eclat_astral"},
	"bombarde_de_poche": {"projectile": "bombe", "impact": "explosion_feu"},
	"petard_de_rempart": {"projectile": "petard", "impact": "pop_petard"},
	"trebuchet_de_chambre": {"projectile": "rocher", "impact": "cratere"},
	"mine_de_forge": {"projectile": "mine_forge", "impact": "explosion_feu"},
	"canon_de_cloche": {"projectile": "boule_feu", "impact": "explosion_feu"},
	"grande_bombarde": {"projectile": "bombe", "impact": "explosion_feu"},
	"de_pipe": {"projectile": "de_pipe", "impact": "eclat_des"},
	"sablier_fele": {"projectile": "sablier", "impact": "tourbillon_sable"},
	"cornue_instable": {"projectile": "fiole", "impact": "eclaboussure_poison"},
	"miroir_brise": {"projectile": "eclat_miroir", "impact": "gerbe_verre"},
	"vortex_de_verre": {"projectile": "vague_verre", "impact": "eclat_verre"},
	"horloge_folle": {"projectile": "engrenage", "impact": "eclat_engrenage"},
	# Lot 9, tranchantes.
	"serpe_de_vigne": {"projectile": "serpe", "impact": "balayage"},
	"rasoir_tournoyant": {"projectile": "rasoir", "impact": "entaille"},
	"couperet_a_epines": {"projectile": "couperet", "impact": "entaille"},
	"lame_de_brume":
	{"projectile": "lame_croissant", "impact": "entaille", "teinte": Color(0.7, 0.85, 1.0)},
	"faucheuse_double":
	{"projectile": "lame_tournante", "impact": "eclat_acier", "teinte": Color(0.7, 1.0, 0.75)},
	"fleau_de_rasoirs": {"projectile": "rasoir", "impact": "eclat_acier"},
	"hache_de_garde": {"projectile": "hache", "impact": "eclat_acier"},
	"scie_a_ruban": {"projectile": "disque_scie", "impact": "eclat_acier"},
	"moissonneuse_d_acier": {"projectile": "faucille", "impact": "balayage"},
	# Lot 9, perçantes.
	"javeline_de_jet": {"projectile": "javeline", "impact": "gerbe"},
	"trait_en_gerbe": {"projectile": "aiguille", "impact": "gerbe"},
	"fleche_marquante": {"projectile": "fleche_marquante", "impact": "gerbe"},
	"arc_de_remparts":
	{"projectile": "carreau", "impact": "gerbe", "teinte": Color(1.0, 0.9, 0.75)},
	"herse_de_pieux": {"projectile": "pique", "impact": "pointes_sol"},
	"lance_epineuse": {"projectile": "lance_epineuse", "impact": "plante"},
	"carquois_en_rafale":
	{"projectile": "aiguille", "impact": "gerbe", "teinte": Color(1.0, 0.85, 0.7)},
	"mur_de_pointes":
	{"projectile": "pique", "impact": "pointes_sol", "teinte": Color(0.8, 1.0, 0.8)},
	"couronne_de_pointes": {"projectile": "chausse_trape", "impact": "pointes_sol"},
	# Lot 9, magiques.
	"rune_de_veille": {"projectile": "rune", "impact": "eclat_rune", "disque": "disque_rune"},
	"eclat_siphonneur": {"projectile": "siphon", "impact": "eclat_siphon"},
	"lueur_vagabonde": {"projectile": "lueur", "impact": "eclat_rune"},
	"prisme_de_faille": {"projectile": "prisme", "impact": "eclat_prisme"},
	"orage_en_cage":
	{"projectile": "etincelle", "impact": "eclat_astral", "disque": "disque_orage"},
	"couronne_d_etoiles": {"projectile": "etoile_astrale", "impact": "eclat_astral"},
	"vasque_d_arcanes": {"projectile": "vasque", "impact": "eclat_siphon"},
	"nuee_d_etincelles": {"projectile": "etincelle", "impact": "eclat_rune"},
	"nova_celeste": {"projectile": "vague_celeste", "impact": "eclat_astral"},
}

## Part de la durée d'un impact où l'on prend ses trois images : début, milieu, dissipation.
const PARTS_IMPACT: Array[float] = [0.2, 0.5, 0.8]


## La fiche de l'arme `id`, `{}` sans fiche.
static func de(id: String) -> Dictionary:
	return FICHES.get(id, {})


## Les rangs d'images (distincts, dans l'ordre) d'un impact de `n` images.
static func images_impact(n: int) -> Array[int]:
	var rangs: Array[int] = []
	for part: float in PARTS_IMPACT:
		var rang: int = roundi(float(n - 1) * part)
		if not rangs.has(rang):
			rangs.append(rang)
	return rangs
