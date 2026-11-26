class_name Protocole
extends RefCounted
## Protocole binaire compact entre serveur et clients (little-endian). Tout octet reçu vient
## d'un tiers : chaque décodeur vérifie la taille globale, puis chaque compteur contre les octets
## restants, AVANT toute boucle ou allocation. Un paquet invalide donne `null` (ou `{}` / `""`),
## jamais une exception ni un message d'erreur.
##
## Quantification des positions : `i16` en 1/16 d'unité, arrondi au plus proche. L'erreur est donc
## d'au plus 1/32 d'unité (`ERREUR_POS_MAX`) pour toute position dans ±`POS_MAX` ; au-delà, la
## position est ramenée au bord. Le rayon de l'arène est 1 300, `POS_MAX` ≈ 2 048.
##
## Hors de ce que la spécification chiffre : `rayon` d'un événement est codé par pas de 8 unités ;
## `t` d'un événement n'est pas transmis (il vaut le `tick` du message) ; les événements au-delà de
## `MAX_EVENEMENTS` sont abandonnés (effets visuels seulement).

enum Msg {
	BONJOUR = 1,
	ETAT_ARENE,
	ETAT_GLOBAL,
	INTENTION,
	SALON,
	REFUS,
	RESULTAT,
	ETAT_ARENE_REGARDEE,
	BILAN
}
enum Intention {
	ACHETER = 1, RELANCER, VENDRE, MARCHE_NOIR, OBSERVER, SANS_FIN, QUITTER, PRET, OPTIONS, REGARDER
}

## 2 : ajout de `RESULTAT` (réponse du serveur à chaque intention).
## 3 : un octet de plus par événement d'arène (genre et statut de l'arme, T5.3b).
## 4 : le bonjour porte un jeton d'hôte (0 ou 8 octets, T7.2b).
## 5 : armes jusqu'à 255, mana, familles suivantes (jusqu'à 3), arme et événement `absorption`
##     dans les événements (14 octets), `dps` et densités dans l'état global, état d'arène
##     regardée, intention `REGARDER` (lot 8).
## 6 : l'état global porte les PV et les PV max de la tour de chaque joueur (8 octets de plus
##     par joueur, suivi S14).
## 7 : alliés (5 octets), zones posées (7) et bombes (6) dans l'état d'arène, trois compteurs de
##     plus ; les genres et statuts d'événement du lot 9 (4 bits chacun, format inchangé) ne sont
##     lisibles que par cette version (lot 9).
## 8 : message `BILAN`, le bilan de fin de partie envoyé à chaque joueur présent (lot 11).
## 9 : l'état d'arène porte quatre flottants d'apparence de la tour de plus (épines, esquive,
##     régénération, vol de vie : 16 octets), aussi pour l'arène regardée (lot 9, D19).
const VERSION: int = 9
## Taille du jeton d'hôte ; un bonjour sans jeton en porte 0.
const JETON_OCTETS: int = 8
const MAX_ENNEMIS: int = 2000
const MAX_EVENEMENTS: int = 64
const MAX_TAILLE: int = 65536

const MAX_NOM: int = 24
const MAX_TEXTE_OCTETS: int = 64
const MAX_MOTIF_OCTETS: int = 200
const MAX_JOUEURS: int = 16
const MAX_OFFRES: int = 8
const MAX_ARMES: int = 255
## Plafonds d'alliés, de zones et de bombes : ceux de `partie.json` `limites` (un test les compare).
const MAX_ALLIES: int = VueArene.ALLIES_MAX
const MAX_ZONES: int = VueArene.ZONES_MAX
const MAX_BOMBES: int = VueArene.BOMBES_MAX
## Familles annoncées pour la manche suivante.
const MAX_FAMILLES_SUIVANTES: int = 3
## Plus grand identifiant de joueur qu'on peut regarder : un identifiant de joueur est celui du
## pair ENet, un entier de 32 bits aléatoire (il ne tient donc pas sur un octet).
const MAX_ID_REGARDE: int = 0x7FFFFFFF
## Plus grand index de famille transportable (un octet, 0 à 127).
const MAX_FAMILLE: int = 127

const ECHELLE_POS: float = 16.0
const POS_MAX: float = 32767.0 / 16.0
const ERREUR_POS_MAX: float = 1.0 / 32.0

## Octets d'un état d'arène sans offre, arme, amélioration, ennemi, événement, allié, zone ni
## bombe.
const TAILLE_FIXE: int = 79
const OFFSET_PHASE: int = 5
const OFFSET_TOUR_PV: int = 11
const OFFSET_MANA: int = 36
## Début des quatre flottants d'apparence (épines, esquive, régénération, vol de vie), juste après
## la mana maximale.
const OFFSET_APPARENCE: int = 44
const OFFSET_NB_FAMILLES: int = 60
## Famille et armure de la première famille suivante (présentes si `OFFSET_NB_FAMILLES` ≥ 1).
const OFFSET_FAMILLE: int = 61
const OFFSET_ARMURE: int = 62
const OFFSET_NB_JOUEURS: int = 10

