"""Assemble docs/skins/planche_v4.png : les 50 skins tels que le jeu les lira dans data/skins_tour.json.

Usage (depuis la racine) : python3 -I docs/skins/generer_planche.py
Pillow (licence HPND, libre) seulement. Chaque case montre le sprite du skin (son cadre), puis son défi,
sa licence, la marque de couleur et l'adéquation avec la silhouette de docs/defis.md. Aucun sprite
n'est retouché : le fanion bleu de la marque est posé à l'affichage, dans la zone `marque` du JSON, comme
le fera le jeu (T11.7), et n'entre dans aucun fichier de sprite.
"""

import json
import re
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

RACINE = Path(__file__).resolve().parents[2]
# Adéquation de chaque skin avec l'idée de silhouette de docs/defis.md : B bon, P partiel, R rapproché.
ADEQUATION = {
    "tour_de_guet": "B",
    "tour_de_pierre": "P",
    "tour_du_vainqueur": "P",
    "tour_sans_horizon": "R",
    "tour_lame": "R",
    "tour_pointe": "B",
    "tour_arcane": "B",
    "tour_bastion": "P",
    "tour_fissure": "B",
    "tour_oeil": "R",
    "tour_nuee": "R",
    "tour_ricochet": "P",
    "tour_sonore": "R",
    "tour_salve": "P",
    "tour_embuscade": "R",
    "tour_sapeur": "R",
    "tour_halo": "R",
    "tour_manege": "R",
    "tour_venimeuse": "B",
    "tour_braise": "B",
    "tour_gelee": "B",
    "tour_tonnerre": "R",
    "tour_sanguine": "R",
    "tour_monolame": "B",
    "tour_du_duelliste": "P",
    "tour_du_tresor": "B",
    "tour_ascete": "R",
    "tour_du_puits": "P",
    "tour_du_dragon_avare": "P",
    "tour_du_chariot": "P",
    "tour_du_banquier": "R",
    "tour_de_granit": "R",
    "tour_rafistolee": "P",
    "tour_du_bouclier": "R",
    "tour_cicatrisee": "R",
    "tour_nue": "R",
    "tour_a_faux": "R",
    "tour_arsenal": "R",
    "tour_de_ronces": "R",
    "tour_survivante": "P",
    "tour_familiere": "R",
    "tour_veterane": "R",
    "tour_conquerante": "P",
    "tour_ossuaire": "R",
    "tour_comptoir": "R",
    "tour_eternelle": "R",
    "tour_de_la_table_ronde": "P",
    "tour_du_dernier_rempart": "R",
    "tour_cratere": "R",
    "tour_artificier": "R",
}
COUL = {"B": (60, 160, 80), "P": (220, 170, 40), "R": (210, 110, 40)}
LIB = {"B": "bon", "P": "partiel", "R": "rapproché"}


def lire_skins() -> list[tuple[str, str, str]]:
    texte = (RACINE / "docs/defis.md").read_text(encoding="utf-8")
    section = texte.split("## 5. Un skin par défi")[1].split("## 6.")[0]
    return [
        (m[0], m[1], m[2].strip())
        for m in re.findall(r"^\| `(\w+)`\s*\| `(\w+)`\s*\| (.+?)\s*\|$", section, re.M)
    ]


def sprite(skin: dict) -> Image.Image:
    im = Image.open(RACINE / str(skin["sprite"]).removeprefix("res://")).convert("RGBA")
    if "cadre" in skin:
        c = skin["cadre"]
        im = im.crop((c["x"], c["y"], c["x"] + c["largeur"], c["y"] + c["hauteur"]))
    return im


def fanion(im: Image.Image, zone: dict) -> None:
    """Pose le fanion de la marque (bleu de Tiny Swords) dans la zone du JSON, par-dessus le sprite."""
    d = ImageDraw.Draw(im)
    x, y = zone["x"] + 2, zone["y"]
    d.line((x, y, x, y + zone["hauteur"] - 2), fill=(90, 70, 70), width=2)
    d.polygon([(x + 1, y), (x + 14, y + 5), (x + 1, y + 11)], fill=(68, 142, 159), outline=(22, 28, 46))


def main() -> None:
    police = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 13)
    gras = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 14)
    skins = lire_skins()
    donnees = json.loads((RACINE / "data/skins_tour.json").read_text(encoding="utf-8"))
    cols, lc, hc = 3, 400, 215
    lignes = (len(skins) + cols - 1) // cols
    planche = Image.new("RGBA", (cols * lc, lignes * hc + 60), (36, 38, 44, 255))
    d = ImageDraw.Draw(planche)
    nb = {k: 0 for k in COUL}
    emploi: dict[str, int] = {}
    for _, skin, _ in skins:
        cle = json.dumps([donnees[skin]["sprite"], donnees[skin].get("cadre")], sort_keys=True)
        emploi[cle] = emploi.get(cle, 0) + 1
    for i, (defi, skin, idee) in enumerate(skins):
        x, y = (i % cols) * lc, (i // cols) * hc + 60
        entree = donnees[skin]
        q = ADEQUATION[skin]
        nb[q] += 1
        d.rectangle((x + 4, y + 4, x + lc - 4, y + hc - 4), outline=COUL[q], width=2)
        im = sprite(entree)
        marque = entree["marque"]
        if marque["genre"] == "fanion":
            fanion(im, marque)
        facteur = min(1.0 * 200 / im.height, 2.0)
        im = im.resize((max(1, int(im.width * facteur)), max(1, int(im.height * facteur))), Image.NEAREST)
        im.thumbnail((165, 200), Image.NEAREST)
        planche.paste(im, (x + 10, y + 8), im)
        d.text((x + 180, y + 10), skin, font=gras, fill=(240, 240, 240))
        d.text((x + 180, y + 32), f"défi : {defi}", font=police, fill=(170, 170, 180))
        d.text((x + 180, y + 52), f"adéquation : {LIB[q]}", font=gras, fill=COUL[q])
        cle = json.dumps([entree["sprite"], entree.get("cadre")], sort_keys=True)
        if emploi[cle] > 1:
            d.text((x + 180, y + 72), f"réemploi ({emploi[cle]} skins)", font=police, fill=(230, 130, 130))
        ligne, ys = "", y + 94
        for m in idee.split():
            if d.textlength(ligne + " " + m, font=police) > 205:
                d.text((x + 180, ys), ligne.strip(), font=police, fill=(210, 210, 215))
                ligne, ys = "", ys + 17
            ligne += " " + m
        d.text((x + 180, ys), ligne.strip(), font=police, fill=(210, 210, 215))
        note = "marque d'origine (teintable)" if marque["genre"] == "origine" else "fanion posé à l'affichage"
        d.text((x + 180, y + hc - 46), note, font=police, fill=(150, 200, 230))
        d.text((x + 180, y + hc - 28), Path(entree["sprite"]).name, font=police, fill=(120, 120, 130))
    distincts = len(emploi)
    d.text(
        (10, 18),
        f"{len(skins)} skins : {nb['B']} bons, {nb['P']} partiels, {nb['R']} rapprochés ; "
        f"{distincts} images distinctes, {len(skins) - distincts} réemplois",
        font=gras,
        fill=(240, 240, 240),
    )
    planche.convert("RGB").save(RACINE / "docs/skins/planche_v4.png")
    print(dict(nb), len(skins), distincts, len(skins) - distincts)


if __name__ == "__main__":
    main()
