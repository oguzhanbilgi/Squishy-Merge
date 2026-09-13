shader_type canvas_item;
// Production gameplay skin render'i (M8.5-14).
//
// Tier sprite'i OLDUGU GIBI kalir (siluet, yuz, yanak, aksesuar); yalnizca
// `body_mask` (assets/visual/skins/generated/body_mask_tier*.png, tools/
// make_skin_masks.py) ile isaretlenen HAMUR GOVDESI yeniden boyanir ve
// desenlenir. Eski tum-sprite hue kaydirmasi (skin_tint.gdshader) yerine:
//
//   1. govde pikselinin LUMINANSI okunur (golge/isik dagilimi buradan gelir),
//   2. luminansa gore shade -> body -> highlight rengi secilir (renk tamamen
//      skin'in, shading tamamen sprite'in),
//   3. deterministik desen (hash/sin, TIME disinda rastgelelik yok) govde
//      uzerine bindirilir; desen sprite UV'siyle tasinir, ekranda kaymaz,
//   4. rarity katmani: gloss / pearl / sparkle (Epic-Legendary), hepsi maske
//      icinde — yuz asla boyanmaz.
//
// Renkler `SkinData` .tres alanlarindan gelir (scripts/game/skin_data.gd),
// materyal skin x tier basina bir kez kurulur (scripts/game/skin_visual.gd).
// Global RNG KULLANILMAZ.

uniform sampler2D body_mask : filter_linear, repeat_disable;
uniform vec4 body_color : source_color = vec4(0.96, 0.92, 0.84, 1.0);
uniform vec4 shade_color : source_color = vec4(0.72, 0.62, 0.50, 1.0);
uniform vec4 highlight_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
// Desen ailesi — SkinData.Pattern ile ayni sira:
// 0 NONE 1 SPECKLE 2 FLECK 3 RING 4 MARBLE 5 SWIRL 6 CRYSTAL 7 STREAK
// 8 WAVE 9 IRIDESCENT 10 METAL
uniform int pattern_type = 0;
uniform vec4 pattern_color : source_color = vec4(0.3, 0.2, 0.1, 1.0);
uniform vec4 pattern_color2 : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float pattern_density : hint_range(0.0, 1.0) = 0.5;
uniform float pattern_scale : hint_range(0.2, 4.0) = 1.0;
uniform float pattern_strength : hint_range(0.0, 1.0) = 0.8;
// Tier'a gore detay olcegi: kucuk parcalarda daha az ama daha buyuk hucre.
uniform float detail_scale : hint_range(0.3, 1.5) = 1.0;
uniform float gloss : hint_range(0.0, 1.0) = 0.0;
uniform float pearl : hint_range(0.0, 1.0) = 0.0;
uniform float sparkle : hint_range(0.0, 1.0) = 0.0;
uniform float anim_speed : hint_range(0.0, 3.0) = 1.0;
// Dokunun en/boy orani: hucreler ekranda kare kalsin (x/y).
uniform float aspect = 1.0;

// Godot 4: fragment()'taki COLOR = doku x modulate. Dokuyu kendimiz
// okuduğumuz için modulate'i vertex'ten ayrı taşıyoruz — `src * COLOR`
// dokuyu iki kez çarpar (eski skin_tint.gdshader'ın zayıflığının sebebi).
varying vec4 v_modulate;

void vertex() {
	v_modulate = COLOR;
}

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);
// Govde orta tonunun referans luminansi (8 tier'in olcumu ~0.80-0.86).
const float BODY_MID = 0.82;

