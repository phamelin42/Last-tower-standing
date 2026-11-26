extends RefCounted
## Les 30 armes du lot 8, qui ont déjà leur signature (`SignaturesArmes`) et leur son de tir
## (`CatalogueSons`). Le lot 9 ajoute ses armes aux données avant leur rendu (T9.18) et leurs sons
## (T9.20) : d'ici là, les tests n'exigent plus une ligne par arme des données, mais celles-ci ne
## perdent jamais la leur. T9.18 et T9.20 rétablissent l'égalité stricte et retirent ce fichier.

const IDS: Array[String] = [
	"lame_de_fil",
	"faucille_a_ressort",
	"disque_scie",
	"moulinet_de_cuivre",
	"guillotine_a_vapeur",
	"tourbillon_d_acier",
	"arbalete_de_bureau",
	"chausse_trape",
	"carreau_ricochet",
	"herse_de_ressorts",
	"baliste_de_guet",
	"pluie_d_aiguilles",
	"etincelle_runique",
	"orbe_de_brume",
	"chaine_d_arcanes",
	"cercle_de_givre",
	"nova_d_ambre",
	"tempete_astrale",
	"bombarde_de_poche",
	"petard_de_rempart",
	"trebuchet_de_chambre",
	"mine_de_forge",
	"canon_de_cloche",
	"grande_bombarde",
	"de_pipe",
	"sablier_fele",
	"cornue_instable",
	"miroir_brise",
	"vortex_de_verre",
	"horloge_folle",
]
