class_name TeintesStatut
extends RefCounted
## La teinte posée sur un ennemi selon l'octet de ses statuts (`Types.STATUT_*`). Un seul statut se
## lit, le plus gênant d'abord : étourdi, brûlé, empoisonné, gelé, ralenti, puis les trois du lot 9
## (vulnérable, maudit, siphonné). Chaque teinte s'écarte d'au moins 0,2 de toutes les autres, du
## blanc et de celle des alliés (un test le vérifie).

const ETOURDI := Color(1.0, 0.92, 0.45)
const BRULE := Color(1.0, 0.6, 0.4)
const EMPOISONNE := Color(0.6, 1.0, 0.55)
const GELE := Color(0.6, 0.85, 1.0)
const RALENTI := Color(0.8, 0.7, 1.0)
const VULNERABLE := Color(1.0, 0.45, 0.6)
const MAUDIT := Color(0.7, 0.45, 0.9)
const SIPHONNE := Color(0.4, 0.8, 0.8)


## Blanc sans statut.
static func teinte(octet: int) -> Color:
	if octet & Types.STATUT_ETOURDI != 0:
		return ETOURDI
	if octet & Types.STATUT_BRULE != 0:
		return BRULE
	if octet & Types.STATUT_EMPOISONNE != 0:
		return EMPOISONNE
	if octet & Types.STATUT_GELE != 0:
		return GELE
	if octet & Types.STATUT_RALENTI != 0:
		return RALENTI
	if octet & Types.STATUT_VULNERABLE != 0:
		return VULNERABLE
	if octet & Types.STATUT_MAUDIT != 0:
		return MAUDIT
	if octet & Types.STATUT_SIPHONNE != 0:
		return SIPHONNE
	return Color.WHITE
