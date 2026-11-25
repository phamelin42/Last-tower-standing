class_name AnnuaireProtocole
extends RefCounted
## Codec unique de l'annuaire (ADR 001, § Protocole) : cadre `u16 taille · corps`, cinq messages,
## bornes de champ. Le service et le client du jeu l'appellent tous deux ; aucun ne code d'octets
## à la main. Entiers petit-boutistes. Tout octet reçu vient d'un tiers : un message invalide,
## trop grand ou tronqué donne `{}` (ou `[]` / `-1`), jamais une exception.
##
## Les fonctions `encoder_*` renvoient un cadre complet (préfixe de taille compris), vide si un
## champ est hors bornes. Les fonctions `decoder_*` des requêtes prennent le corps seul, tel que
## le rend `analyser`.

enum Type { ANNONCE = 0x01, RETRAIT = 0x02, LISTE = 0x03, REPONSE = 0x81, SALONS = 0x83 }
enum Statut {
	ACCEPTE,
	VERSION_DIFFERENTE,
	INJOIGNABLE,
	DEBIT,
	INVALIDE,
	PLEIN,
	NON_PUBLIQUE,
	OCCUPE,
}
## Ce qu'on peut conclure des octets reçus jusqu'ici (`analyser`).
enum Analyse { ATTENTE, FERMER, VERSION_DIFFERENTE, TROP_GRAND, COMPLET }

const MAGIE: int = 0x41
## Version de l'annuaire, distincte de `Protocole.VERSION` (celle du jeu). Un changement de
## format l'incrémente ; le préfixe `u16` et les trois octets d'en-tête ne changent jamais.
const VERSION: int = 1
const PORT_DEFAUT: int = 7779

const MAX_CORPS_REQUETE: int = 128
const MAX_CADRE_CLIENT: int = 16384
const MAX_SALONS: int = 100
const PORT_MIN: int = 1024
const PORT_MAX: int = 65535
const MAX_NOM_CAR: int = Protocole.MAX_NOM
const MAX_NOM_OCTETS: int = Protocole.MAX_NOM * 4
const STATUT_MAX: int = 7
const TAILLE_EN_TETE: int = 3

# --- Encodage ----------------------------------------------------------------------------------


static func encoder_annonce(
	version_jeu: int, joueurs: int, maximum: int, port: int, nom: String
) -> PackedByteArray:
	if version_jeu < 0 or version_jeu > 255 or not _effectif_valide(joueurs, maximum):
		return PackedByteArray()
	if port < PORT_MIN or port > PORT_MAX or not _nom_valide(nom):
		return PackedByteArray()
	var corps := _en_tete(Type.ANNONCE)
	corps.append(version_jeu)
	corps.append(joueurs)
	corps.append(maximum)
	_ajouter_u16(corps, port)
	var octets := nom.to_utf8_buffer()
	corps.append(octets.size())
	corps.append_array(octets)
	return _cadre(corps)


static func encoder_retrait(port: int) -> PackedByteArray:
	if port < PORT_MIN or port > PORT_MAX:
		return PackedByteArray()
	var corps := _en_tete(Type.RETRAIT)
	_ajouter_u16(corps, port)
	return _cadre(corps)


static func encoder_liste() -> PackedByteArray:
	return _cadre(_en_tete(Type.LISTE))


static func encoder_reponse(statut: int) -> PackedByteArray:
	if statut < 0 or statut > STATUT_MAX:
		return PackedByteArray()
	var corps := _en_tete(Type.REPONSE)
	corps.append(statut)
	corps.append(VERSION)
	return _cadre(corps)


## `salons` : au plus 100 `{ip: "a.b.c.d", port, version_jeu, joueurs, max, nom}`.
static func encoder_salons(salons: Array[Dictionary]) -> PackedByteArray:
	if salons.size() > MAX_SALONS:
		return PackedByteArray()
	var corps := _en_tete(Type.SALONS)
	corps.append(salons.size())
	for s: Dictionary in salons:
		var ip := ip_en_octets(str(s.get("ip", "")))
		var port := int(s.get("port", 0))
		var v_jeu := int(s.get("version_jeu", -1))
		var joueurs := int(s.get("joueurs", -1))
		var maximum := int(s.get("max", 0))
		var nom := str(s.get("nom", ""))
		if ip.is_empty() or port < PORT_MIN or port > PORT_MAX or v_jeu < 0 or v_jeu > 255:
			return PackedByteArray()
		if not _effectif_valide(joueurs, maximum) or not _nom_valide(nom):
			return PackedByteArray()
		corps.append_array(ip)
		_ajouter_u16(corps, port)
		corps.append(v_jeu)
		corps.append(joueurs)
		corps.append(maximum)
		var octets := nom.to_utf8_buffer()
		corps.append(octets.size())
		corps.append_array(octets)
	return _cadre(corps)


