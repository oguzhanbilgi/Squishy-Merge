shader_type canvas_item;
// Legendary aura (M8.5-14): sprite'in arkasindaki radyal parilti, TIME ile
// nefes alir ve yavas doner. Script yok, parcacik yok, RNG yok.
// Renk sprite'in modulate'inden (SkinData.aura_color) gelir.

varying vec4 v_modulate;

void vertex() {
	v_modulate = COLOR;
}

void fragment() {
	vec2 c = UV - 0.5;
	float ang = atan(c.y, c.x);
	// 6 kollu yumusak yildiz: duz daireden daha "premium" okunur.
	float rays = 0.85 + 0.15 * sin(ang * 6.0 + TIME * 0.6);
	float breath = 0.78 + 0.22 * sin(TIME * 1.7);
	vec4 src = texture(TEXTURE, UV);
	COLOR = vec4(src.rgb, src.a * rays * breath) * v_modulate;
}
