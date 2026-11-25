extends CasDeTest
## Tests qui DOIVENT échouer : `--controle` prouve que le lanceur détecte un échec.
## Jamais lancés par la suite normale.


func test_echec_assertion() -> void:
	verifier(false, "échec volontaire")


func test_sans_assertion() -> void:
	pass


func test_erreur_execution() -> void:
	var rien: Object = null
	verifier(true, "cette assertion réussit, puis la méthode plante")
	rien.call("inexistante")


func test_async_delai_depasse() -> void:
	delai_max = 0.2
	verifier(true, "cette assertion réussit, puis la méthode attend trop longtemps")
	await arbre.create_timer(5.0).timeout


func test_async_echec_apres_await() -> void:
	await attendre_images(2)
	verifier(false, "échec volontaire après un await")
