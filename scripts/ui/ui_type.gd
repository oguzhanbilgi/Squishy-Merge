class_name UiType
extends RefCounted
## Tipografi rollerinin TEK tanım noktası (M8.5-09).
##
## İki font ailesi var ve ikisinin işi ayrı:
##
##   Baloo 2   — DISPLAY/BAŞLIK. Yuvarlak, tombul, candy asset'lerle aynı dili
##               konuşuyor. Karakteri var ama uzun metinde yoruyor.
##   Nunito    — UI/VERİ. Sakin, dar, rakamları net. Skor, stok, fiyat, kota
##               ve açıklamalar burada.
##
## Kural: **başlık ve CTA Baloo, geri kalan her şey Nunito.** "Her şey Baloo
## olsun" bilinçli olarak YAPILMADI — küçük gridlerde (level numarası +
## yıldız, koleksiyon kartı) Baloo'nun tombulluğu okunabilirliği düşürüyor.
##
## Boyutlar ve fontlar `assets/visual/ui_theme.tres` içindeki type
## variation'larda duruyor; tema `project.godot` → `gui/theme/custom` ile
## PROJE GENELİNDE varsayılan. Buradaki sabitler o variation'ların
## isimleri — sahnede `theme_type_variation`, kodda `UiType.apply()`.
##
## Neden ayrı bir dosya: mağaza, koleksiyon ve güç çubuğu etiketlerini KOD
## üretiyor; onlar sahne inspector'ından rol seçemiyor. Rol adı string olarak
## dağılırsa bir yerde yazım hatası sessizce varsayılan gövde metnine düşer.
##
## Yeni boyut eklemeden önce: gerçekten yeni bir ROL mü, yoksa mevcut bir
## rolün yerini mi kullanmalı? Rol sayısı arttıkça hiyerarşi okunmaz olur.

## Pencere kahramanı. "Devam etmek ister misin?", "Bomba bitti",
## "Level 3 tamam!". Ekranda aynı anda BİR tane olmalı.
const DISPLAY: StringName = &"Display"

## Sekme ekranının kendi başlığı: "Koleksiyon", "Mağaza".
const SCREEN_TITLE: StringName = &"ScreenTitle"

## Liste bölümü: "GÜÇLER", "KOLEKSİYON", rarity satırı.
const SECTION_TITLE: StringName = &"SectionTitle"

## Kart/satır adı: skin adı, güç adı, ödül rarity'si.
const CARD_TITLE: StringName = &"CardTitle"

## Küçük ama ÖNEMLİ veri: "Stok: ×3", "120 Hamur", "VİTRİNDE".
## Gövde metninden küçük olabilir ama Bold olduğu için daha güçlü okunur.
const STAT: StringName = &"Stat"

## İkincil açıklama: kota satırı, "Tüketilir." notu, rarity etiketi.
const CAPTION: StringName = &"Caption"

## Oyun HUD'unun birincil satırı: Level + Hedef.
const HUD_PRIMARY: StringName = &"HudPrimary"

## Oyun HUD'unun ikincil satırları: Skor, Sıradaki.
const HUD_SECONDARY: StringName = &"HudSecondary"

## Level + Hedef satırı — satır içi ikonlu olduğu için RichTextLabel.
const HUD_OBJECTIVE: StringName = &"HudObjective"

## Birincil olmayan buton: "Kapat", "Vazgeç", "Bitir".
const SECONDARY_BUTTON: StringName = &"SecondaryButton"

## Alt sekme çubuğu butonu.
const TAB_BUTTON: StringName = &"TabButton"


## Rolü uygular ve kontrolü geri döner — kodla kurulan etiketlerde
## `column.add_child(UiType.apply(label, UiType.CARD_TITLE))` yazılabilsin.
static func apply(control: Control, role: StringName) -> Control:
	control.theme_type_variation = role
	return control


# --- Squishy UI System V3 (TASK/057) -------------------------------------------
#
# V3 tipografi hiyerarşisi: dokuz rol, boyutlar `UiTokens.TYPE_*`. Font ailesi ve
# rengi mevcut tema variation'ından (krem yüzey / koyu yüzey), boyut tokendan —
# tema YENİDEN ÜRETİLMEDİ, yeni font yok. Her V3 bileşeni metnini yalnız
# `UiType.v3()` / `UiType.v3_label()` ile kurar; böylece "ekran başına keyfi
# boyut" ve sessiz varsayılan-font düşüşü olamaz (ui_system_v3_test tarar).

const V3_HERO: StringName = &"hero"
const V3_SCREEN_TITLE: StringName = &"screen_title"
const V3_SECTION: StringName = &"section"
const V3_CARD_TITLE: StringName = &"card_title"
const V3_BODY: StringName = &"body"
const V3_SECONDARY: StringName = &"secondary"
const V3_BUTTON: StringName = &"button"
const V3_BADGE: StringName = &"badge"
const V3_META: StringName = &"meta"
const V3_NAV: StringName = &"nav"

## rol → [krem yüzey variation'ı, koyu yüzey variation'ı, boyut].
const V3_ROLES: Dictionary = {
	&"hero": [&"LabelDisplay", &"LabelDisplayOnDark", UiTokens.TYPE_HERO],
	&"screen_title": [&"LabelTitle", &"LabelTitleOnDark", UiTokens.TYPE_SCREEN_TITLE],
	&"section": [&"LabelSection", &"LabelSectionOnDark", UiTokens.TYPE_SECTION],
	&"card_title": [&"LabelSection", &"LabelSectionOnDark", UiTokens.TYPE_CARD_TITLE],
	&"body": [&"LabelBody", &"LabelBodyOnDark", UiTokens.TYPE_BODY],
	&"secondary": [&"LabelCaption", &"LabelCaptionOnDark", UiTokens.TYPE_SECONDARY],
	&"button": [&"LabelTitle", &"LabelTitleOnDark", UiTokens.TYPE_BUTTON],
	&"badge": [&"LabelBadge", &"LabelBadgeOnDark", UiTokens.TYPE_BADGE],
	&"meta": [&"LabelHudCaptionDark", &"LabelHudCaption", UiTokens.TYPE_META],
	&"nav": [&"LabelBadgeOnDark", &"LabelBadgeOnDark", UiTokens.TYPE_NAV],
}


## V3 rolünü uygular: variation (font ailesi + renk + gölge) + token boyutu.
## `size` > 0 yalnız bileşen içi sınırlı sığdırma için (ör. buton boy sınıfı);
## yine de TYPE_META'nın altına inilmez.
static func v3(label: Label, role: StringName, on_dark: bool = false, size: int = 0) -> Label:
	var spec: Array = V3_ROLES.get(role, V3_ROLES[V3_BODY])
	label.theme_type_variation = spec[1] if on_dark else spec[0]
	var px: int = size if size > 0 else int(spec[2])
	label.add_theme_font_size_override("font_size", maxi(px, UiTokens.TYPE_META))
	label.set_meta(&"v3_role", role)
	return label


## Yeni V3 etiketi (fare almaz).
static func v3_label(text: String, role: StringName, on_dark: bool = false,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, size: int = 0) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v3(label, role, on_dark, size)


## Türkçe büyük harf: Godot `to_upper` i → I yapar (İ olmalı) ve ı'yı bilmez.
static func upper_tr(text: String) -> String:
	return text.replace("i", "İ").replace("ı", "I").to_upper()
