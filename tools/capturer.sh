#!/usr/bin/env bash
# Capture une scène Godot image par image (--write-movie) et fabrique une planche-contact.
#
# Usage :
#   tools/capturer.sh <scène res://…> [--images N] [--fps F] [--taille LxH]
#                     [--sortie DOSSIER] [--compat] [--colonnes C] [-- args du jeu…]
#
#   --images N      nombre d'images à rendre (défaut 45, soit 1,5 s à 30 i/s)
#   --fps F         cadence fixe du rendu (défaut 30) : le temps du jeu avance de 1/F par image
#   --taille LxH    redimensionne les images après coup, au plus proche voisin (défaut : taille du
#                   projet, 1152x648). Godot ignore --resolution avec --write-movie, d'où ce repli.
#   --sortie DOSSIER  dossier des images (défaut ${TMPDIR:-/tmp}/capture-<scène>-<horodatage>)
#   --compat        force OpenGL Compatibility (plus rapide, mais SANS traînées de particules)
#   --colonnes C    colonnes de la planche-contact (défaut 5 ; 3 lignes de 5 = 15 images)
#   -- args…        tout ce qui suit est passé au jeu, ex. : tools/capturer.sh
#                   res://scenes/principal.tscn -- --banc-ips 40
#
# Par défaut : Vulkan logiciel (lavapipe) en Forward+, comme le jeu. Seul ce rendu affiche les
# traînées de particules ; si lavapipe est absent, repli OpenGL avec un avertissement.
# Sortie : <dossier>/image_XXXXXXXX.png et <dossier>/planche.png ; une image est répétable au
# pixel près si la scène graine ses particules (use_fixed_seed) et n'utilise pas d'horloge réelle.
# Code de sortie : 0 si tout est bon, 1 si la capture est incomplète ou vide, 2 si l'appel est faux.

set -euo pipefail

cd "$(dirname "$0")/.."
RACINE=$(pwd)

LAVAPIPE=/opt/lavapipe/lvp_icd.json
IMAGES=45
FPS=30
TAILLE=""
SORTIE=""
COMPAT=0
COLONNES=5
LIGNES_PLANCHE=3

erreur() {
	echo "capturer.sh : $*" >&2
}

usage() {
	sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//' >&2
}

entier_positif() {
	[[ "$1" =~ ^[1-9][0-9]*$ ]]
}

# --- Arguments ---------------------------------------------------------------------------------

SCENE=""
ARGS_JEU=()
while (($#)); do
	case "$1" in
	--)
		shift
		ARGS_JEU=("$@")
		break
		;;
	-h | --help)
		usage
		exit 0
		;;
	--images | --fps | --taille | --sortie | --colonnes)
		if (($# < 2)); then
			erreur "l'option $1 attend une valeur"
			exit 2
		fi
		case "$1" in
		--images) IMAGES=$2 ;;
		--fps) FPS=$2 ;;
		--taille) TAILLE=$2 ;;
		--sortie) SORTIE=$2 ;;
		--colonnes) COLONNES=$2 ;;
		esac
		shift 2
		;;
	--compat)
		COMPAT=1
		shift
		;;
	-*)
		erreur "option inconnue : $1"
		usage
		exit 2
		;;
	*)
		if [[ -n "$SCENE" ]]; then
			erreur "une seule scène attendue (reçu « $SCENE » puis « $1 »)"
			exit 2
		fi
		SCENE=$1
		shift
		;;
	esac
done

if [[ -z "$SCENE" ]]; then
	erreur "la scène est obligatoire (ex. res://scenes/banc_ips.tscn)"
	usage
	exit 2
fi
if ! entier_positif "$IMAGES"; then
	erreur "--images doit être un entier supérieur à 0 (reçu « $IMAGES »)"
	exit 2
fi
if ! entier_positif "$FPS"; then
	erreur "--fps doit être un entier supérieur à 0 (reçu « $FPS »)"
	exit 2
fi
if ! entier_positif "$COLONNES"; then
	erreur "--colonnes doit être un entier supérieur à 0 (reçu « $COLONNES »)"
	exit 2
fi
if [[ -n "$TAILLE" && ! "$TAILLE" =~ ^[1-9][0-9]*x[1-9][0-9]*$ ]]; then
	erreur "--taille attend LxH, par exemple 640x360 (reçu « $TAILLE »)"
	exit 2