const _OCTETS_ENNEMI: int = 9
const _OCTETS_EVENEMENT: int = 14
const _OCTETS_JOUEUR_MIN: int = 30
## Octets d'une carte de densité diffusée : identifiant (i32) et 256 cases.
const _OCTETS_DENSITE: int = 4 + VueGlobale.DENSITE_OCTETS
const _SANS_ARME: int = 0xFFFF
const _MAX_NOM_OCTETS: int = MAX_NOM * 4
const _MAX_BONJOUR: int = 3 + _MAX_NOM_OCTETS + 8 + 1 + JETON_OCTETS
const _MAX_INTENTION: int = 7 + MAX_TEXTE_OCTETS
const _MAX_REFUS: int = 2 + MAX_MOTIF_OCTETS
const _TAILLE_RESULTAT: int = 3
const _GENRES_EVENEMENT: Array[String] = ["tir", "impact", "mort", "absorption"]

# --- Bonjour ---------------------------------------------------------------------------------


## `u8 type · u8 version · u8 n + nom UTF-8 · i64 empreinte · u8 m + jeton`. Le nom est tronqué à
## 24 caractères par l'émetteur (et nettoyé de ses caractères de contrôle). Le jeton d'hôte vaut 0
## octet (client ordinaire) ou 8 ; l'encodeur écrit celui qu'on lui donne (au plus 255 octets)
## pour que les tests forgent des bonjours faux, le décodeur n'en accepte que deux tailles.
static func encoder_bonjour(
	nom: String, empreinte: int, jeton: PackedByteArray = PackedByteArray()
) -> PackedByteArray:
	var octets := _nom_en_octets(nom)
	var e := _Ecrivain.new(_MAX_BONJOUR + 255)
	e.u8(Msg.BONJOUR)
	e.u8(VERSION)
	e.u8(octets.size())
	e.octets(octets)
	e.i64(empreinte)
	e.u8(jeton.size())
	e.octets(jeton.slice(0, 255))
	return e.fin()


## `{version, nom, empreinte, jeton}`, ou `{}` si le paquet est invalide, de version différente
## (voir `version_bonjour`), ou si le nom dépasse 24 caractères.
static func decoder_bonjour(b: PackedByteArray) -> Dictionary:
	if b.size() > _MAX_BONJOUR:
		return {}
	var l := LecteurOctets.new(b)
	if l.u8() != Msg.BONJOUR or l.u8() != VERSION:
		return {}
	var nom := l.texte(l.u8(), MAX_NOM)
	var empreinte := l.i64()
	var taille_jeton := l.u8()
	if not l.ok or (taille_jeton != 0 and taille_jeton != JETON_OCTETS):
		return {}
	var jeton := PackedByteArray()
	for i: int in taille_jeton:
		jeton.append(l.u8())
	if not l.ok or l.reste() != 0:
		return {}
	return {"version": VERSION, "nom": nom, "empreinte": empreinte, "jeton": jeton}


## Version annoncée par un paquet `BONJOUR` (même d'une autre version), -1 si ce n'en est pas un :
## le serveur s'en sert pour refuser avec `motif_version`.
static func version_bonjour(b: PackedByteArray) -> int:
	if b.size() < 2 or b.size() > _MAX_BONJOUR or b[0] != Msg.BONJOUR:
		return -1
	return b[1]


static func motif_version(version_recue: int) -> String:
	return "Version du protocole différente : reçue %d, attendue %d." % [version_recue, VERSION]


# --- Intention et refus ----------------------------------------------------------------------


## `u8 type · u8 genre · i32 arg · u8 n + texte UTF-8`. Vide si le genre est inconnu ou le texte
## trop long (64 octets) ou invalide ; pour `REGARDER`, l'argument est -1 (cesser) ou un
## identifiant de joueur (0 à `MAX_ID_REGARDE`).
static func encoder_intention(genre: int, arg: int, texte: String = "") -> PackedByteArray:
	if genre < Intention.ACHETER or genre > Intention.REGARDER:
		return PackedByteArray()
	if genre == Intention.REGARDER and not _id_regarde_valide(arg):
		return PackedByteArray()
	var octets := texte.to_utf8_buffer()
	if octets.size() > MAX_TEXTE_OCTETS or not _texte_sain(texte):
		return PackedByteArray()
	var e := _Ecrivain.new(_MAX_INTENTION)
	e.u8(Msg.INTENTION)
	e.u8(genre)
	e.i32(arg)
	e.u8(octets.size())
	e.octets(octets)
	return e.fin()


## `{genre, arg, texte}` ou `{}`.
static func decoder_intention(b: PackedByteArray) -> Dictionary:
	if b.size() > _MAX_INTENTION:
		return {}
	var l := LecteurOctets.new(b)
	if l.u8() != Msg.INTENTION:
		return {}
	var genre := l.u8()
	var arg := l.i32()
	var n := l.u8()
	if n > MAX_TEXTE_OCTETS:
		return {}
	var texte := l.texte(n, MAX_TEXTE_OCTETS)
	if not l.ok or l.reste() != 0:
		return {}
	if genre < Intention.ACHETER or genre > Intention.REGARDER:
		return {}
	if genre == Intention.REGARDER and not _id_regarde_valide(arg):
		return {}
	return {"genre": genre, "arg": arg, "texte": texte}


