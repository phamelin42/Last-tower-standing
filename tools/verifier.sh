#!/usr/bin/env bash
# Rejoue localement exactement ce que fait la CI, étape par étape.
#
# Usage :
#   tools/verifier.sh                    toutes les étapes, dans l'ordre, arrêt à la première rouge
#   tools/verifier.sh --etape <nom>      une seule étape
#
# Étapes : import, uid, lint, format, tests, controle, integration.
# Code de sortie : 0 si tout passe, sinon celui de l'étape fautive (2 si l'étape est inconnue).
# Les noms d'étapes sont repris tels quels par .github/workflows/ci.yml : les renommer des deux côtés.

set -euo pipefail

cd "$(dirname "$0")/.."

ETAPES="import uid lint format tests controle integration"

# Lance le lanceur de tests maison. Forme : T --filtre test_<fichier> pour un test ciblé.
lanceur() {
	godot --headless --path . --script res://tests/lanceur.gd -- "$@"
}

# Chaque script GDScript suivi par git doit avoir son `.gd.uid` suivi, et réciproquement : un
# `.uid` absent de l'index est recréé par Godot dans une autre copie, et la fusion échoue.
# `.claude/` est ignoré (worktrees des agents).
verifier_uid() {
	local manquants orphelins gd_attendus uid_suivis doublons
	lister_suivis() {
		git ls-files -- "$1" | { grep -v '^\.claude/' || true; } | LC_ALL=C sort
	}
	gd_attendus=$(lister_suivis '*.gd' | sed 's/$/.uid/')
	uid_suivis=$(lister_suivis '*.gd.uid')
	manquants=$(LC_ALL=C comm -23 <(printf '%s\n' "$gd_attendus" | sed '/^$/d') <(printf '%s\n' "$uid_suivis" | sed '/^$/d'))
	orphelins=$(LC_ALL=C comm -13 <(printf '%s\n' "$gd_attendus" | sed '/^$/d') <(printf '%s\n' "$uid_suivis" | sed '/^$/d'))
	# Deux fichiers qui portent le même uid font signaler « UID duplicate » à l'import, et Godot
	# en réattribue un au hasard : on refuse le doublon dès qu'il est suivi par git.
	doublons=$(
		{
			git ls-files -z -- '*.import' | xargs -0 grep -h '^uid=' | sed 's/^uid=//; s/"//g'
			git ls-files -z -- '*.gd.uid' | { grep -zv '^\.claude/' || true; } | xargs -0 cat
		} | sed '/^$/d' | LC_ALL=C sort | uniq -d
	)
	if [[ -n "$doublons" ]]; then
		echo "étape uid : uid en double dans les fichiers suivis :" >&2
		sed 's/^/  /' <<<"$doublons" >&2
		return 1
	fi
	if [[ -z "$manquants" && -z "$orphelins" ]]; then
		echo "étape uid : chaque .gd suivi a son .uid suivi, aucun uid en double"
		return 0
	fi
	if [[ -n "$manquants" ]]; then
		echo "étape uid : .uid suivi absent pour :" >&2
		sed 's/\.uid$//; s/^/  /' <<<"$manquants" >&2
	fi
	if [[ -n "$orphelins" ]]; then
		echo "étape uid : .uid suivi sans .gd suivi :" >&2
		sed 's/^/  /' <<<"$orphelins" >&2
	fi
	return 1
}

executer_etape() {
	case "$1" in
	import)
		godot --headless --path . --import
		;;
	uid)
		verifier_uid
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