# --- Décodage côté service ---------------------------------------------------------------------


## Analyse incrémentale du flux entrant, dans l'ordre des contrôles 3 à 7 de l'ADR. `octets` est
## tout ce qui est arrivé depuis l'acceptation. Renvoie `{etat: Analyse, corps: PackedByteArray}` ;
## `corps` n'est rempli que pour `COMPLET`. Les octets après le cadre sont ignorés.
static func analyser(octets: PackedByteArray) -> Dictionary:
	var resultat: Dictionary = {"etat": Analyse.ATTENTE, "corps": PackedByteArray()}
	if octets.size() < 2:
		return resultat
	var taille := octets[0] | (octets[1] << 8)
	if taille < TAILLE_EN_TETE:
		resultat["etat"] = Analyse.FERMER
		return resultat
	if octets.size() < 2 + TAILLE_EN_TETE:
		return resultat
	if octets[2] != MAGIE:
		resultat["etat"] = Analyse.FERMER
		return resultat
	if octets[3] != VERSION:
		resultat["etat"] = Analyse.VERSION_DIFFERENTE
		return resultat
	if taille > MAX_CORPS_REQUETE:
		resultat["etat"] = Analyse.TROP_GRAND
		return resultat
	if octets.size() < 2 + taille:
		return resultat
	resultat["etat"] = Analyse.COMPLET
	resultat["corps"] = octets.slice(2, 2 + taille)
	return resultat


## `Type` d'une requête (ANNONCE, RETRAIT ou LISTE), -1 si l'en-tête est faux ou le type inconnu.
static func type_de(corps: PackedByteArray) -> int:
	if corps.size() < TAILLE_EN_TETE or corps[0] != MAGIE or corps[1] != VERSION:
		return -1
	var type := corps[2]
	if type == Type.ANNONCE or type == Type.RETRAIT or type == Type.LISTE:
		return type
	return -1


## `{version_jeu, joueurs, max, port, nom}` ou `{}`.
static func decoder_annonce(corps: PackedByteArray) -> Dictionary:
	if type_de(corps) != Type.ANNONCE or corps.size() > MAX_CORPS_REQUETE:
		return {}
	var l := Protocole.LecteurOctets.new(corps)
	l.p = TAILLE_EN_TETE
	var version_jeu := l.u8()
	var joueurs := l.u8()
	var maximum := l.u8()
	var port := l.u16()
	var n := l.u8()
	if not l.ok or n < 1 or n > MAX_NOM_OCTETS:
		return {}
	var nom := l.texte(n, MAX_NOM_CAR)
	if not l.ok or l.reste() != 0 or nom.is_empty():
		return {}
	if not _effectif_valide(joueurs, maximum) or port < PORT_MIN or port > PORT_MAX:
		return {}
	return {
		"version_jeu": version_jeu, "joueurs": joueurs, "max": maximum, "port": port, "nom": nom
	}


## `{port}` ou `{}`.
static func decoder_retrait(corps: PackedByteArray) -> Dictionary:
	if type_de(corps) != Type.RETRAIT or corps.size() != TAILLE_EN_TETE + 2:
		return {}
	var l := Protocole.LecteurOctets.new(corps)
	l.p = TAILLE_EN_TETE
	var port := l.u16()
	if not l.ok or port < PORT_MIN or port > PORT_MAX:
		return {}
	return {"port": port}


static func decoder_liste(corps: PackedByteArray) -> bool:
	return type_de(corps) == Type.LISTE and corps.size() == TAILLE_EN_TETE


# --- Décodage côté client ----------------------------------------------------------------------


## Version d'annuaire d'un cadre reçu du service (la sienne ou une autre), -1 si ce n'en est pas
## un : le client s'en sert pour afficher « Annuaire incompatible » sans rien interpréter d'autre.
static func version_du_cadre(cadre: PackedByteArray) -> int:
	if cadre.size() < 2 + TAILLE_EN_TETE or cadre[2] != MAGIE:
		return -1
	return cadre[3]