float hash1(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 hash2(vec2 p) {
	return vec2(hash1(p), hash1(p + vec2(17.3, 5.7)));
}

// Hucre tabanli deterministik blob alani. Her hucrede en fazla bir blob;
// `density` hucrenin dolu olma olasiligi, `elong` 1 = daire, <1 = uzun.
// Donus: [blob kapsama (0..1), varyant hash (0..1)]
vec2 blobs(vec2 uv, float cells, float radius, float density, float elong, float edge) {
	vec2 g = uv * cells;
	vec2 id = floor(g);
	vec2 f = fract(g);
	float cover = 0.0;
	float variant = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 n = vec2(float(x), float(y));
			vec2 cid = id + n;
			float on = step(hash1(cid + 3.1), density);
			vec2 h = hash2(cid);
			vec2 c = n + 0.3 + h * 0.4;
			float ang = hash1(cid + 9.2) * 6.2832;
			vec2 d = f - c;
			vec2 r = vec2(cos(ang) * d.x + sin(ang) * d.y, -sin(ang) * d.x + cos(ang) * d.y);
			r.y /= elong;
			float rad = radius * (0.65 + 0.7 * hash1(cid + 1.7));
			float dist = length(r);
			float b = (1.0 - smoothstep(rad - edge, rad + edge, dist)) * on;
			if (b > cover) {
				cover = b;
				variant = hash1(cid + 5.5);
			}
		}
	}
	return vec2(cover, variant);
}

// Ince, halkalar (yesil sogan).
float rings(vec2 uv, float cells, float density) {
	vec2 g = uv * cells;
	vec2 id = floor(g);
	vec2 f = fract(g);
	float cover = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 n = vec2(float(x), float(y));
			vec2 cid = id + n;
			float on = step(hash1(cid + 3.1), density);
			vec2 c = n + 0.3 + hash2(cid) * 0.4;
			float rad = 0.16 + 0.12 * hash1(cid + 1.7);
			float dist = length(f - c);
			float ring = (1.0 - smoothstep(rad + 0.03, rad + 0.09, dist)) * smoothstep(rad - 0.09, rad - 0.03, dist);
			cover = max(cover, ring * on);
		}
	}
	return cover;
}

// Yumusak, deterministik organik alan (mermer / girdap / dalga icin).
float fnoise(vec2 p) {
	return 0.5 + 0.5 * sin(p.x * 3.1 + sin(p.y * 2.3 + 1.7)) * sin(p.y * 2.7 + sin(p.x * 1.9 + 0.4));
}

