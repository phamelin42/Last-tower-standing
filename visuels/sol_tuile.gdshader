shader_type canvas_item;
// Répète une seule tuile d'une planche de terrain sur tout le sprite (le sprite porte la planche
// entière, étirée sur la zone à couvrir). Provisoire : le vrai terrain en tuiles vient avec T5.2.

uniform vec2 origine_uv = vec2(0.1, 0.25);
uniform vec2 taille_uv = vec2(0.1, 0.25);
uniform vec2 repetitions = vec2(100.0, 100.0);

void fragment() {
	COLOR = texture(TEXTURE, origine_uv + fract(UV * repetitions) * taille_uv);
}
