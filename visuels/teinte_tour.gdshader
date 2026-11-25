shader_type canvas_item;
// Tourne la teinte de la pierre bleue du pack, pour les joueurs 5 à 8. Les gris, le bois et les
// autres couleurs gardent leur teinte : seuls les pixels colorés de la famille bleu-vert bougent.

uniform float decalage_teinte = 0.0;
uniform float teinte_min = 0.375;
uniform float teinte_max = 0.75;
uniform float saturation_min = 0.2;

vec3 rgb_vers_hsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv_vers_rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

void fragment() {
	vec3 hsv = rgb_vers_hsv(COLOR.rgb);
	if (hsv.y > saturation_min && hsv.x >= teinte_min && hsv.x <= teinte_max) {
		hsv.x = fract(hsv.x + decalage_teinte);
	}
	COLOR = vec4(hsv_vers_rgb(hsv), COLOR.a);
}