## `u8 type · u8 n + motif UTF-8`. Le motif est tronqué à 200 octets.
static func encoder_refus(motif: String) -> PackedByteArray:
	var propre := _sans_controle(motif.substr(0, MAX_MOTIF_OCTETS))
	while propre.to_utf8_buffer().size() > MAX_MOTIF_OCTETS:
		propre = propre.substr(0, propre.length() - 1)
	var octets := propre.to_utf8_buffer()
	var e := _Ecrivain.new(_MAX_REFUS)
	e.u8(Msg.REFUS)
	e.u8(octets.size())
	e.octets(octets)
	return e.fin()


## Le motif, ou `""` si le paquet est invalide.
static func decoder_refus(b: PackedByteArray) -> String:
	if b.size() > _MAX_REFUS:
		return ""
	var l := LecteurOctets.new(b)
	if l.u8() != Msg.REFUS:
		return ""
	var n := l.u8()
	if n > MAX_MOTIF_OCTETS:
		return ""
	var motif := l.texte(n, MAX_MOTIF_OCTETS)
	if not l.ok or l.reste() != 0:
		return ""
	return motif


## `u8 type · u8 genre · u8 code` : ce que le serveur a répondu à une intention (`genre` =
## `Intention`, `code` = `Types.Resultat`). Vide si l'un des deux est hors bornes.
static func encoder_resultat(genre: int, code: int) -> PackedByteArray:
	if genre < Intention.ACHETER or genre > Intention.REGARDER:
		return PackedByteArray()
	if code < Types.Resultat.OK or code > Types.Resultat.ARMES_AU_MAXIMUM:
		return PackedByteArray()
	var e := _Ecrivain.new(_TAILLE_RESULTAT)
	e.u8(Msg.RESULTAT)
	e.u8(genre)
	e.u8(code)
	return e.fin()


## `{genre, code}`, ou `{}` si le paquet est invalide.
static func decoder_resultat(b: PackedByteArray) -> Dictionary:
	if b.size() != _TAILLE_RESULTAT:
		return {}
	var l := LecteurOctets.new(b)
	if l.u8() != Msg.RESULTAT:
		return {}
	var genre := l.u8()
	var code := l.u8()
	if not l.ok or l.reste() != 0:
		return {}
	if genre < Intention.ACHETER or genre > Intention.REGARDER:
		return {}
	if code < Types.Resultat.OK or code > Types.Resultat.ARMES_AU_MAXIMUM:
		return {}
	return {"genre": genre, "code": code}


## Type du message (`Msg`) d'un paquet, -1 s'il est vide, trop grand ou de type inconnu.
static func type_de(b: PackedByteArray) -> int:
	if b.is_empty() or b.size() > MAX_TAILLE:
		return -1
	if b[0] < Msg.BONJOUR or b[0] > Msg.BILAN:
		return -1
	return b[0]


# --- Bilan de partie -------------------------------------------------------------------------


## Voir `ProtocoleBilan` : tableau vide si le bilan n'est pas représentable.
static func encoder_bilan(bilan: Dictionary) -> PackedByteArray:
	return ProtocoleBilan.encoder(bilan)


## `{}` si le paquet est invalide.
static func decoder_bilan(b: PackedByteArray) -> Dictionary:
	return ProtocoleBilan.decoder(b)


# --- État global -----------------------------------------------------------------------------


## `u8 type · f32 temps · u8 flags · i32 dernier_rempart · u8 n_joueurs` puis par joueur
## `[i32 id · u8 n + nom · u16 manche · u16 eliminations · f32 degats · f32 dps · f32 pv ·
## f32 pv_max · i32 revenu · u8 flags]`, `u8 n_classement · n × i32`,
## `u8 n_densites · n × [i32 id · 256 octets]`. Vide si plus de 16 joueurs, 16 rangs ou 16
## cartes, ou si une carte n'a pas 256 octets.
static func encoder_etat_global(v: VueGlobale) -> PackedByteArray:
	if v.joueurs.size() > MAX_JOUEURS or v.classement.size() > MAX_JOUEURS:
		return PackedByteArray()
	if v.densites.size() > MAX_JOUEURS:
		return PackedByteArray()
	for id: Variant in v.densites:
		if typeof(id) != TYPE_INT or typeof(v.densites[id]) != TYPE_PACKED_BYTE_ARRAY:
			return PackedByteArray()
		var carte_brute: PackedByteArray = v.densites[id]
		if carte_brute.size() != VueGlobale.DENSITE_OCTETS:
			return PackedByteArray()
	var capacite := 11 + 1 + 4 * MAX_JOUEURS + 1 + _OCTETS_DENSITE * v.densites.size()
	capacite += v.joueurs.size() * (_OCTETS_JOUEUR_MIN + _MAX_NOM_OCTETS)
	var e := _Ecrivain.new(capacite)
	e.u8(Msg.ETAT_GLOBAL)
	e.f32(v.temps_ecoule)
	e.u8((1 if v.en_cours else 0) | (2 if v.termine else 0))
	e.i32(v.dernier_rempart)
	e.u8(v.joueurs.size())
	for j: Dictionary in v.joueurs:
		var nom := _nom_en_octets(String(j["nom"]))
		e.i32(int(j["id"]))
		e.u8(nom.size())
		e.octets(nom)
		e.u16(int(j["manche"]))
		e.u16(int(j["eliminations"]))
		e.f32(float(j["degats"]))
		e.f32(float(j.get("dps", 0.0)))
		e.f32(float(j.get("pv", 0.0)))
		e.f32(float(j.get("pv_max", 0.0)))
		e.i32(int(j["revenu"]))
		e.u8((1 if bool(j["vivant"]) else 0) | (2 if bool(j["victorieux"]) else 0))
	e.u8(v.classement.size())
	for rang: int in v.classement:
		e.i32(rang)
	e.u8(v.densites.size())
	for id: int in v.densites:
		var carte: PackedByteArray = v.densites[id]
		e.i32(id)
		e.octets(carte)
	return e.fin()


