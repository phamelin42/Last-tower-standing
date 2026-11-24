#!/usr/bin/env bash
# Rejoue localement exactement ce que fait la CI, étape par étape.
#
# Usage :
#   tools/verifier.sh                    toutes les étapes, dans l'ordre, arrêt à la première rouge
#   tools/verifier.sh --etape <nom>      une seule étape
#
# Étapes : import, lint, format, tests, controle, integration.
# Code de sortie : 0 si tout passe, sinon celui de l'étape fautive (2 si l'étape est inconnue).
# Les noms d'étapes sont repris tels quels par .github/workflows/ci.yml : les renommer des deux côtés.

set -euo pipefail

cd "$(dirname "$0")/.."

ETAPES="import lint format tests controle integration"

# Lance le lanceur de tests maison. Forme : T --filtre test_<fichier> pour un test ciblé.
lanceur() {
	godot --headless --path . --script res://tests/lanceur.gd -- "$@"
}

executer_etape() {
	case "$1" in
	import)
		godot --headless --path . --import
		;;
	lint)
		gdlint .
		;;
	format)
		local dossiers=() dossier
		for dossier in sim app visuels ui reseau tests tools; do
			[[ -d "$dossier" ]] && dossiers+=("$dossier")
		done
		if [[ "${#dossiers[@]}" -eq 0 ]]; then
			echo "étape format : aucun dossier GDScript, ignorée"
			return 0
		fi
		gdformat --check "${dossiers[@]}"
		;;
	tests)
		lanceur
		;;
	controle)
		lanceur --controle
		;;
	integration)
		if [[ -f tools/integration.sh ]]; then
			bash tools/integration.sh
		else
			echo "étape absente, ignorée : tools/integration.sh n'existe pas"
		fi
		;;
	esac
}

if [[ "${1:-}" == "--etape" ]]; then
	etape="${2:-}"
	if [[ " $ETAPES " != *" $etape "* ]] || [[ -z "$etape" ]]; then
		echo "tools/verifier.sh : étape inconnue '${etape}' (attendu : ${ETAPES})" >&2
		exit 2
	fi
	echo "== étape ${etape} =="
	executer_etape "$etape" || {
		code="$?"
		echo "tools/verifier.sh : étape ${etape} rouge (code ${code})" >&2
		exit "$code"
	}
	exit 0
fi

if [[ "$#" -gt 0 ]]; then
	echo "tools/verifier.sh : argument inconnu '$1' (usage : tools/verifier.sh [--etape <nom>])" >&2
	exit 2
fi

for etape in $ETAPES; do
	echo "== étape ${etape} =="
	executer_etape "$etape" || {
		code="$?"
		echo "tools/verifier.sh : étape ${etape} rouge (code ${code}), arrêt" >&2
		exit "$code"
	}
done

echo "tools/verifier.sh : toutes les étapes sont vertes"
