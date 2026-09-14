class_name UiTokens
extends RefCounted
## Production UI tasarim token'larinin TEK kaynagi (M8.6-01).
##
## Renk, bosluk, yaricap, kontrol yuksekligi, ikon boyutu, golge ve parilti
## degerleri BURADA tanimlanir; `tools/make_ui_theme.gd` bunlardan
## `assets/visual/ui_theme.tres`'i uretir, `UiKit` bilesenleri bunlari okur.
## Yeni ekranlar rastgele literal (Color("..."), 13 px, 0.37 alfa) YAZMAZ —
## bir deger burada yoksa once buraya eklenir. Tam belge:
## docs/UI_VISUAL_SYSTEM.md.
##
## Renk dili (M8.6): dunya gece civit/mor; icerik kartlari sicak vanilya/krem;
## ikincil yuzeyler lavanta/erik; birincil CTA candy cyan; satin alma nane;
## vurgu candy pembe; premium altin (YALNIZ Legendary + onemli odul);
## pasif doygunlugu alinmis lavanta-gri. Tonlar owner asset'lerinden olculdu
## (`UiPalette` ile ayni degerler — o dosya M8.5 kabugunun, bu dosya M8.6
## sisteminin kaynagi; ikisi ayni sayilari tasir).

# --- Dunya / zemin -----------------------------------------------------------
const WORLD_INDIGO: Color = Color("0d153f")
const WORLD_INDIGO_MID: Color = Color("2d2a6c")
## Koyu lacivert-mor plaka (HUD, kaynak pill'i, pencere karartma rengi).
const NAVY_PURPLE: Color = Color("2a1f5c")
const NAVY_PURPLE_DEEP: Color = Color("1a1440")

# --- Yuzeyler ----------------------------------------------------------------
## Icerik karti / modal govdesi (LayerLab beyaz gövde bu renkle boyanir).
const CREAM: Color = Color("fcf7ec")
## Krem ustunde ikincil dolgu (satir arka plani, stok balonu).
const CREAM_DEEP: Color = Color("f1e9dc")
## Ikincil yuzey: koyu zemin ustunde erik plaka.
const PLUM: Color = Color("453885")
## Ikincil buton / lavanta yuzey (krem ustunde "Bitir", "Kapat").
const LAVENDER: Color = Color("c694fa")
const LAVENDER_SURFACE: Color = Color("dccbe8")

# --- Candy vurgular ----------------------------------------------------------
const CYAN: Color = Color("5eddf9")
const CYAN_DEEP: Color = Color("2f8fd0")
const PINK: Color = Color("f06aa8")
const PINK_DEEP: Color = Color("c94a86")
const MINT: Color = Color("6ddc8b")
const MINT_DEEP: Color = Color("2f9e57")
const GOLD: Color = Color("ffd166")
const GOLD_BRIGHT: Color = Color("fee85f")
const GOLD_DEEP: Color = Color("b8731f")
## Pasif: doygunlugu alinmis lavanta-gri (okunur kalir, bagirmaz).
const DISABLED: Color = Color("8a86a8")
const DISABLED_DEEP: Color = Color("5c5878")

# --- Metin -------------------------------------------------------------------
## Krem yuzey ustundeki koyu erik.
const TEXT_PRIMARY: Color = Color("5c2952")
const TEXT_SECONDARY: Color = Color("7a4a69")
const TEXT_TERTIARY: Color = Color("a07f95")
## Koyu yuzey ustundeki beyaz.
const TEXT_ON_DARK: Color = Color(0.99, 0.97, 1.0)
const TEXT_ON_DARK_MUTED: Color = Color(1, 1, 1, 0.62)
## Cyan / nane / altin butonlarin ustundeki lacivert.
const TEXT_ON_ACCENT: Color = Color("0f2e4d")
const TEXT_DISABLED: Color = Color("4a4766")
const TEXT_DISABLED_ON_DARK: Color = Color(1, 1, 1, 0.45)
## Fiyat: krem ustunde koyu altin (GOLD kremde okunmuyor).
const TEXT_PRICE: Color = GOLD_DEEP
const TEXT_POSITIVE: Color = MINT_DEEP
const TEXT_WARNING: Color = Color("d4762b")
const HIGHLIGHT: Color = Color.WHITE
## Metin golgesi (koyu zemin ustundeki baslik/HUD).
const TEXT_SHADOW: Color = Color(0.02, 0.01, 0.05, 0.6)

# --- Rarity ------------------------------------------------------------------
## Oyun verisiyle (SkinData.rarity_color) AYNI tonlar; test bunu dogrular.
const RARITY_COMMON: Color = Color("9aa0a6")
const RARITY_RARE: Color = Color("4c9be8")
const RARITY_EPIC: Color = Color("a55cd6")
const RARITY_LEGENDARY: Color = Color("f0a92e")

# --- Bosluk ------------------------------------------------------------------
const SPACE_XS: int = 4
const SPACE_SM: int = 8
const SPACE_MD: int = 12
const SPACE_LG: int = 20
const SPACE_XL: int = 32

# --- Yaricap (StyleBoxFlat cizimleri; 9-slice'lar kendi koselerini tasir) ---
const RADIUS_SMALL: int = 12
const RADIUS_MEDIUM: int = 20
const RADIUS_LARGE: int = 28

# --- Kontrol yukseklikleri (dokunma hedefi >= 48) --------------------------
const HEIGHT_COMPACT: int = 44
const HEIGHT_NORMAL: int = 56
const HEIGHT_LARGE: int = 72
const HEIGHT_HERO: int = 88
const TOUCH_MIN: int = 48

# --- Ikon boyutlari ----------------------------------------------------------
const ICON_SMALL: int = 24
const ICON_MEDIUM: int = 32
const ICON_LARGE: int = 48
const ICON_HERO: int = 72

# --- Golge (StyleBoxFlat shadow_* icin) -------------------------------------
const SHADOW_SOFT: Dictionary = {"color": Color(0.03, 0.02, 0.12, 0.22), "size": 4, "offset": Vector2(0, 2)}
const SHADOW_NORMAL: Dictionary = {"color": Color(0.03, 0.02, 0.12, 0.35), "size": 8, "offset": Vector2(0, 4)}
const SHADOW_ELEVATED: Dictionary = {"color": Color(0.03, 0.02, 0.12, 0.45), "size": 16, "offset": Vector2(0, 8)}

# --- Parilti (popup_glow / item_focus modulate'i) ---------------------------
const GLOW_SUBTLE: Color = Color(0.94, 0.42, 0.66, 0.35)
const GLOW_PREMIUM: Color = Color(1.0, 0.82, 0.4, 0.6)


static func rarity_color(rarity: int) -> Color:
	match rarity:
		SkinData.Rarity.RARE: return RARITY_RARE
		SkinData.Rarity.EPIC: return RARITY_EPIC
		SkinData.Rarity.LEGENDARY: return RARITY_LEGENDARY
	return RARITY_COMMON


## Krem kart ustundeki rarity etiketi/cercevesi icin okunur ton: Common gri
## kremde kayboluyor, digerleri hafif koyulasinca beyaz yazi tasiyor.
static func rarity_tint(rarity: int) -> Color:
	var color: Color = rarity_color(rarity)
	if rarity == SkinData.Rarity.COMMON:
		return color.darkened(0.12)
	return color


static func shadow_apply(box: StyleBoxFlat, shadow: Dictionary) -> StyleBoxFlat:
	box.shadow_color = shadow["color"]
	box.shadow_size = shadow["size"]
	box.shadow_offset = shadow["offset"]
	return box