## `null` si le paquet est invalide (tronqué, compteur mensonger, nom non UTF-8 ou trop long…).
static func decoder_etat_global(b: PackedByteArray) -> VueGlobale:
	if b.size() > MAX_TAILLE:
		return null
	var l := LecteurOctets.new(b)
	if l.u8() != Msg.ETAT_GLOBAL:
		return null
	var v := VueGlobale.new()
	v.temps_ecoule = l.f32()
	var flags := l.u8()
	if flags & ~3 != 0:
		return null
	v.en_cours = flags & 1 != 0
	v.termine = flags & 2 != 0
	v.dernier_rempart = l.i32()
	var n := l.u8()
	if n > MAX_JOUEURS or not l.exiger(n * _OCTETS_JOUEUR_MIN):
		return null
	for i in n:
		var id := l.i32()
		var nom := l.texte(l.u8(), MAX_NOM)
		var manche := l.u16()
		var eliminations := l.u16()
		var degats := l.f32()
		var dps := l.f32()
		var pv := l.f32()
		var pv_max := l.f32()
		var revenu := l.i32()
		var drapeaux := l.u8()
		if not l.ok or drapeaux & ~3 != 0:
			return null
		(
			v
			. joueurs
			. append(
				{
					"id": id,
					"nom": nom,
					"manche": manche,
					"eliminations": eliminations,
					"degats": degats,
					"dps": dps,
					"pv": pv,
					"pv_max": pv_max,
					"revenu": revenu,
					"vivant": drapeaux & 1 != 0,
					"victorieux": drapeaux & 2 != 0,
				}
			)
		)
	var rangs := l.u8()
	if rangs > MAX_JOUEURS or not l.exiger(4 * rangs):
		return null
	for i in rangs:
		v.classement.append(l.i32())
	var cartes := l.u8()
	if cartes > MAX_JOUEURS or not l.exiger(_OCTETS_DENSITE * cartes):
		return null
	for i in cartes:
		var id_carte := l.i32()
		if v.densites.has(id_carte):
			return null
		v.densites[id_carte] = b.slice(l.p, l.p + VueGlobale.DENSITE_OCTETS)
		l.p += VueGlobale.DENSITE_OCTETS
	if not l.ok or l.reste() != 0:
		return null
	return v


# --- État d'arène ----------------------------------------------------------------------------


