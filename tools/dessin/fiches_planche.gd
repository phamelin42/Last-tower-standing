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
	# Lot 9, siège.
	"baril_a_retardement": {"projectile": "baril", "impact": "explosion_feu"},
	"maillet_de_rempart": {"projectile": "maillet", "impact": "onde_choc"},
	"catapulte_a_contrepoids": {"projectile": "pierre_lestee", "impact": "cratere"},
	"obusier_de_breche": {"projectile": "obus", "impact": "pop_petard"},
	"braise_de_siege":
	{"projectile": "brasero", "impact": "explosion_feu", "disque": "disque_braise"},
	"ecrasement_de_tour": {"projectile": "creneau", "impact": "onde_choc"},
	"champ_de_ruines": {"projectile": "gravats", "impact": "cratere", "disque": "disque_ruines"},
	"salve_du_rempart":
	{"projectile": "bombe", "impact": "pop_petard", "teinte": Color(1.0, 0.8, 0.65)},
	"colosse_de_pierre": {"projectile": "bloc_colosse", "impact": "cratere"},
	# Lot 9, chaos.
	"urne_des_ombres": {"projectile": "urne", "impact": "eclat_siphon"},
	"pacte_de_sang": {"projectile": "goutte_sang", "impact": "eclat_astral"},
	"engrenage_jumeau": {"projectile": "engrenage_double", "impact": "eclat_engrenage"},
	"serment_brise": {"projectile": "serment", "impact": "eclat_prisme"},
	"archere_fantome": {"projectile": "fleche_spectre", "impact": "eclat_rune"},
	"miroir_de_discorde": {"projectile": "eclat_discorde", "impact": "gerbe_verre"},
	"coupe_d_oubli": {"projectile": "coupe", "impact": "eclat_des"},
	"legion_de_cendre": {"projectile": "cendre", "impact": "tourbillon_sable"},
	"tempete_de_malefices": {"projectile": "malefice", "impact": "eclat_astral"},
	# Fin de partie (T12.7) : planches existantes réutilisées, en attendant des dessins propres.
	"lame_des_aieux":
	{"projectile": "lame_croissant", "impact": "entaille"},
	"ouragan_de_lames": {"projectile": "lame_tournante", "impact": "eclat_acier"},
	"faux_du_dernier_jour": {"projectile": "arc_lame", "impact": "balayage"},
	"carquois_des_ancetres": {"projectile": "carreau", "impact": "gerbe"},
	"epine_de_mille_ans": {"projectile": "pique", "impact": "pointes_sol"},
	"pique_du_souverain":
	{"projectile": "chausse_trape", "impact": "pointes_sol"},
	"sceptre_des_astres": {"projectile": "etoile_astrale", "impact": "eclat_astral"},
	"sablier_d_aurore": {"projectile": "rune", "impact": "eclat_rune", "disque": "disque_rune"},
	"oeil_du_firmament": {"projectile": "vague_celeste", "impact": "eclat_astral"},
	"catapulte_des_anciens": {"projectile": "rocher", "impact": "cratere"},
	"lance_braise_du_conquerant": {"projectile": "baril", "impact": "explosion_feu"},
	"canon_du_dernier_rempart": {"projectile": "bloc_colosse", "impact": "cratere"},
	"urne_des_mille_ombres": {"projectile": "urne", "impact": "eclat_siphon"},
	"pendule_du_desordre": {"projectile": "de_pipe", "impact": "eclat_des"},
	"couronne_du_vide":
	{"projectile": "eclat_miroir", "impact": "gerbe_verre", "disque": "disque_orage"},
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
