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
			# L'uid qu'une scène ou une ressource texte déclare dans son en-tête (pas ceux qu'elle cite).
			git ls-files -z -- '*.tscn' '*.tres' | { grep -zv '^\.claude/' || true; } | xargs -0 -r grep -h '^\[gd_\(scene\|resource\)' | { grep -o 'uid="uid://[a-z0-9]*"' || true; } | sed 's/^uid=//; s/"//g'
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

# L'import ne doit signaler aucun « UID duplicate » : deux ressources qui se disputent un uid font
# réattribuer l'un au hasard. Un cache d'éditeur périmé (`.godot/editor`, resté d'une branche
# antérieure) en signale à tort sur une copie saine : on le supprime et on réimporte une fois ; si
# l'avertissement revient, le doublon est réel et l'étape échoue.
importer() {
	local journal code
	journal=$(mktemp)
	godot --headless --path . --import 2>&1 | tee "$journal"
	code="${PIPESTATUS[0]}"
	if [[ "$code" -eq 0 ]] && grep -q 'UID duplicate' "$journal"; then
		echo "étape import : « UID duplicate » signalé, cache de l'éditeur supprimé puis import refait" >&2
		rm -rf .godot/editor
		godot --headless --path . --import 2>&1 | tee "$journal"
		code="${PIPESTATUS[0]}"
		if [[ "$code" -eq 0 ]] && grep -q 'UID duplicate' "$journal"; then
			echo "étape import : « UID duplicate » persiste : deux ressources portent le même uid" >&2
			grep 'UID duplicate' "$journal" >&2
			code=1
		fi
	fi
	rm -f "$journal"
	return "$code"
}

executer_etape() {
	case "$1" in
	import)
		importer
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