vec3 hue_wheel(float t) {
	// Pastel gokkusagi: doygunlugu dusuk, parlakligi yuksek.
	vec3 c = 0.5 + 0.5 * cos(6.2832 * (t + vec3(0.0, 0.33, 0.67)));
	return mix(vec3(0.85), c, 0.55);
}

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	float m = texture(body_mask, UV).r * step(0.001, src.a);
	vec3 out_rgb = src.rgb;
	if (m > 0.001) {
		float lum = dot(src.rgb, LUMA);
		// Sprite shading'i skin renklerine cevir.
		float t = clamp(lum / BODY_MID, 0.0, 1.35);
		vec3 base = mix(shade_color.rgb, body_color.rgb, smoothstep(0.30, 1.0, t));
		float hi = smoothstep(0.90, 0.99, lum);
		base = mix(base, highlight_color.rgb, hi * (0.7 + 0.3 * gloss));
		// Gloss: orta-ustu tonlarda hafif ekstra parlama.
		base += gloss * 0.12 * smoothstep(0.78, 0.92, lum);

		// Desen (sprite UV'si; hucreler ekranda kareye yakin kalsin).
		vec2 puv = vec2(UV.x * aspect, UV.y);
		float cells = 9.0 * pattern_scale * detail_scale;
		float tm = TIME * anim_speed;
		vec3 pat = base;
		float pw = 0.0;
		if (pattern_type == 1) {          // SPECKLE (susam, karabiber)
			vec2 b = blobs(puv, cells, 0.13, pattern_density, 1.0, 0.03);
			pat = mix(pattern_color.rgb, pattern_color2.rgb, step(0.55, b.y));
			pw = b.x;
		} else if (pattern_type == 2) {   // FLECK (kepek, havuc, ispanak, biber)
			vec2 b = blobs(puv, cells, 0.14, pattern_density, 0.45, 0.04);
			pat = mix(pattern_color.rgb, pattern_color2.rgb, smoothstep(0.4, 0.7, b.y));
			pw = b.x;
		} else if (pattern_type == 3) {   // RING (yesil sogan)
			pw = rings(puv, cells * 0.8, pattern_density);
			pat = pattern_color.rgb;
		} else if (pattern_type == 4) {   // MARBLE (mantar, kakao)
			float n = fnoise(puv * cells * 0.45 + 0.7 * fnoise(puv * cells * 0.2));
			pw = smoothstep(0.42, 0.7, n) * 0.9;
			pat = pattern_color.rgb;
		} else if (pattern_type == 5) {   // SWIRL (zencefil, safran iplikleri)
			vec2 c = puv - vec2(0.5 * aspect, 0.55);
			float a = atan(c.y, c.x) + length(c) * 9.0 * pattern_scale;
			float s = 0.5 + 0.5 * sin(a * 3.0 + fnoise(puv * cells * 0.3) * 4.0);
			pw = smoothstep(0.5, 0.85, s) * 0.85;
			pat = pattern_color.rgb;
		} else if (pattern_type == 6) {   // CRYSTAL (deniz tuzu)
			vec2 b = blobs(puv, cells, 0.13, pattern_density, 0.5, 0.015);
			float tw = 0.7 + 0.3 * sin(tm * 2.0 + b.y * 6.28);
			pat = mix(pattern_color.rgb, pattern_color2.rgb, b.y);
			pw = b.x * tw;
		} else if (pattern_type == 7) {   // STREAK (aci sos)
			float s = 0.5 + 0.5 * sin((puv.x * 0.7 + puv.y) * cells * 1.4 + fnoise(puv * cells * 0.35) * 3.0);
			pw = smoothstep(0.7, 0.95, s) * 0.7;
			pat = pattern_color.rgb;
			vec2 b = blobs(puv, cells, 0.11, pattern_density * 0.6, 0.6, 0.04);
			pat = mix(pat, pattern_color2.rgb, b.x);
			pw = max(pw, b.x);
		} else if (pattern_type == 8) {   // WAVE (yosun)
			float s = 0.5 + 0.5 * sin(puv.y * cells * 1.6 + sin(puv.x * cells * 0.9 + tm * 0.4) * 1.6);
			pw = smoothstep(0.6, 0.95, s) * 0.55;
			pat = pattern_color.rgb;
			vec2 b = blobs(puv, cells * 0.9, 0.09, pattern_density * 0.5, 1.0, 0.03);
			pat = mix(pat, pattern_color2.rgb, b.x);
			pw = max(pw, b.x * 0.9);
		} else if (pattern_type == 9) {   // IRIDESCENT (gokkusagi)
			float phase = (puv.x * 0.6 + puv.y * 0.8) * 0.9 + tm * 0.08;
			vec3 rainbow = hue_wheel(phase);
			pat = rainbow * (0.75 + 0.25 * t);
			pw = 1.0;
		} else if (pattern_type == 10) {  // METAL (altin hamur)
			float band = 0.5 + 0.5 * sin((puv.x + puv.y * 0.6) * 7.0 - tm * 0.9);
			float grain = fnoise(puv * cells * 0.8);
			pw = smoothstep(0.75, 1.0, band) * 0.5 + grain * 0.12;
			pat = pattern_color.rgb;
		}
		vec3 body = mix(base, pat, clamp(pw * pattern_strength, 0.0, 1.0));
		// Desen de golgeyi taşısın: koyu bolgede desen de kararir.
		body *= mix(1.0, 0.55 + 0.45 * t, 0.6 * step(1.0, float(pattern_type)) * (1.0 - step(9.0, float(pattern_type))));

		// Pearl: acidan bagimsiz sedef — ton, luminans ve konuma gore doner.
		if (pearl > 0.001) {
			vec3 sheen = hue_wheel(lum * 1.3 + puv.x * 0.5 + tm * 0.05);
			body = mix(body, body * 0.6 + sheen * 0.55, pearl * smoothstep(0.6, 0.95, lum));
		}
		// Sparkle: hucre basina faz kaydirmali, deterministik kucuk glint'ler.
		if (sparkle > 0.001) {
			vec2 b = blobs(puv + 0.37, cells * 1.1, 0.06, 0.35, 1.0, 0.02);
			float pulse = pow(max(0.0, sin(tm * 2.2 + b.y * 6.2832)), 6.0);
			body += vec3(1.0, 0.98, 0.9) * b.x * pulse * sparkle * 0.9;
		}
		out_rgb = mix(src.rgb, body, m);
	}
	COLOR = vec4(out_rgb, src.a) * v_modulate;
}