## Voir la spécification (§ 4) pour la disposition. Renvoie un tableau VIDE (refus explicite,
## rien n'est envoyé) si l'état n'est pas représentable : plus de 2 000 ennemis, tableaux
## d'ennemis de tailles différentes, identifiant absent du catalogue, genre/rareté/phase hors
## bornes, plus de 255 armes, 8 offres ou 3 familles suivantes, arme hors catalogue, plus d'alliés,
## de zones ou de bombes que les plafonds, un allié dont l'unité est hors de `nb_unites` (si elle
## est donnée), une zone ou une bombe au rayon ou au temps restant non fini ou négatif. Les
## événements au-delà de 64 sont abandonnés.
static func encoder_etat_arene(
	v: VueArene, catalogue: PackedStringArray, nb_unites: int = -1
) -> PackedByteArray:
	var n := v.ennemis_id.size()
	var coherent := (
		n <= MAX_ENNEMIS
		and v.ennemis_pos.size() == n
		and v.ennemis_famille.size() == n
		and v.ennemis_pv.size() == n
		and v.ennemis_statuts.size() == n
		and v.offres.size() <= MAX_OFFRES
		and v.armes.size() <= MAX_ARMES
		and v.ameliorations.size() <= 65535
		and v.prochaines_familles.size() <= MAX_FAMILLES_SUIVANTES
		and v.allies.size() <= MAX_ALLIES
		and v.zones.size() <= MAX_ZONES
		and v.bombes.size() <= MAX_BOMBES
		and v.phase >= Types.Phase.PREPARATION
		and v.phase <= Types.Phase.DEFAITE
	)
	if not coherent:
		return PackedByteArray()
	# Un état qui ne renseigne que `prochaine_famille` (un producteur d'avant le lot 8) annonce une
	# seule famille : `prochaines_familles` n'est lu en premier que s'il est rempli.
	var familles_suivantes := v.prochaines_familles
	var armures_suivantes := v.prochaines_armures
	if familles_suivantes.is_empty() and v.prochaine_famille >= 0:
		familles_suivantes = PackedInt32Array([v.prochaine_famille])
		armures_suivantes = PackedByteArray([clampi(v.prochaine_armure, 0, Types.Armure.BOSS)])
	if armures_suivantes.size() != familles_suivantes.size():
		return PackedByteArray()
	for i in familles_suivantes.size():
		if familles_suivantes[i] < 0 or familles_suivantes[i] > MAX_FAMILLE:
			return PackedByteArray()
		if armures_suivantes[i] > Types.Armure.BOSS:
			return PackedByteArray()
	var indices_offres := PackedInt32Array()
	var drapeaux_offres := PackedByteArray()
	for o: Dictionary in v.offres:
		var genre := int(o["genre"])
		var rarete := int(o["rarete"])
		var idx := catalogue.find(String(o["id"]))
		if idx < 0 or genre < 0 or genre > 1 or rarete < 0 or rarete > 3:
			return PackedByteArray()
		indices_offres.append(idx)
		drapeaux_offres.append(genre | (rarete << 1) | ((1 if bool(o["vendu"]) else 0) << 4))
	var indices_armes := PackedInt32Array()
	for a: Dictionary in v.armes:
		var idx := catalogue.find(String(a["id"]))
		if idx < 0:
			return PackedByteArray()
		indices_armes.append(idx)
	var indices_amelios := PackedInt32Array()
	var comptes_amelios := PackedByteArray()
	for id: Variant in v.ameliorations:
		var idx := catalogue.find(String(id))
		if idx < 0:
			return PackedByteArray()
		indices_amelios.append(idx)
		comptes_amelios.append(clampi(int(v.ameliorations[id]), 0, 255))
	var genres_evt := PackedByteArray()
	var armes_evt := PackedInt32Array()
	var nb_evt := mini(v.evenements.size(), MAX_EVENEMENTS)
	for i in nb_evt:
		var g := _GENRES_EVENEMENT.find(String(v.evenements[i]["k"]))
		if g < 0:
			return PackedByteArray()
		genres_evt.append(g)
		var arme_evt := _SANS_ARME
		if v.evenements[i].has("arme"):
			arme_evt = int(v.evenements[i]["arme"])
			if arme_evt < 0 or arme_evt >= catalogue.size() or arme_evt >= _SANS_ARME:
				return PackedByteArray()
		armes_evt.append(arme_evt)

	if not ProtocolePoses.encodables(v, catalogue.size(), nb_unites):
		return PackedByteArray()

	var taille := (
		TAILLE_FIXE
		+ ProtocolePoses.octets(v)
		+ 2 * familles_suivantes.size()
		+ 5 * indices_offres.size()
		+ 3 * indices_armes.size()
		+ 3 * indices_amelios.size()
		+ _OCTETS_ENNEMI * n
		+ _OCTETS_EVENEMENT * nb_evt
	)
	var e := _Ecrivain.new(taille)
	e.u8(Msg.ETAT_ARENE)
	e.u32(v.tick)
	e.u8(v.phase)
	e.u16(v.manche)
	e.u16(_dixiemes(v.temps_restant))
	e.u8((1 if v.sans_fin else 0) | (2 if v.marche_noir_ouvert else 0))
	e.f32(v.tour_pv)
	e.f32(v.tour_pv_max)
	e.f32(v.tour_armure)
	e.i32(v.argent)
	e.i32(v.revenu)
	e.u16(_dixiemes(v.revenu_dans))
	e.u16(v.cout_relance)
	e.u8(v.relances_gratuites)
	e.f32(v.tour_mana)
	e.f32(v.tour_mana_max)
	e.f32(v.tour_epines)
	e.f32(v.tour_esquive)
	e.f32(v.tour_regen)
	e.f32(v.tour_vol_de_vie)
	e.u8(familles_suivantes.size())
	for i in familles_suivantes.size():
		e.u8(familles_suivantes[i])
		e.u8(armures_suivantes[i])
	e.u8(indices_offres.size())
	for i in indices_offres.size():
		e.u8(drapeaux_offres[i])
		e.u16(indices_offres[i])
		e.u16(int(v.offres[i]["prix"]))
	e.u8(indices_armes.size())
	for i in indices_armes.size():
		e.u16(indices_armes[i])
		e.u8(roundi(clampf(float(v.armes[i]["recharge_ratio"]), 0.0, 1.0) * 255.0))
	e.u16(indices_amelios.size())
	for i in indices_amelios.size():
		e.u16(indices_amelios[i])
		e.u8(comptes_amelios[i])
	e.u16(n)
	for i in n:
		e.u16(v.ennemis_id[i] & 0xFFFF)
		e.i16(quantifier(v.ennemis_pos[i].x))
		e.i16(quantifier(v.ennemis_pos[i].y))
		e.u8(v.ennemis_famille[i])
		e.u8(v.ennemis_pv[i])
		e.u8(v.ennemis_statuts[i])
	e.u8(nb_evt)
	for i in nb_evt:
		var evt: Dictionary = v.evenements[i]
		var de: Vector2 = evt["de"]
		var vers: Vector2 = evt["vers"]
		e.u8(genres_evt[i])
		e.u8(clampi(int(evt["type_degats"]), 0, Types.TypeDegats.CHAOS))
		e.i16(quantifier(de.x))
		e.i16(quantifier(de.y))
		e.i16(quantifier(vers.x))
		e.i16(quantifier(vers.y))
		e.u8(roundi(clampf(float(evt["rayon"]), 0.0, 2040.0) / 8.0))
		# Genre (4 bits de poids faible) et statut (4 bits de poids fort) de l'arme ; 0 = aucun.
		var genre_arme := clampi(int(evt.get("genre", 0)), 0, VueArene.GENRES_ARME.size() - 1)
		var statut_arme := clampi(int(evt.get("statut", 0)), 0, VueArene.STATUTS_ARME.size() - 1)
		e.u8(genre_arme | (statut_arme << 4))
		e.u16(armes_evt[i])
	ProtocolePoses.ecrire(e, v)
	e.u16(v.eliminations)
	e.f32(v.degats_infliges)
	e.u16(v.manche_max)
	return e.fin()


