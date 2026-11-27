class_name AttaquePercante
extends AttaqueElement
## Ce que partagent les six armes perçantes (famille du carreau) : les couleurs du bois et de
## l'acier, la gerbe d'éclats de l'impact et le projectile planté (carreau ou aiguille). Ce n'est
## pas un élément : chaque arme a le sien, qui l'étend.

const COULEUR_BOIS := Color(0.66, 0.45, 0.23)
const COULEUR_ACIER := Color(0.81, 0.85, 0.92)
const COULEUR_VENIN := Color(0.3, 0.72, 0.29)
const SEQ_GERBE: Array[int] = [0, 0, 1, 1, 2, 2, 3, 3]
## Images de la planche `plante` : elle oscille deux images, puis ne bouge plus.
const IMAGES_OSCILLATION: int = 2
## Un projectile planté garde les pixels du jeu : son diamètre est un multiple entier de celui,
## visible, de la planche `plante`. Le multiple ordinaire est l'échelle des planches ; les
## projectiles lourds prennent ×4.
const MULTIPLE_PLANTE_LOURD: float = 4.0


## Une gerbe d'éclats de bois et d'acier de `diametre` pixels.
func gerbe(m: AttaquesElementaires, ou: Vector2, diametre: float, age: float) -> bool:
	return not m.image_impact("gerbe", ou, diametre, SEQ_GERBE, age).is_empty()


## Un projectile planté en `ou`, visible `images` images (il s'efface sur le dernier quart).
func planter(
	m: AttaquesElementaires, ou: Vector2, images: int, age: float, multiple: float = 0.0
) -> bool:
	var seq: Array[int] = []
	for i: int in images:
		seq.append(0 if i < IMAGES_OSCILLATION else 1)
	var pixels: float = multiple if multiple > 0.0 else PlanchesEffets.echelle()
	var diametre: float = AttaquesElementaires.visible_de("plante") * pixels
	return not m.image_impact("plante", ou, diametre, seq, age).is_empty()


## Une salve d'éclats de `couleur` : `nombre` carrés, vifs et courts.
func eclats(m: AttaquesElementaires, ou: Vector2, nombre: int, couleur: Color) -> void:
	m.salve(ou, nombre, couleur, 12.0 * AttaquesElementaires.IMAGE, 50.0, 140.0, Vector2.ZERO, 1.5)
