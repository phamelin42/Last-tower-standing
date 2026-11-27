class_name RegistreAttaques
extends RefCounted
## La liste des scripts d'éléments d'attaque (D22).


## Un élément par fichier sous `visuels/attaques/` : une ligne ici suffit à en ajouter un
## (`AttaquesElementaires.registre` les instancie).
static func scripts() -> Array[GDScript]:
	return [
		AttaqueFeu,
		AttaqueGlace,
		AttaqueBombe,
		AttaquePoison,
		AttaqueFoudre,
		AttaqueArcane,
		AttaqueLame,
		AttaqueFaucille,
		AttaqueDisque,
		AttaqueMoulinet,
		AttaqueGuillotine,
		AttaqueTourbillon,
		AttaqueArbalete,
		AttaqueChausseTrape,
		AttaqueRicochet,
		AttaqueHerse,
		AttaqueBaliste,
		AttaquePluie,
		AttaqueCercleGivre,
		AttaqueNova,
		AttaqueTempete,
		AttaquePetard,
		AttaqueMineForge,
		AttaqueTrebuchet,
		AttaqueGrandeBombe,
		AttaqueDePipe,
		AttaqueSablier,
		AttaqueMiroir,
		AttaqueVortex,
		AttaqueHorloge,
		AttaqueSerpe,
		AttaqueRasoir,
		AttaqueCouperet,
		AttaqueBrume,
		AttaqueFaucheuse,
		AttaqueFleau,
		AttaqueHache,
		AttaqueScie,
		AttaqueMoissonneuse,
		AttaqueJaveline,
		AttaqueTraitGerbe,
		AttaqueFlecheMarquante,
		AttaqueArcRemparts,
		AttaqueHersePieux,
		AttaqueLanceEpineuse,
		AttaqueCarquois,
		AttaqueMurPointes,
		AttaqueCouronnePointes,
		AttaqueRuneVeille,
		AttaqueSiphonneur,
		AttaqueLueur,
		AttaquePrisme,
		AttaqueOrage,
		AttaqueCouronneEtoiles,
		AttaqueVasque,
		AttaqueNuee,
		AttaqueNovaCeleste,
		AttaqueBaril,
		AttaqueMaillet,
		AttaqueCatapulte,
		AttaqueObusier,
		AttaqueBraise,
		AttaqueEcrasement,
		AttaqueColosse,
		AttaqueRuines,
		AttaqueSalve,
		AttaqueUrne,
		AttaquePacte,
		AttaqueJumeau,
		AttaqueSerment,
		AttaqueArchere,
		AttaqueDiscorde,
		AttaqueCoupe,
		AttaqueLegion,
		AttaqueMalefices,
	]


## Les éléments de fin de partie (T12.8) : un par arme de `signatures.familles_tardives`
## (`data/assets.json`), construit sur l'élément de sa famille (`base`, par identifiant) et
## teinté de la teinte de sa rareté (`signatures.raretes_tardives`). Une famille ou une rareté
## inconnue n'en fait aucun : l'arme garde alors son rendu par signature.
static func tardives(base: Dictionary) -> Array[AttaqueElement]:
	var sortie: Array[AttaqueElement] = []
	var signatures: Dictionary = Assets.typee("signatures")
	var familles: Dictionary = signatures.get("familles_tardives", {})
	var teintes: Dictionary = signatures.get("raretes_tardives", {})
	for arme: String in familles:
		var fiche: Dictionary = familles[arme]
		var famille: AttaqueElement = base.get(str(fiche.get("famille", "")))
		var rarete: Dictionary = teintes.get(str(fiche.get("rarete", "")), {})
		if famille == null or rarete.is_empty():
			continue
		sortie.append(AttaqueTardive.creer(arme, famille, rarete["teinte"]))
	return sortie
