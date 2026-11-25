#!/usr/bin/env bash
# Prépare une session cloud : Godot, gdtoolkit, puis import du projet.
#
# Idempotent : les installeurs ne téléchargent rien si la version attendue est déjà là.
# Hors ligne ou sans droits, chaque étape signale son échec et la session continue : ce hook
# ne bloque jamais le démarrage, même en cas d'échec.

cd "$(dirname "$0")/../.." || exit 0

journal() {
	printf '[session-start] %s\n' "$*" >&2
}

etape() {
	local nom="$1"
	shift
	if "$@"; then
		return 0
	fi
	journal "avertissement : étape ${nom} en échec (hors ligne ? droits ?), la session continue"
	return 1
}

etape godot tools/install-godot.sh
etape gdtoolkit tools/install-gdtoolkit.sh

if command -v godot >/dev/null 2>&1 && [[ -f project.godot ]]; then
	etape import godot --headless --path . --import
else
	journal "import ignoré : godot ou project.godot absent"
fi

exit 0
