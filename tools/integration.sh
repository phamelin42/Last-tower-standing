#!/usr/bin/env bash
# Intégration de bout en bout : un vrai serveur dédié et deux robots (processus séparés) jouent une
# partie accélérée jusqu'au bout.
#
# Usage : tools/integration.sh            (variable : DELAI_GLOBAL en secondes, 120 par défaut)
#
# Code de sortie : 0 si et seulement si les trois processus sortent à 0, sans `SCRIPT ERROR` ni
# `ERROR:` dans leurs journaux ; 1 sinon (les journaux sont alors affichés).

set -uo pipefail

cd "$(dirname "$0")/.."

DELAI_GLOBAL="${DELAI_GLOBAL:-120}"
GRAINE=7
ACCELERATION=20
STRATEGIE_1="${STRATEGIE_1:-raisonnable}"
STRATEGIE_2="${STRATEGIE_2:-raisonnable}"

dossier=$(mktemp -d)
pids=()
debut=$SECONDS

# Pas de `pkill -f` : on ne tue que les PID lancés ici.
nettoyer() {
	local pid
	for pid in "${pids[@]}"; do
		kill -0 "$pid" 2>/dev/null && kill "$pid" 2>/dev/null
	done
	sleep 0.3
	for pid in "${pids[@]}"; do
		kill -0 "$pid" 2>/dev/null && kill -9 "$pid" 2>/dev/null
	done
	rm -rf "$dossier"
}
trap nettoyer EXIT

# Un port UDP libre, tiré par le système (ENet est en UDP).
port=$(python3 -c 'import socket; s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')

attendre_motif() {
	local fichier="$1" motif="$2" limite=$((SECONDS + 30))
	while ((SECONDS < limite)); do
		grep -q "$motif" "$fichier" 2>/dev/null && return 0
		sleep 0.2
	done
	return 1
}

lancer_robot() {
	local nom="$1" strategie="$2"
	godot --headless --path . --script res://tests/integration/robot.gd -- \
		--adresse 127.0.0.1 --port "$port" --nom "$nom" --strategie "$strategie" \
		--delai "$((DELAI_GLOBAL - 10))" >"$dossier/$nom.log" 2>&1 &
	pids+=("$!")
}

echo "intégration : port ${port}, graine ${GRAINE}, serveur ×${ACCELERATION}, partie ×4"

godot --headless --path . -- --serveur --port "$port" --graine "$GRAINE" \
	--acceleration "$ACCELERATION" --quitter-a-la-fin >"$dossier/serveur.log" 2>&1 &
pids+=("$!")

if ! attendre_motif "$dossier/serveur.log" "Serveur ouvert"; then
	echo "intégration : le serveur ne s'est pas ouvert" >&2
	cat "$dossier/serveur.log" >&2
	exit 1
fi

# Le premier connecté est l'hôte : le second attend que le salon l'ait vu.
lancer_robot Robot1 "$STRATEGIE_1"
attendre_motif "$dossier/serveur.log" "Salon : 1 joueur" || true
lancer_robot Robot2 "$STRATEGIE_2"

limite=$((debut + DELAI_GLOBAL))
while ((SECONDS < limite)); do
	vivants=0
	for pid in "${pids[@]}"; do
		kill -0 "$pid" 2>/dev/null && vivants=$((vivants + 1))
	done
	((vivants == 0)) && break
	sleep 0.5
done

echec=0
noms=(serveur Robot1 Robot2)
for i in 0 1 2; do
	pid="${pids[$i]}"
	if kill -0 "$pid" 2>/dev/null; then
		echo "intégration : ${noms[$i]} encore actif après ${DELAI_GLOBAL} s" >&2
		kill "$pid" 2>/dev/null
		echec=1
		continue
	fi
	wait "$pid"
	code=$?
	if ((code != 0)); then
		echo "intégration : ${noms[$i]} est sorti avec le code ${code}" >&2
		echec=1
	fi
done

for nom in "${noms[@]}"; do
	if grep -nE 'SCRIPT ERROR|^ERROR:|^WARNING:.*leaked' "$dossier/$nom.log" >"$dossier/$nom.erreurs"; then
		echo "intégration : erreurs dans le journal de ${nom} :" >&2
		cat "$dossier/$nom.erreurs" >&2
		echec=1
	fi
done
grep -q "Fin de partie" "$dossier/serveur.log" || {
	echo "intégration : le journal du serveur ne contient pas « Fin de partie »" >&2
	echec=1
}

echo "--- résumé ---"
for nom in Robot1 Robot2; do
	grep -h "^ROBOT " "$dossier/$nom.log" || echo "(${nom} : pas de ligne finale)"
done
echo "durée totale : $((SECONDS - debut)) s"

if ((echec != 0)); then
	for nom in "${noms[@]}"; do
		echo "=== journal ${nom} ===" >&2
		tail -n 60 "$dossier/$nom.log" >&2
	done
	echo "intégration : ROUGE" >&2
	exit 1
fi
echo "intégration : verte"
