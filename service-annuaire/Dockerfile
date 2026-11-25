# Annuaire des parties en ligne (ADR 001). Le contexte de construction est la racine du dépôt :
#   docker build -f service-annuaire/Dockerfile -t lts-annuaire .
# Le service ne parle que TCP (7779) et garde tout en mémoire : aucun volume.
FROM debian:bookworm-slim

# Même version que tools/install-godot.sh (un test le vérifie). La somme est celle de la ligne de
# SHA512-SUMS.txt de la release godotengine/godot-builds pour l'archive Linux x86_64 standard.
ARG GODOT_VERSION=4.7.2
ARG GODOT_SHA512=9aa00f7a605200940bce3027a567b782f49bd8e940dd06ae9e987bd65aee1b1467edd56ed84fcdcbdd44354bf613bdbb4e5d2913e925850368e150c59ed54c65

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl unzip \
    && rm -rf /var/lib/apt/lists/*

# Contrairement à install-godot.sh, la construction échoue si la somme diffère : aucun repli
# « archive non vérifiée ».
RUN set -eu; \
    archive="Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip"; \
    curl -fsSL --retry 3 --max-time 900 -o "/tmp/${archive}" \
        "https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}-stable/${archive}"; \
    echo "${GODOT_SHA512}  /tmp/${archive}" | sha512sum -c -; \
    unzip -q "/tmp/${archive}" -d /tmp/godot; \
    install -m 0755 "/tmp/godot/Godot_v${GODOT_VERSION}-stable_linux.x86_64" /usr/local/bin/godot; \
    rm -rf /tmp/godot "/tmp/${archive}"

# Utilisateur sans droits : il possède le dépôt copié et le cache d'import, rien d'autre.
RUN useradd --system --create-home --uid 10001 annuaire \
    && install -d -o annuaire -g annuaire /app
WORKDIR /app
COPY --chown=annuaire:annuaire . /app
USER annuaire

# Le cache d'import (.godot/) est produit à la construction : au démarrage, le système de fichiers
# du conteneur peut être en lecture seule.
RUN godot --headless --path /app --import

EXPOSE 7779/tcp
ENTRYPOINT ["godot", "--headless", "--path", "/app", "--", "--annuaire"]
