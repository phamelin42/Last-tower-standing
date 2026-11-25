#!/usr/bin/env bash
# Rejoue en l'amplifiant le plantage de l'import à froid de Godot 4.7.2 (godot#125712) : les CSV
# de traduction importés en parallèle corrompent le tas (« double free or corruption », code 134).
#
# Copie les fichiers suivis dans un dossier neuf, ajoute des copies de `i18n/textes_communs.csv`
# (plus il y a de CSV, plus la course est fréquente), puis lance des imports à froid, `HOME` vierge.
# À relancer avec --threads après une montée de version de Godot : 0 plantage avec --threads
# veut dire que le moteur est corrigé et que `editor/import/use_multiple_threads` peut revenir.
#
# Usage : tools/stress-import-csv.sh [--threads] [--essais N] [--copies K] [--parallele P]
#   --threads   force editor/import/use_multiple_threads=true (sinon : réglage de project.godot)
#   défauts     --essais 16 --copies 392 --parallele 4 (4 cœurs : 10 à 30 % de plantages avec --threads)
# Code de sortie : 0 si aucun import n'a planté, 1 sinon, 2 si l'usage est faux.

set -euo pipefail

cd "$(dirname "$0")/.."

threads=0
essais=16
copies=392
parallele=4
while [[ "$#" -gt 0 ]]; do
	case "$1" in
	--threads) threads=1 ;;
	--essais) essais="$2" && shift ;;
	--copies) copies="$2" && shift ;;
	--parallele) parallele="$2" && shift ;;
	*)
		echo "tools/stress-import-csv.sh : argument inconnu '$1'" >&2
		exit 2
		;;
	esac
	shift
done

travail="$(mktemp -d)"
trap 'rm -rf "$travail"' EXIT

modele="${travail}/modele"
mkdir -p "$modele"
git ls-files -z | grep -zv '^\.claude/' | xargs -0 cp --parents -t "$modele"
for k in $(seq 1 "$copies"); do
	cp i18n/textes_communs.csv "${modele}/i18n/stress_$(printf '%03d' "$k").csv"
done
if [[ "$threads" -eq 1 ]]; then
	sed -i 's|^import/use_multiple_threads=false$|import/use_multiple_threads=true|' "${modele}/project.godot"
fi

# Un import à froid : copie neuve, sans `.godot/`, `HOME` vierge (réglages d'éditeur recréés).
un_import() {
	local dossier
	dossier="$(mktemp -d "${travail}/essai.XXXX")"
	cp -r "${modele}/." "${dossier}/projet"
	mkdir -p "${dossier}/home"
	local code=0
	HOME="${dossier}/home" godot --headless --path "${dossier}/projet" --import \
		>"${dossier}/journal.txt" 2>&1 || code="$?"
	if [[ "$code" -ne 0 ]]; then
		echo "essai $1 : code ${code}, $(grep -m1 -E 'double free|corrupt|invalid|crashed' "${dossier}/journal.txt" || echo 'sans message')"
	fi
	rm -rf "$dossier"
	echo "$code" >>"${travail}/codes.txt"
}
export -f un_import
export travail modele

seq 1 "$essais" | xargs -P "$parallele" -I{} bash -c 'un_import {}'

plantages="$(grep -cv '^0$' "${travail}/codes.txt" || true)"
nb_csv="$(find "${modele}/i18n" -name '*.csv' | wc -l)"
echo "stress-import-csv : ${essais} imports à froid, ${nb_csv} CSV, threads=${threads} : ${plantages} plantage(s)"
[[ "$plantages" -eq 0 ]]
