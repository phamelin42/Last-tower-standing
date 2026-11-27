class_name Salon
extends RefCounted
## Salon d'avant-partie : machine à états pure (salon ouvert, puis partie lancée), sans réseau.
## Tout ce qui l'alimente vient d'un pair non fiable : chaque opération renvoie un booléen et
## laisse dans `motif_refus` la raison du dernier refus, jamais une exception.

const MAX_JOUEURS: int = 8
const MAX_NOM: int = Protocole.MAX_NOM
const VITESSES: Array[float] = [1.0, 0.5, 0.25]
const _TOLERANCE_VITESSE: float = 0.001
const _OCTETS_JOUEUR_MIN: int = 6

## id → {nom: String, pret: bool}, dans l'ordre d'arrivée.
var joueurs: Dictionary = {}
var vitesse: float = 1.0
var graine: int = 0
var graine_fixe: bool = false
## Joueur le plus ancien du salon, -1 s'il est vide : il règle les options et lance la partie.
var hote: int = -1
var lancee: bool = false
## Jeton d'hôte du salon hébergé par un joueur (8 octets), vide pour le serveur dédié. Quand il est
## posé, seul le pair qui le présente devient hôte et personne ne reprend le rôle à son départ.
## Il ne sort jamais du salon : ni sérialisé, ni journalisé.
var jeton_hote: PackedByteArray = PackedByteArray()
var motif_refus: String = ""


## `jeton` : celui du bonjour. Sans `jeton_hote`, le premier pair devient hôte ; avec, seul le
## premier pair qui présente le bon jeton le devient (un autre porteur du même jeton reste joueur).
func ajouter(id: int, nom: String, jeton: PackedByteArray = PackedByteArray()) -> bool:
	var motif := _motif_admission(id, nom)
	if not motif.is_empty():
		return _refuser(motif)
	var propre := nom.strip_edges()
	if propre.is_empty():
		propre = _nom_par_defaut()
	joueurs[id] = {"nom": _nom_unique(propre), "pret": false}
	if hote == -1 and _donne_le_role(jeton):
		hote = id
	return true


func retirer(id: int) -> bool:
	if lancee:
		return _refuser("La partie a déjà commencé.")
	if not joueurs.has(id):
		return _refuser("Ce joueur n'est pas dans le salon.")
	joueurs.erase(id)
	if id == hote:
		hote = -1
		# Le salon hébergé n'a pas de repli : l'hôte parti ferme le serveur, et le rôle reste
		# réservé au porteur du jeton, y compris s'il revient.
		if jeton_hote.is_empty():
			for suivant: int in joueurs:
				hote = suivant
				break
	return true


func marquer_pret(id: int, pret: bool) -> bool:
	if lancee:
		return _refuser("La partie a déjà commencé.")
	if not joueurs.has(id):
		return _refuser("Ce joueur n'est pas dans le salon.")
	joueurs[id]["pret"] = pret
	return true


## Le skin de tour de `id` (index déjà borné au catalogue par l'appelant) ; refusé une fois la
## partie lancée. Il n'est pas diffusé avec le salon : il rejoint la partie au lancement.
func definir_skin(id: int, index: int) -> bool:
	if lancee:
		return _refuser("La partie a déjà commencé.")
	if not joueurs.has(id):
		return _refuser("Ce joueur n'est pas dans le salon.")
	joueurs[id]["skin"] = index
	return true


## `id_hote` est l'émetteur de la demande, `id` le joueur dont on règle la partie : seul l'hôte
## actuel passe, et il ne peut agir qu'en son nom.
func regler(id_hote: int, id: int, v: float, g: int, fixe: bool) -> bool:
	if lancee:
		return _refuser("La partie a déjà commencé.")
	if id_hote != hote or id != hote or not joueurs.has(id_hote):
		return _refuser("Seul l'hôte règle les options.")
	var canonique := _vitesse_canonique(v)
	if canonique < 0.0:
		return _refuser("Vitesse de partie inconnue.")
	if g < 0:
		return _refuser("Graine invalide.")
	vitesse = canonique
	graine_fixe = fixe
	graine = g if fixe else 0
	return true


func peut_demarrer() -> bool:
	if joueurs.is_empty():
		return false
	for id: int in joueurs:
		if not joueurs[id]["pret"]:
			return false
	return true


func demarrer(id_hote: int) -> bool:
	if lancee:
		return _refuser("La partie a déjà commencé.")
	if id_hote != hote or not joueurs.has(id_hote):
		return _refuser("Seul l'hôte lance la partie.")
	if not peut_demarrer():
		return _refuser("Tous les joueurs ne sont pas prêts.")
	lancee = true
	return true


## La graine à donner à la partie : la graine fixe, sinon un tirage neuf.
func graine_de_partie() -> int:
	if graine_fixe:
		return graine
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return rng.randi()


