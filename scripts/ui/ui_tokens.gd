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
## (M8.5 kabugunun palet dosyasi M8.6-10'da emekli oldu; tek kaynak burasi,
## sayilar UI_VISUAL_SYSTEM §2 ile kilitli).

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
## Gameplay HUD (M8.6-02 HUD v3, hud_target.png'den olculdu): govde koyu
## lavanta-mor, kenar/tepsi acik lavanta-krem.
const LAVENDER_DEEP: Color = Color("8b72dc")
const LAVENDER_LIGHT: Color = Color("ece3fb")
const TRAY_CREAM: Color = Color("f3e9f9")
## Madalyon cam ic diski (acik gok mavisi) ve pasif hali.
const GLASS_BLUE: Color = Color("bfe6ff")
const GLASS_MUTED: Color = Color("d9d4e8")

# --- Candy vurgular ----------------------------------------------------------
const CYAN: Color = Color("5eddf9")
const CYAN_DEEP: Color = Color("2f8fd0")
## "Hamur yetmiyor" satin alma butonu (M8.6-05): cyan ailesinin doygunlugu
## alinmis hali — hala "satin alma butonu" okunur (dokunulabilir, geri
## bildirim verir), gercek pasif DISABLED lavanta-grisinden ayrik.
const CYAN_MUTED: Color = Color("8fbfd2")
const PINK: Color = Color("f06aa8")
const PINK_DEEP: Color = Color("c94a86")
const MINT: Color = Color("6ddc8b")
const MINT_DEEP: Color = Color("2f9e57")
const GOLD: Color = Color("ffd166")
const GOLD_BRIGHT: Color = Color("fee85f")
const GOLD_DEEP: Color = Color("b8731f")
## Pasif: doygunlugu alinmis lavanta-gri (okunur kalir, bagirmaz).
## Govde acik tutulur ki ustundeki koyu yazi/ikon telefonda okunsun
## (TEXT_DISABLED ile ~4.8:1); koyu ton rozet/etiket icin.
const DISABLED: Color = Color("a19dba")
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
## Pasif buton yazisi/ikonu: DISABLED govde ustunde ~4.8:1 (olculdu).
const TEXT_DISABLED: Color = Color("33304d")
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


# =============================================================================
# Squishy UI System V3 (TASK/057) — yukaridaki M8.6 tokenlarinin EVRIMI, ikinci
# bir sistem DEGIL. V3 bilesenleri (SquishyButton, FeatureCard, OfferCard,
# PowerCard, AttentionBadge, NavItem / GlobalNav) yalniz bu bolumu + yukaridaki
# paleti okur. Belge: docs/UI_VISUAL_SYSTEM.md §27.
# =============================================================================

# --- V3 olcum temeli (A36 olcumu, TASK/057 Faz A) ----------------------------
## Mantiksal tuval genisligi HER telefonda 720 px (`canvas_items` + `expand`;
## yukseklik serbest). Samsung A36: 1080 px fiziksel, yogunluk 2.625 →
## 1 tuval px = 1.5 fiziksel px = 0.571 dp. 360 dp genislikli dar telefonda
## 1 tuval px = 0.5 dp. Yani mevcut 56 px ikon butonu A36'da yalniz 32 dp,
## eski TOUCH_MIN 48 px = 27 dp (Android onerisi 48 dp) — "kucuk buton" hissinin
## olculmus kaynagi.
const DP_PER_PX_A36: float = 0.571
## V3 dokunma kurali: birincil kontroller (CTA, gezinme ogesi, kart) en az
## TOUCH_TARGET = 84 px (A36'da 48 dp; 360 dp telefonda 42 dp). Kart ici kompakt
## eylemler (odul / reklam / fiyat dugmesi) en az TOUCH_COMPACT = 64 px yukseklik
## + komsusuyla en az SPACE_MD bosluk (A36'da 37 dp). Bunun altinda yeni V3
## kontrolu YOK; eski 56 px kose butonlari TASK/060/064'te ele alinir.
const TOUCH_TARGET: int = 84
const TOUCH_COMPACT: int = 64
## V3 CTA boy sınıfları (dudak dahil): kahraman · normal (= TOUCH_TARGET) · kompakt (= TOUCH_COMPACT).
const BUTTON_HEIGHT_HERO: int = 108
const BUTTON_HEIGHT: int = TOUCH_TARGET
const BUTTON_HEIGHT_COMPACT: int = TOUCH_COMPACT
## Eski (M8.6) ↔ V3 eşleşmesi — eski tokenlar onaylı M8.6 ekranlarında AYNEN kalır, yeni / yeniden tasarlanan
## yüzeyler V3 adını kullanır: TOUCH_MIN 48 → TOUCH_TARGET 84 / TOUCH_COMPACT 64 · RADIUS_SMALL / MEDIUM / LARGE
## (12 / 20 / 28; 9-slice dokulu M8.6 bileşenleri) → RADIUS_COMPACT / CONTROL / FEATURE / MODAL (14 / 22 / 30 / 36;
## StyleBoxFlat V3 çizimi) · SHADOW_SOFT / NORMAL / ELEVATED → DEPTH_RESTING / ELEVATED / FLOATING (candy dudağıyla
## birlikte) · HEIGHT_* (Button01 dokusu) → BUTTON_HEIGHT_* · tema yazı boyutları → TYPE_* (UiType.v3).

