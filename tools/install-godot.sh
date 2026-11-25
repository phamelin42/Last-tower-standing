#!/usr/bin/env bash
# Installe Godot (binaire Linux x86_64 officiel) sans interface graphique.
#
# Idempotent : si /opt/godot/<version>/godot répond à --version avec la bonne
# version, rien n'est téléchargé. Sinon l'archive est téléchargée dans un
# dossier neuf, sa somme SHA512 est vérifiée quand la liste officielle est
# joignable, puis le binaire est installé dans /opt/godot/<version>.
#
# Usage : install-godot.sh [--dry-run]
#   Variables facultatives : GODOT_INSTALL_ROOT (défaut /opt/godot),
#   GODOT_BIN_LINK (défaut /usr/local/bin/godot).

set -euo pipefail

GODOT_VERSION="4.7.2"
GODOT_FLAVOR="stable"

INSTALL_ROOT="${GODOT_INSTALL_ROOT:-/opt/godot}"
BIN_LINK="${GODOT_BIN_LINK:-/usr/local/bin/godot}"

# Release officielle godot-builds sur GitHub d'abord : downloads.godotengine.org répond 403 aux
# runners GitHub Actions. Ce domaine reste en secours pour un réseau où GitHub serait bloqué.
ARCHIVE="Godot_v${GODOT_VERSION}-${GODOT_FLAVOR}_linux.x86_64.zip"
RELEASE_URL="https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}-${GODOT_FLAVOR}"
ARCHIVE_URLS=(
	"${RELEASE_URL}/${ARCHIVE}"
	"https://downloads.godotengine.org/?version=${GODOT_VERSION}&flavor=${GODOT_FLAVOR}&slug=linux.x86_64.zip&platform=linux.64"
)
SUMS_URL="${RELEASE_URL}/SHA512-SUMS.txt"

DEST_DIR="${INSTALL_ROOT}/${GODOT_VERSION}"
DEST_BIN="${DEST_DIR}/godot"
EXPECTED_VERSION_PREFIX="${GODOT_VERSION}.${GODOT_FLAVOR}."

DRY_RUN=0
if [[ "${1:-}" == "--dry-run" ]]; then
	DRY_RUN=1
fi

log() {
	printf '[install-godot] %s\n' "$*"
}

# Privilégie root ; sinon sudo si disponible (poste ou CI non root).
as_root() {
	if [[ "$(id -u)" -eq 0 ]]; then
		"$@"
	elif command -v sudo >/dev/null 2>&1; then
		sudo "$@"
	else
		log "erreur : droits root requis pour : $*"
		exit 1
	fi
}

installed_version_ok() {
	[[ -x "$DEST_BIN" ]] || return 1
	local out
	out="$("$DEST_BIN" --headless --version 2>/dev/null | head -n 1 || true)"
	[[ "$out" == "${EXPECTED_VERSION_PREFIX}"* ]]
}

ensure_link() {
	local current
	current="$(readlink "$BIN_LINK" 2>/dev/null || true)"
	if [[ "$current" != "$DEST_BIN" ]]; then
		as_root ln -sfn "$DEST_BIN" "$BIN_LINK"
		log "lien : ${BIN_LINK} -> ${DEST_BIN}"
	fi
}

if installed_version_ok; then
	log "Godot ${GODOT_VERSION} déjà installé dans ${DEST_DIR}, rien à télécharger"
	ensure_link
	exit 0
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
	log "dry-run : téléchargerait ${ARCHIVE} et l'installerait dans ${DEST_DIR}"
	exit 0
fi

command -v curl >/dev/null 2>&1 || { log "erreur : curl est requis"; exit 1; }
command -v unzip >/dev/null 2>&1 || { log "erreur : unzip est requis"; exit 1; }

# Dossier de travail neuf et vide, supprimé en sortie (données non fiables).
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

telecharge=0
for url in "${ARCHIVE_URLS[@]}"; do
	log "téléchargement de ${ARCHIVE} depuis ${url%%\?*}"
	if curl -fsSL --retry 3 --max-time 900 -o "${WORK}/godot.zip" "$url"; then
		telecharge=1
		break
	fi
	log "échec depuis cette source, essai suivant"
done
if [[ "$telecharge" -ne 1 ]]; then
	log "erreur : aucune source n'a servi ${ARCHIVE}"
	exit 1
fi

if curl -fsSL --retry 2 --max-time 120 -o "${WORK}/SHA512-SUMS.txt" "$SUMS_URL" 2>/dev/null; then
	line="$(grep -F "  ${ARCHIVE}" "${WORK}/SHA512-SUMS.txt" || true)"
	if [[ -z "$line" ]]; then
		log "erreur : ${ARCHIVE} absent de la liste de sommes"
		exit 1
	fi
	printf '%s\n' "$line" > "${WORK}/expected.sha512"
	(cd "$WORK" && mv godot.zip "$ARCHIVE" && sha512sum -c expected.sha512 >/dev/null)
	log "somme SHA512 vérifiée"
else
	log "avertissement : liste de sommes injoignable, archive non vérifiée"
	mv "${WORK}/godot.zip" "${WORK}/${ARCHIVE}"
fi

mkdir -p "${WORK}/extract"
unzip -q "${WORK}/${ARCHIVE}" -d "${WORK}/extract"

BIN_IN_ARCHIVE="${WORK}/extract/Godot_v${GODOT_VERSION}-${GODOT_FLAVOR}_linux.x86_64"
[[ -f "$BIN_IN_ARCHIVE" ]] || { log "erreur : binaire absent de l'archive"; exit 1; }

as_root mkdir -p "$DEST_DIR"
as_root install -m 0755 "$BIN_IN_ARCHIVE" "$DEST_BIN"

installed_version_ok || { log "erreur : la version installée ne correspond pas"; exit 1; }
ensure_link
log "installé : $("$DEST_BIN" --headless --version | head -n 1)"
