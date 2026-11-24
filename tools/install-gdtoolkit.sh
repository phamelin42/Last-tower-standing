#!/usr/bin/env bash
# Installe gdtoolkit 4 (gdlint, gdformat) dans un venv dédié, sans toucher au Python du système.
#
# Idempotent : si gdlint et gdformat répondent tous deux en 4.x, rien n'est fait. Sinon le venv
# /opt/gdtoolkit est créé (ou complété) avec gdtoolkit==4.*, et les commandes sont liées dans
# /usr/local/bin. Les distributions récentes refusent `pip install` hors venv (PEP 668) : d'où le venv.
#
# Usage : install-gdtoolkit.sh
#   Variables facultatives : GDTOOLKIT_VENV (défaut /opt/gdtoolkit),
#   GDTOOLKIT_BIN_DIR (défaut /usr/local/bin).

set -euo pipefail

VENV="${GDTOOLKIT_VENV:-/opt/gdtoolkit}"
BIN_DIR="${GDTOOLKIT_BIN_DIR:-/usr/local/bin}"
PAQUET="gdtoolkit==4.*"

log() {
	printf '[install-gdtoolkit] %s\n' "$*"
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

# Une seule version majeure pour les deux outils : gdlint et gdformat doivent parler la même 4.x.
version_4_ok() {
	local commande="$1" sortie
	command -v "$commande" >/dev/null 2>&1 || return 1
	sortie="$("$commande" --version 2>/dev/null | head -n 1 || true)"
	[[ "$sortie" =~ ^${commande}\ 4\. ]]
}

if version_4_ok gdlint && version_4_ok gdformat; then
	log "gdtoolkit 4.x déjà présent ($(gdlint --version | head -n 1)), rien à installer"
	exit 0
fi

command -v python3 >/dev/null 2>&1 || { log "erreur : python3 est requis"; exit 1; }

if [[ ! -x "${VENV}/bin/python" ]]; then
	as_root python3 -m venv "$VENV" || {
		log "erreur : création du venv impossible (sur Debian/Ubuntu : paquet python3-venv)"
		exit 1
	}
	log "venv créé : ${VENV}"
fi

as_root "${VENV}/bin/pip" install --quiet --upgrade "$PAQUET"
log "installé : $("${VENV}/bin/gdlint" --version | head -n 1)"

for outil in gdlint gdformat; do
	lien="${BIN_DIR}/${outil}"
	if [[ "$(readlink "$lien" 2>/dev/null || true)" != "${VENV}/bin/${outil}" ]]; then
		as_root ln -sfn "${VENV}/bin/${outil}" "$lien"
		log "lien : ${lien} -> ${VENV}/bin/${outil}"
	fi
done

version_4_ok gdlint && version_4_ok gdformat || { log "erreur : gdlint ou gdformat hors 4.x après installation"; exit 1; }