# --- V3 tipografi olcegi (Turkce okunurluk once; en kucuk yazi 14) ---------
## Rol → boyut. Font ailesi rolun tema variation'indan gelir (UiType.V3_ROLES):
## Baloo 2 = baslik / CTA / rozet, Nunito = govde / veri. Ekran basina keyfi
## boyut YAZILMAZ; V3 bilesenleri yalniz bu olcegi kullanir.
const TYPE_HERO: int = 44
const TYPE_SCREEN_TITLE: int = 30
const TYPE_SECTION: int = 24
const TYPE_CARD_TITLE: int = 23
const TYPE_BODY: int = 19
const TYPE_SECONDARY: int = 16
const TYPE_BUTTON_HERO: int = 36
const TYPE_BUTTON: int = 26
const TYPE_BUTTON_COMPACT: int = 21
const TYPE_BADGE: int = 16
const TYPE_NAV: int = 18
## En kucuk izinli yazi (meta / sayac). V3'te bunun altinda metin yok.
const TYPE_META: int = 14

# --- V3 bosluk olcegi --------------------------------------------------------
## Mevcut SPACE_XS..XL (4/8/12/20/32) korunur; V3 adlari onlara baglanir + iki uc.
const SPACE_MICRO: int = 2
const SPACE_2XL: int = 48

# --- V3 yaricap aileleri ------------------------------------------------------
## Kompakt kontrol (rozet, kucuk cip) · standart buton / kart · buyuk ozellik /
## teklif karti · pencere / gezinme tepsisi. Hepsi StyleBoxFlat ile cizilir.
const RADIUS_COMPACT: int = 14
const RADIUS_CONTROL: int = 22
const RADIUS_FEATURE: int = 30
const RADIUS_MODAL: int = 36

# --- V3 derinlik modeli (candy "dudak") --------------------------------------
## Her V3 yuzeyi ayni recete: yumusak erik golge → koyu taban (dudak) → yuz →
## ust ic isik cizgisi → gloss. Dinlenmede yuz dudagin LIP_REST px ustunde;
## basinca LIP_PRESSED'e iner (gorsel cokme, yalniz opaklik degil); pasif /
## alinmis kontrol duzdur (LIP_FLAT). Golge yalniz bu uc kademeden secilir.
const LIP_REST: float = 7.0
const LIP_PRESSED: float = 2.0
const LIP_FLAT: float = 2.0
const LIP_CARD: float = 6.0
## Golge kademeleri: dinlenen yuzey / yukseltilmis kart / pencere ve tepsi.
const DEPTH_RESTING: Dictionary = {"color": Color(0.10, 0.04, 0.22, 0.28), "size": 6, "offset": Vector2(0, 4)}
const DEPTH_ELEVATED: Dictionary = {"color": Color(0.10, 0.04, 0.22, 0.36), "size": 12, "offset": Vector2(0, 7)}
const DEPTH_FLOATING: Dictionary = {"color": Color(0.05, 0.02, 0.14, 0.50), "size": 20, "offset": Vector2(0, 8)}
## Gloss: yuzun ust bolumu, beyaz alfa.
const GLOSS_ALPHA: float = 0.26
const GLOSS_SHARE: float = 0.38

# --- V3 kenar (border) rolleri -----------------------------------------------
## Kural: kenar HIYERARSI tasimaz (boyut / ikon / derinlik tasir). Yalniz:
## standart yuzey kenari (ince acik halka), secili (kalin beyaz-altin),
## premium (altin), pasif (gri). "Cerceve icinde cerceve" YOK: bir V3 kartin
## icinde ikinci bir kenarli panel acilmaz.
const BORDER_STANDARD: int = 3
const BORDER_SELECTED: int = 4
const BORDER_PREMIUM: int = 4
const BORDER_COLOR_STANDARD: Color = Color(1, 1, 1, 0.55)
const BORDER_COLOR_SELECTED: Color = Color("fff3c4")
const BORDER_COLOR_PREMIUM: Color = Color("ffcf4d")
const BORDER_COLOR_DISABLED: Color = Color(1, 1, 1, 0.25)