## `null` si le paquet est invalide : tronqué, trop grand, octets en trop, type inconnu, compteur
## supérieur aux octets restants ou aux bornes, indice hors du catalogue, phase/armure/genre hors
## bornes, drapeau inconnu, flottant non fini, amélioration en double, plus d'alliés, de zones ou de
## bombes que les plafonds, index d'unité hors de `nb_unites` (si elle est donnée) ou d'arme de zone
## hors du catalogue.
static func decoder_etat_arene(
	b: PackedByteArray, catalogue: PackedStringArray, nb_unites: int = -1
) -> VueArene:
	if b.size() > MAX_TAILLE or b.size() < TAILLE_FIXE:
		return null
	var l := LecteurOctets.new(b)
	if l.u8() != Msg.ETAT_ARENE:
		return null
	var v := VueArene.new()
	v.tick = l.u32()
	v.phase = l.u8()
	v.manche = l.u16()
	v.temps_restant = float(l.u16()) / 10.0
	var flags := l.u8()
	v.sans_fin = flags & 1 != 0
	v.marche_noir_ouvert = flags & 2 != 0
	v.tour_pv = l.f32()
	v.tour_pv_max = l.f32()
	v.tour_armure = l.f32()
	v.argent = l.i32()
	v.revenu = l.i32()
	v.revenu_dans = float(l.u16()) / 10.0
	v.cout_relance = l.u16()
	v.relances_gratuites = l.u8()
	v.tour_mana = l.f32()
	v.tour_mana_max = l.f32()
	v.tour_epines = l.f32()
	v.tour_esquive = l.f32()
	v.tour_regen = l.f32()
	v.tour_vol_de_vie = l.f32()
	var n_familles := l.u8()
	var apparence_negative := (
		v.tour_epines < 0.0 or v.tour_esquive < 0.0 or v.tour_regen < 0.0 or v.tour_vol_de_vie < 0.0
	)
	if not l.ok or flags & ~3 != 0 or v.phase > Types.Phase.DEFAITE or apparence_negative:
		return null
	if n_familles > MAX_FAMILLES_SUIVANTES or not l.exiger(2 * n_familles):
		return null
	for i in n_familles:
		var famille := l.u8()
		var armure := l.u8()
		if famille > MAX_FAMILLE or armure > Types.Armure.BOSS:
			return null
		v.prochaines_familles.append(famille)
		v.prochaines_armures.append(armure)
	if n_familles > 0:
		v.prochaine_famille = v.prochaines_familles[0]
		v.prochaine_armure = v.prochaines_armures[0]

	var nb_catalogue := catalogue.size()
	var n_offres := l.u8()
	if n_offres > MAX_OFFRES or not l.exiger(5 * n_offres):
		return null
	for i in n_offres:
		var d := l.u8()
		var idx := l.u16()
		var prix := l.u16()
		if idx >= nb_catalogue or d & ~0x17 != 0:
			return null
		(
			v
			. offres
			. append(
				{
					"id": catalogue[idx],
					"genre": d & 1,
					"rarete": (d >> 1) & 3,
					"prix": prix,
					"vendu": d & 0x10 != 0,
				}
			)
		)

	var n_armes := l.u8()
	if n_armes > MAX_ARMES or not l.exiger(3 * n_armes):
		return null
	for i in n_armes:
		var idx := l.u16()
		var ratio := l.u8()
		if idx >= nb_catalogue:
			return null
		v.armes.append({"id": catalogue[idx], "recharge_ratio": float(ratio) / 255.0})

	var n_amelios := l.u16()
	if n_amelios > nb_catalogue or not l.exiger(3 * n_amelios):
		return null
	for i in n_amelios:
		var idx := l.u16()
		var compte := l.u8()
		if idx >= nb_catalogue or v.ameliorations.has(catalogue[idx]):
			return null
		v.ameliorations[catalogue[idx]] = compte

	var n_ennemis := l.u16()
	if n_ennemis > MAX_ENNEMIS or not l.exiger(_OCTETS_ENNEMI * n_ennemis):
		return null
	v.ennemis_id.resize(n_ennemis)
	v.ennemis_pos.resize(n_ennemis)
	v.ennemis_famille.resize(n_ennemis)
	v.ennemis_pv.resize(n_ennemis)
	v.ennemis_statuts.resize(n_ennemis)
	var o := l.p
	for i in n_ennemis:
		v.ennemis_id[i] = b.decode_u16(o)
		v.ennemis_pos[i] = Vector2(
			float(b.decode_s16(o + 2)) / ECHELLE_POS, float(b.decode_s16(o + 4)) / ECHELLE_POS
		)
		v.ennemis_famille[i] = b[o + 6]
		v.ennemis_pv[i] = b[o + 7]
		v.ennemis_statuts[i] = b[o + 8]
		o += _OCTETS_ENNEMI
	l.p = o

	var n_evt := l.u8()
	if n_evt > MAX_EVENEMENTS or not l.exiger(_OCTETS_EVENEMENT * n_evt):
		return null
	for i in n_evt:
		var genre := l.u8()
		var type_degats := l.u8()
		var de := Vector2(l.i16(), l.i16()) / ECHELLE_POS
		var vers := Vector2(l.i16(), l.i16()) / ECHELLE_POS
		var rayon := float(l.u8()) * 8.0
		var arme := l.u8()
		var genre_arme := arme & 0x0F
		var statut_arme := arme >> 4
		var index_arme := l.u16()
		if not l.ok or (index_arme != _SANS_ARME and index_arme >= nb_catalogue):
			return null
		if (
			genre >= _GENRES_EVENEMENT.size()
			or type_degats > Types.TypeDegats.CHAOS
			or genre_arme >= VueArene.GENRES_ARME.size()
			or statut_arme >= VueArene.STATUTS_ARME.size()
		):
			return null
		var evenement: Dictionary = {
			"k": _GENRES_EVENEMENT[genre],
			"t": v.tick,
			"de": de,
			"vers": vers,
			"type_degats": type_degats,
			"rayon": rayon,
			"genre": genre_arme,
			"statut": statut_arme,
		}
		if index_arme != _SANS_ARME:
			evenement["arme"] = index_arme
		v.evenements.append(evenement)
	if not ProtocolePoses.lire(l, v, nb_catalogue, nb_unites):
		return null
	v.eliminations = l.u16()
	v.degats_infliges = l.f32()
	v.manche_max = l.u16()
	if not l.ok or l.reste() != 0:
		return null
	return v


