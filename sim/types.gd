class_name Types
extends RefCounted
## Énumérations et constantes partagées par toute la simulation. Les valeurs entières
## suivent l'ordre des lignes et colonnes de `data/efficacite.json`.

enum TypeDegats { TRANCHANT, PERCANT, MAGIQUE, SIEGE, CHAOS }
enum Armure { LEGERE, MOYENNE, LOURDE, FORTIFIEE, AUCUNE, BOSS }
enum Rarete { COMMUNE, PEU_COMMUNE, RARE, EPIQUE, ANCESTRALE, SOUVERAINE }
enum Ciblage { PLUS_PROCHE, PLUS_FORT, PLUS_FAIBLE }
enum Phase { PREPARATION, MANCHE, BOSS, VICTOIRE, DEFAITE }
enum Genre { ARME, AMELIORATION }
## Catégorie d'une offre, reconnue d'un coup d'œil. Une arme est toujours `ARME` ; les
## améliorations portent la leur dans `data/ameliorations.json`.
enum Categorie { ARME, AMELIORATION, REVENU }
enum ClassePortee { CORPS_A_CORPS, MOYENNE, LONGUE }
enum Resultat {
	OK,
	OR_INSUFFISANT,
	EMPLACEMENTS_PLEINS,
	OFFRE_INVALIDE,
	DEJA_ACHETE,
	MAUVAISE_PHASE,
	ARENE_MORTE,
	INDICE_INVALIDE,
	NON_DISPONIBLE,
	# Ajouté à la fin : le réseau transporte ces codes, EMPLACEMENTS_PLEINS ne se renumérote pas.
	ARMES_AU_MAXIMUM,
}

const STATUT_GELE := 1
const STATUT_RALENTI := 2
const STATUT_EMPOISONNE := 4
const STATUT_BRULE := 8
const STATUT_ETOURDI := 16
## Lot 9 : les bits de `Ennemis.statuts`, un octet en tout (8 sur 8 utilisés). `STATUT_MAUDIT`
## vaut pour l'une ou l'autre des deux malédictions.
const STATUT_VULNERABLE := 32
const STATUT_MAUDIT := 64
const STATUT_SIPHONNE := 128

# Noms tels que les écrivent les fichiers de données, dans l'ordre des enums. La comparaison est
# stricte : sans accent, en majuscules ou avec une espace en trop, un nom est refusé (-1), pour
# qu'une faute de frappe dans un fichier soit vue au chargement et non ignorée.
const NOMS_TYPES: Array[String] = ["tranchant", "perçant", "magique", "siège", "chaos"]
const NOMS_ARMURES: Array[String] = ["légère", "moyenne", "lourde", "fortifiée", "aucune", "boss"]
const NOMS_RARETES: Array[String] = [
	"commune", "peu_commune", "rare", "epique", "ancestrale", "souveraine"
]
const NOMS_CIBLAGES: Array[String] = ["plus_proche", "plus_fort", "plus_faible"]
const NOMS_CATEGORIES: Array[String] = ["arme", "amelioration", "revenu"]
const NOMS_CLASSES_PORTEE: Array[String] = ["corps_a_corps", "moyenne", "longue"]
## Champ `famille` d'une amélioration (`data/ameliorations.json`) : l'effectif cible du catalogue
## se compte par famille.
const FAMILLES_AMELIORATION: Array[String] = [
	"degats_type",
	"degats_global",
	"degats_classe",
	"cadence",
	"etats",
	"epines",
	"pv_max",
	"regeneration",
	"armure",
	"esquive",
	"mana",
	"revenu",
	"boutique",
	"aura_mixte",
	"critique",
]


## « tranchant » → TRANCHANT ; -1 si inconnu.
static func type_depuis_nom(nom: String) -> int:
	return NOMS_TYPES.find(nom)


static func armure_depuis_nom(nom: String) -> int:
	return NOMS_ARMURES.find(nom)


static func rarete_depuis_nom(nom: String) -> int:
	return NOMS_RARETES.find(nom)


static func ciblage_depuis_nom(nom: String) -> int:
	return NOMS_CIBLAGES.find(nom)


static func categorie_depuis_nom(nom: String) -> int:
	return NOMS_CATEGORIES.find(nom)


static func classe_portee_depuis_nom(nom: String) -> int:
	return NOMS_CLASSES_PORTEE.find(nom)