fi
if [[ "$SCENE" != res://* ]] || [[ ! -f "$RACINE/${SCENE#res://}" ]]; then
	erreur "scène introuvable dans le projet : $SCENE"
	exit 2
fi

# --- Dossier de sortie -------------------------------------------------------------------------

NOM_SCENE=$(basename "$SCENE")
NOM_SCENE=${NOM_SCENE%.*}
if [[ -z "$SORTIE" ]]; then
	SORTIE="${TMPDIR:-/tmp}/capture-${NOM_SCENE}-$(date +%Y%m%d-%H%M%S)"
fi
# --write-movie exige un chemin absolu vers un dossier déjà créé, sinon aucune image n'est écrite.
SORTIE=$(realpath -m "$SORTIE")
mkdir -p "$SORTIE"
# On ne supprime que ce que cette commande produit : les anciennes images de ce dossier, pas le reste.
rm -f "$SORTIE"/image_*.png "$SORTIE"/planche.png

# --- Rendu -------------------------------------------------------------------------------------

if [[ ! -d .godot ]]; then
	echo "Import du projet (.godot absent)…"
	godot --headless --path . --import >/dev/null 2>&1 || true
fi

if [[ -f "$LAVAPIPE" && $COMPAT -eq 0 ]]; then
	MOTEUR="Vulkan lavapipe, Forward+"
	COMMANDE=(env "VK_ICD_FILENAMES=$LAVAPIPE" xvfb-run -a godot --path . --rendering-driver vulkan
		--rendering-method forward_plus)
else
	MOTEUR="OpenGL Compatibility"
	if ((COMPAT)); then
		erreur "avertissement : --compat demandé, les GPUParticles2D à traînée (trail_enabled) n'afficheront AUCUNE particule."
	else
		erreur "avertissement : $LAVAPIPE absent, repli sur OpenGL Compatibility : les GPUParticles2D à traînée (trail_enabled) n'afficheront AUCUNE particule."
	fi
	COMMANDE=(xvfb-run -a godot --path . --rendering-driver opengl3 --rendering-method gl_compatibility)
fi

echo "Capture de $SCENE : $IMAGES images à $FPS i/s, $MOTEUR"

DEBUT=$(date +%s)
JOURNAL="$SORTIE/godot.log"
# --fixed-fps fait avancer le jeu de 1/FPS par image, quelle que soit la lenteur du rendu logiciel.
if ! "${COMMANDE[@]}" --fixed-fps "$FPS" \
	--write-movie "$SORTIE/image_.png" --quit-after "$IMAGES" "$SCENE" "${ARGS_JEU[@]+--}" "${ARGS_JEU[@]}" >"$JOURNAL" 2>&1; then
	erreur "Godot a échoué (journal : $JOURNAL) :"
	tail -n 15 "$JOURNAL" >&2
	exit 1
fi
DUREE=$(($(date +%s) - DEBUT))

# --- Contrôles ---------------------------------------------------------------------------------

mapfile -t FICHIERS < <(find "$SORTIE" -maxdepth 1 -name 'image_*.png' | LC_ALL=C sort)
TROUVEES=${#FICHIERS[@]}
echo "Rendu terminé en ${DUREE} s : $TROUVEES image(s) pour $IMAGES attendue(s)."

ECHEC=0
if ((TROUVEES == 0)); then
	erreur "aucune image écrite (journal : $JOURNAL) :"
	tail -n 15 "$JOURNAL" >&2
	exit 1
fi
if ((TROUVEES != IMAGES)); then
	erreur "écart : $TROUVEES image(s) au lieu de $IMAGES (différence $((TROUVEES - IMAGES)))."
	ECHEC=1
fi

if [[ -n "$TAILLE" ]]; then
	if command -v mogrify >/dev/null; then
		mogrify -filter point -resize "${TAILLE}!" "${FICHIERS[@]}"
	else
		erreur "avertissement : mogrify absent, images laissées à la taille du projet."
	fi
fi

# Une image « unie » a un écart-type nul : rendu noir, fond seul, scène qui ne s'est pas affichée.
if command -v identify >/dev/null; then
	UNIES=0
	for f in "${FICHIERS[@]}"; do
		ecart=$(identify -format '%[fx:standard_deviation]' "$f")
		if awk -v e="$ecart" 'BEGIN { exit !(e + 0 < 0.000001) }'; then
			UNIES=$((UNIES + 1))
		fi
	done
	if ((UNIES == TROUVEES)); then
		erreur "toutes les images sont unies : la scène ne s'est pas affichée (journal : $JOURNAL)."
		ECHEC=1
	elif ((UNIES > 0)); then
		erreur "avertissement : $UNIES image(s) sur $TROUVEES entièrement unie(s)."
	fi
else
	erreur "identify (ImageMagick) absent : contrôle des images unies sauté."
fi

# --- Planche-contact ---------------------------------------------------------------------------

PLANCHE=""
if command -v montage >/dev/null; then
	# Images réparties régulièrement : première et dernière comprises quand il y en a assez.
	voulues=$((COLONNES * LIGNES_PLANCHE))
	((voulues > TROUVEES)) && voulues=$TROUVEES
	SELECTION=()
	for ((i = 0; i < voulues; i++)); do
		if ((voulues == 1)); then
			idx=0
		else
			idx=$((i * (TROUVEES - 1) / (voulues - 1)))
		fi
		# Numéro réel de l'image (0 à N-1) en légende.
		SELECTION+=(-label "$idx" "${FICHIERS[idx]}")
	done
	PLANCHE="$SORTIE/planche.png"
	if ! montage -background '#202020' -fill white -pointsize 14 "${SELECTION[@]}" \
		-tile "${COLONNES}x" -geometry '+4+4' "$PLANCHE" 2>"$SORTIE/montage.log"; then
		erreur "montage a échoué (voir $SORTIE/montage.log), pas de planche."
		PLANCHE=""
	fi
else
	erreur "montage (ImageMagick) absent : pas de planche-contact, les images restent utilisables."
fi

echo "Images : $SORTIE"
if [[ -n "$PLANCHE" ]]; then
	echo "Planche : $PLANCHE"
fi
exit "$ECHEC"