## `u8 type · i32 id` puis le corps d'un état d'arène (sans son octet de type) : l'arène d'un
## autre joueur, regardée de son vivant. Vide si l'identifiant n'est pas dans 0 à 255 ou si l'état
## n'est pas représentable (voir `encoder_etat_arene`).
static func encoder_etat_arene_regardee(
	id_joueur: int, v: VueArene, catalogue: PackedStringArray, nb_unites: int = -1
) -> PackedByteArray:
	if id_joueur < 0 or id_joueur > MAX_ID_REGARDE:
		return PackedByteArray()
	var etat := encoder_etat_arene(v, catalogue, nb_unites)
	if etat.is_empty():
		return PackedByteArray()
	var sortie := PackedByteArray([Msg.ETAT_ARENE_REGARDEE])
	sortie.resize(5)
	sortie.encode_s32(1, id_joueur)
	sortie.append_array(etat.slice(1))
	return sortie


## `{id: int, vue: VueArene}`, ou `{}` si le paquet est invalide.
static func decoder_etat_arene_regardee(
	b: PackedByteArray, catalogue: PackedStringArray, nb_unites: int = -1
) -> Dictionary:
	if b.size() > MAX_TAILLE or b.size() < 5 or b[0] != Msg.ETAT_ARENE_REGARDEE:
		return {}
	var id := b.decode_s32(1)
	if id < 0:
		return {}
	var etat := PackedByteArray([Msg.ETAT_ARENE])
	etat.append_array(b.slice(5))
	var vue := decoder_etat_arene(etat, catalogue, nb_unites)
	if vue == null:
		return {}
	return {"id": id, "vue": vue}


static func _id_regarde_valide(arg: int) -> bool:
	return arg == -1 or (arg >= 0 and arg <= MAX_ID_REGARDE)


## Position en 1/16 d'unité, arrondie au plus proche, bornée à l'`i16` ; une valeur non finie
## ne fait pas d'exception (NaN → 0, ±infini → bord).
static func quantifier(x: float) -> int:
	if is_nan(x):
		return 0
	return clampi(roundi(clampf(x, -POS_MAX, POS_MAX) * ECHELLE_POS), -32767, 32767)


# --- Outils privés ---------------------------------------------------------------------------


static func _dixiemes(x: float) -> int:
	if is_nan(x):
		return 0
	return clampi(roundi(clampf(x, 0.0, 6553.5) * 10.0), 0, 65535)


static func _sans_controle(s: String) -> String:
	var sortie := ""
	for i in s.length():
		var c := s.unicode_at(i)
		if c >= 32 and c != 127:
			sortie += char(c)
	return sortie