## `{statut, version_service}` ou `{}` (taille mensongère, version autre, statut inconnu).
static func decoder_reponse(cadre: PackedByteArray) -> Dictionary:
	var l := _lecteur_de_cadre(cadre, Type.REPONSE)
	if l == null:
		return {}
	var statut := l.u8()
	var version_service := l.u8()
	if not l.ok or l.reste() != 0 or statut > STATUT_MAX:
		return {}
	return {"statut": statut, "version_service": version_service}


## `{salons: Array[Dictionary]}` (mêmes champs qu'à l'encodage) ou `{}`.
static func decoder_salons(cadre: PackedByteArray) -> Dictionary:
	var l := _lecteur_de_cadre(cadre, Type.SALONS)
	if l == null:
		return {}
	var n := l.u8()
	if not l.ok or n > MAX_SALONS:
		return {}
	var salons: Array[Dictionary] = []
	for i: int in n:
		# Chaque salon pèse au moins 12 octets : le compteur est vérifié avant d'allouer.
		if l.reste() < 12:
			return {}
		var ip := "%d.%d.%d.%d" % [l.u8(), l.u8(), l.u8(), l.u8()]
		var port := l.u16()
		var version_jeu := l.u8()
		var joueurs := l.u8()
		var maximum := l.u8()
		var taille_nom := l.u8()
		if taille_nom < 1 or taille_nom > MAX_NOM_OCTETS:
			return {}
		var nom := l.texte(taille_nom, MAX_NOM_CAR)
		if not l.ok or nom.is_empty():
			return {}
		if not _effectif_valide(joueurs, maximum) or port < PORT_MIN or port > PORT_MAX:
			return {}
		(
			salons
			. append(
				{
					"ip": ip,
					"port": port,
					"version_jeu": version_jeu,
					"joueurs": joueurs,
					"max": maximum,
					"nom": nom,
				}
			)
		)
	if l.reste() != 0:
		return {}
	return {"salons": salons}


# --- Adresses ----------------------------------------------------------------------------------


## Les quatre octets d'une IPv4 « a.b.c.d » (décimal strict), vide sinon.
static func ip_en_octets(ip: String) -> PackedByteArray:
	var parties := ip.split(".")
	if parties.size() != 4:
		return PackedByteArray()
	var octets := PackedByteArray()
	for partie: String in parties:
		if partie.is_empty() or partie.length() > 3 or not partie.is_valid_int():
			return PackedByteArray()
		if partie.begins_with("+") or partie.begins_with("-"):
			return PackedByteArray()
		var v := partie.to_int()
		if v > 255:
			return PackedByteArray()
		octets.append(v)
	return octets


# --- Interne -----------------------------------------------------------------------------------


static func _effectif_valide(joueurs: int, maximum: int) -> bool:
	return maximum >= 1 and maximum <= Salon.MAX_JOUEURS and joueurs >= 0 and joueurs <= maximum


static func _nom_valide(nom: String) -> bool:
	if nom.is_empty() or nom.length() > MAX_NOM_CAR or not Protocole._texte_sain(nom):
		return false
	return nom.to_utf8_buffer().size() <= MAX_NOM_OCTETS


static func _en_tete(type: int) -> PackedByteArray:
	return PackedByteArray([MAGIE, VERSION, type])


static func _ajouter_u16(b: PackedByteArray, v: int) -> void:
	b.append(v & 0xFF)
	b.append((v >> 8) & 0xFF)


static func _cadre(corps: PackedByteArray) -> PackedByteArray:
	var cadre := PackedByteArray()
	_ajouter_u16(cadre, corps.size())
	cadre.append_array(corps)
	return cadre


## Lecteur placé après l'en-tête d'un cadre complet de service (taille cohérente, au plus
## 16 384 octets, magie, version et type attendus), `null` sinon.
static func _lecteur_de_cadre(cadre: PackedByteArray, type: int) -> Protocole.LecteurOctets:
	if cadre.size() < 2 + TAILLE_EN_TETE:
		return null
	var taille := cadre[0] | (cadre[1] << 8)
	if taille > MAX_CADRE_CLIENT or cadre.size() != 2 + taille:
		return null
	if cadre[2] != MAGIE or cadre[3] != VERSION or cadre[4] != type:
		return null
	var l := Protocole.LecteurOctets.new(cadre)
	l.p = 2 + TAILLE_EN_TETE
	return l
