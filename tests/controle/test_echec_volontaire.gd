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