# --- Sérialisation ---------------------------------------------------------------------------


## `u8 SALON · f32 vitesse · i64 graine · u8 flags (1 fixe, 2 lancée) · i32 hôte · u8 n`
## puis par joueur `[i32 id · u8 prêt · u8 n + nom UTF-8]`.
func vers_octets() -> PackedByteArray:
	var e := StreamPeerBuffer.new()
	e.put_u8(Protocole.Msg.SALON)
	e.put_float(vitesse)
	e.put_64(graine)
	e.put_u8((1 if graine_fixe else 0) | (2 if lancee else 0))
	e.put_32(hote)
	e.put_u8(joueurs.size())
	for id: int in joueurs:
		var nom := (joueurs[id]["nom"] as String).to_utf8_buffer()
		e.put_32(id)
		e.put_u8(1 if joueurs[id]["pret"] else 0)
		e.put_u8(nom.size())
		e.put_data(nom)
	return e.data_array


## `null` pour tout paquet invalide : tronqué, trop long, incohérent, noms illégaux.
static func depuis_octets(b: PackedByteArray) -> Salon:
	if b.size() > Protocole.MAX_TAILLE:
		return null
	var l := LecteurOctets.new(b)
	if l.u8() != Protocole.Msg.SALON:
		return null
	var s := Salon.new()
	var v := _vitesse_canonique(l.f32())
	s.graine = l.i64()
	var drapeaux := l.u8()
	s.hote = l.i32()
	var n := l.u8()
	if not l.ok or v < 0.0 or s.graine < 0 or drapeaux > 3 or n > MAX_JOUEURS:
		return null
	if n * _OCTETS_JOUEUR_MIN > l.reste():
		return null
	s.vitesse = v
	s.graine_fixe = drapeaux & 1 != 0
	s.lancee = drapeaux & 2 != 0
	if not s.graine_fixe and s.graine != 0:
		return null
	for i: int in n:
		var id := l.i32()
		var pret := l.u8()
		var nom := l.texte(l.u8(), MAX_NOM)
		if not l.ok or id <= 0 or pret > 1 or s.joueurs.has(id) or nom.strip_edges() != nom:
			return null
		if nom.is_empty():
			return null
		s.joueurs[id] = {"nom": nom, "pret": pret == 1}
	if l.reste() != 0 or not l.ok:
		return null
	if s.joueurs.is_empty():
		return s if s.hote == -1 and not s.lancee else null
	return s if s.joueurs.has(s.hote) else null


# --- Internes --------------------------------------------------------------------------------


func _donne_le_role(jeton: PackedByteArray) -> bool:
	return jeton_hote.is_empty() or jeton == jeton_hote


func _motif_admission(id: int, nom: String) -> String:
	if lancee:
		return "La partie a déjà commencé."
	if id <= 0:
		return "Identifiant de joueur invalide."
	if joueurs.has(id):
		return "Ce joueur est déjà dans le salon."
	if joueurs.size() >= MAX_JOUEURS:
		return "Le salon est plein (%d joueurs)." % MAX_JOUEURS
	return _motif_nom(nom)


func _motif_nom(nom: String) -> String:
	if nom.strip_edges().length() > MAX_NOM:
		return "Nom trop long (%d caractères au plus)." % MAX_NOM
	if not _sans_controle(nom):
		return "Le nom contient un caractère interdit."
	return ""


func _refuser(motif: String) -> bool:
	motif_refus = motif
	return false


static func _vitesse_canonique(v: float) -> float:
	if is_nan(v) or is_inf(v):
		return -1.0
	for connue: float in VITESSES:
		if absf(v - connue) < _TOLERANCE_VITESSE:
			return connue
	return -1.0


static func _sans_controle(s: String) -> bool:
	for i: int in s.length():
		var c := s.unicode_at(i)
		if c < 32 or c == 127 or (c >= 128 and c < 160):
			return false
	return true


func _nom_pris(nom: String) -> bool:
	var minuscule := nom.to_lower()
	for id: int in joueurs:
		if (joueurs[id]["nom"] as String).to_lower() == minuscule:
			return true
	return false


func _nom_par_defaut() -> String:
	var n := 1
	while _nom_pris("Joueur %d" % n):
		n += 1
	return "Joueur %d" % n


## Suffixe « (2) », « (3) »… en rognant le nom pour rester sous la limite.
func _nom_unique(nom: String) -> String:
	if not _nom_pris(nom):
		return nom
	var k := 2
	while true:
		var suffixe := " (%d)" % k
		var candidat := nom.substr(0, MAX_NOM - suffixe.length()) + suffixe
		if not _nom_pris(candidat):
			return candidat
		k += 1
	return nom