static func _texte_sain(s: String) -> bool:
	return _sans_controle(s) == s


## Nom d'un joueur prêt à l'envoi : sans caractère de contrôle, au plus 24 caractères.
static func _nom_en_octets(nom: String) -> PackedByteArray:
	return _sans_controle(nom).substr(0, MAX_NOM).to_utf8_buffer()


## Validation UTF-8 stricte faite à la main : le décodeur de Godot journalise une erreur sur une
## entrée invalide, ce que le décodage d'un paquet tiers ne doit jamais faire.
static func _utf8_valide(raw: PackedByteArray) -> bool:
	var i := 0
	var n := raw.size()
	while i < n:
		var c := raw[i]
		if c < 0x80:
			i += 1
			continue
		var extra := 0
		var minimum := 0
		if c >= 0xC2 and c <= 0xDF:
			extra = 1
			minimum = 0x80
		elif c >= 0xE0 and c <= 0xEF:
			extra = 2
			minimum = 0x800
		elif c >= 0xF0 and c <= 0xF4:
			extra = 3
			minimum = 0x10000
		else:
			return false
		if i + extra >= n:
			return false
		var point := c & (0x7F >> (extra + 1))
		for k in extra:
			var suite := raw[i + 1 + k]
			if suite & 0xC0 != 0x80:
				return false
			point = (point << 6) | (suite & 0x3F)
		if point < minimum or point > 0x10FFFF or (point >= 0xD800 and point <= 0xDFFF):
			return false
		i += extra + 1
	return true


## Lecteur à curseur : toute lecture hors des octets disponibles passe `ok` à faux et renvoie 0,
## sans jamais appeler `decode_*` hors bornes.
class LecteurOctets:
	extends RefCounted
	var b: PackedByteArray
	var p: int = 0
	var ok: bool = true

	func _init(octets: PackedByteArray) -> void:
		b = octets

	func reste() -> int:
		return b.size() - p

	func exiger(n: int) -> bool:
		if n < 0 or n > reste():
			ok = false
			return false
		return true

	func u8() -> int:
		if not exiger(1):
			return 0
		p += 1
		return b[p - 1]

	func i8() -> int:
		if not exiger(1):
			return 0
		p += 1
		return b.decode_s8(p - 1)

	func u16() -> int:
		if not exiger(2):
			return 0
		p += 2
		return b.decode_u16(p - 2)

	func i16() -> int:
		if not exiger(2):
			return 0
		p += 2
		return b.decode_s16(p - 2)

	func u32() -> int:
		if not exiger(4):
			return 0
		p += 4
		return b.decode_u32(p - 4)

	func i32() -> int:
		if not exiger(4):
			return 0
		p += 4
		return b.decode_s32(p - 4)

	func i64() -> int:
		if not exiger(8):
			return 0
		p += 8
		return b.decode_s64(p - 8)

	## Flottant 32 bits ; NaN et infinis sont refusés.
	func f32() -> float:
		if not exiger(4):
			return 0.0
		p += 4
		var x := b.decode_float(p - 4)
		if is_nan(x) or is_inf(x):
			ok = false
			return 0.0
		return x

	## `n` octets UTF-8 valides, sans caractère de contrôle, d'au plus `max_caracteres`.
	func texte(n: int, max_caracteres: int) -> String:
		if not exiger(n):
			return ""
		var brut := b.slice(p, p + n)
		p += n
		# Un octet de contrôle (dont NUL, que le décodeur de Godot prendrait pour une fin).
		for c in brut:
			if c < 32 or c == 127:
				ok = false
				return ""
		if not Protocole._utf8_valide(brut):
			ok = false
			return ""
		var s := brut.get_string_from_utf8()
		if s.length() > max_caracteres or not Protocole._texte_sain(s):
			ok = false
			return ""
		return s


## Écrivain à curseur sur un tampon dimensionné une fois ; les valeurs sont bornées au type.
class _Ecrivain:
	extends RefCounted
	var b: PackedByteArray = PackedByteArray()
	var p: int = 0

	func _init(capacite: int) -> void:
		b.resize(capacite)

	func u8(v: int) -> void:
		b.encode_u8(p, clampi(v, 0, 255))
		p += 1

	func i8(v: int) -> void:
		b.encode_s8(p, clampi(v, -128, 127))
		p += 1

	func u16(v: int) -> void:
		b.encode_u16(p, clampi(v, 0, 65535))
		p += 2

	func i16(v: int) -> void:
		b.encode_s16(p, clampi(v, -32768, 32767))
		p += 2

	func u32(v: int) -> void:
		b.encode_u32(p, v & 0xFFFFFFFF)
		p += 4

	func i32(v: int) -> void:
		b.encode_s32(p, clampi(v, -2147483648, 2147483647))
		p += 4

	func i64(v: int) -> void:
		b.encode_s64(p, v)
		p += 8

	func f32(v: float) -> void:
		b.encode_float(p, v)
		p += 4

	func octets(brut: PackedByteArray) -> void:
		for i in brut.size():
			b[p + i] = brut[i]
		p += brut.size()

	func fin() -> PackedByteArray:
		b.resize(p)
		return b