# --- V3 renk rolleri (paletten turetilir; ekran kodu ham renk YAZMAZ) --------
## Birincil eylem (OYNA / BASLA): candy cyan.
const ROLE_PRIMARY: Color = CYAN
const ROLE_PRIMARY_DEEP: Color = Color("2a86c6")
## Ikincil eylem: koyu lavanta (HUD v5 / ust satir pill'leriyle ayni aile).
const ROLE_SECONDARY: Color = LAVENDER_DEEP
const ROLE_SECONDARY_DEEP: Color = Color("5b46a8")
## Odul alma (ODULU AL): nane.
const ROLE_REWARD: Color = MINT
const ROLE_REWARD_DEEP: Color = MINT_DEEP
## Odullu reklam (REKLAM IZLE n/2): candy pembe (vurgu ailesi; odul nanesinden ayrik).
const ROLE_AD: Color = PINK
const ROLE_AD_DEEP: Color = PINK_DEEP
## Para birimi / satin alma (fiyat dugmesi): nane yuz + altin Hamur ikonu.
const ROLE_CURRENCY: Color = Color("62d38a")
const ROLE_CURRENCY_DEEP: Color = Color("2b8f50")
## Hamur yetmiyor: dokunulabilir, pasif griden AYRIK — krem yuz + mercan-koyu fiyat (yetmeyen fiyat okunur).
const ROLE_CURRENCY_MUTED: Color = Color("fffcf5")
const ROLE_CURRENCY_MUTED_DEEP: Color = Color("e3d6e6")
const TEXT_INSUFFICIENT: Color = Color("b8394a")
## Premium / teklif: altin.
const ROLE_PREMIUM: Color = GOLD
const ROLE_PREMIUM_DEEP: Color = GOLD_DEEP
## Yikici (nadir): mercan kirmizi.
const ROLE_DANGER: Color = Color("ef5b6b")
const ROLE_DANGER_DEEP: Color = Color("b8394a")
## Yuzeyler: notr krem / yukseltilmis (daha acik) / koyu hub yuzeyi (lavanta).
const SURFACE_NEUTRAL: Color = CREAM
const SURFACE_NEUTRAL_DEEP: Color = Color("e3d6e6")
const SURFACE_ELEVATED: Color = Color("fffcf5")
## Hub yüzeyi (özellik kartı): koyu lavanta — beyaz başlık / alt yazı ≥ 4.5:1 (LAVENDER_DEEP'te 3.8:1 idi).
const SURFACE_HUB: Color = Color("6c55c4")
const SURFACE_HUB_DEEP: Color = Color("43308a")
## Gezinme: tepsi + secili kabarcik.
## Tepsi: beyaz etiket ≥ 4.5:1 (5.0:1).
const NAV_TRAY: Color = Color("7259c9")
const NAV_TRAY_DEEP: Color = Color("3f2d86")
const NAV_SELECTED: Color = CREAM
const NAV_SELECTED_DEEP: Color = Color("d9c7f2")
const NAV_ICON_IDLE: Color = Color("efe6ff")
## Seçili olmayan etiket tam beyaz: tepside 4.7:1 (α .78'de 3.5:1 idi — küçük yazıda yetersiz).
const NAV_LABEL_IDLE: Color = TEXT_ON_DARK
## Tepsinin arkasındaki opak taban (dock) — koyu dünya tonu.
const NAV_DOCK: Color = Color("140f35")
const NAV_ICON_SELECTED: Color = Color("5a3fb0")
## Pasif: mevcut DISABLED / TEXT_DISABLED (4.8:1 olculdu).
const ROLE_DISABLED: Color = DISABLED
const ROLE_DISABLED_DEEP: Color = DISABLED_DEEP
## Dikkat rozeti (kirmizi nokta karsiligi): mercan-kirmizi + beyaz halka.
const ATTENTION: Color = Color("ff4d6a")
const ATTENTION_DEEP: Color = Color("c92a4a")
## Para birimi rengi (Hamur rakami, fiyat): altin; krem ustunde koyu altin.
const CURRENCY: Color = GOLD
const CURRENCY_ON_LIGHT: Color = GOLD_DEEP


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
