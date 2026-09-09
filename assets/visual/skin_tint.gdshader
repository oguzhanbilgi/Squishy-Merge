shader_type canvas_item;
// Dumpling skin onizlemesi (M8.5).
//
// Duz `modulate` KULLANILMIYOR. Duz carpim uc seyi birden bozuyor:
//   - koyu kontur ve gozler daha da koyulasip yuzu okunamaz hale getiriyor,
//   - spekuler parlamalar sonuyor, sprite plastik gorunumunu kaybediyor,
//   - her tier ayni renge kaydigi icin boyut disinda ayirt edilemez oluyor.
//
// Bunun yerine: pikselin LUMINANSI korunur, yalnizca RENGI skin tonuna dogru
// kaydirilir; ustelik bu kaydirma orta tonlarla sinirlidir. Koyu uclar
// (kontur/goz/agiz) ve acik uclar (parlama) maskeyle korunur.

uniform vec4 skin_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
// 0 = dokunma, 1 = tam renk degisimi. Uretimde SkinVisual.STRENGTH veriyor.
uniform float strength : hint_range(0.0, 1.0) = 0.0;
// Bu luminansin ALTI kontur/goz sayilir, korunur.
uniform float shadow_guard : hint_range(0.0, 0.6) = 0.28;
// Bu luminansin USTU parlama sayilir, korunur.
uniform float highlight_guard : hint_range(0.4, 1.0) = 0.82;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	if (src.a > 0.001 && strength > 0.001) {
		float lum = dot(src.rgb, LUMA);
		// Orta tonlarda 1'e yaklasan, iki ucta 0'a inen maske.
		float mask = smoothstep(0.0, shadow_guard, lum)
			* (1.0 - smoothstep(highlight_guard, 1.0, lum));
		// Skin tonunu pikselin kendi luminansina normalize et: renk degisir,
		// aydinlik/golge dagilimi (yani shading) oldugu gibi kalir.
		float tint_lum = max(dot(skin_tint.rgb, LUMA), 0.001);
		vec3 tinted = clamp(skin_tint.rgb * (lum / tint_lum), 0.0, 1.0);
		src.rgb = mix(src.rgb, tinted, strength * mask);
	}
	COLOR = src * COLOR;
}
