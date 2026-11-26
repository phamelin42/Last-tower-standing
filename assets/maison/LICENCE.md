# Ressources faites pour ce jeu

Les images de ce dossier sont des créations du projet, mises en CC0 1.0 (domaine public,
<https://creativecommons.org/publicdomain/zero/1.0/>).

## `effets_attaques/`

Sprites d'effets des attaques (boule de feu, explosion, éclat et brisure de glace, givre, bombe,
fiole, nuage et éclaboussure de poison, rune, étincelle, éclair de départ, croissant,
entaille, faucille, balayage, disque de scie, lames de cuivre et tournantes, arc de lame, vapeur et éclats
d'acier, carreaux, chausse-trape, pique de herse, aiguille, carreau planté, gerbe d'éclats, pointes
du sol, vague d'ambre, étoile et éclat astraux, pétard et son pop, rocher, cratère de poussière
et mine de forge, dé, éclat de points, sablier, tourbillon de sable, éclat de miroir, gerbe et vague de
verre, rouage et éclat de rouages), dessinés par
`tools/dessiner_effets_attaques.gd` dans le style et la palette de Tiny Swords : aplats, gros
pixels, contour sombre. Aucun fichier de Tiny Swords n'est copié : seules quelques teintes de
`Effects/Fire/Fire.png` et `Effects/Explosion/Explosions.png` ont été relevées. Le script fait foi :
`godot --headless --path . --script res://tools/dessiner_effets_attaques.gd` régénère les PNG à
l'identique, et `tests/unitaires/test_dessiner_effets_attaques.gd` le vérifie.
