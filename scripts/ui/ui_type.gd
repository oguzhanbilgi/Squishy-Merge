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

## Liste bölümü: "GÜÇLER", "SKİNLER", rarity satırı.
const SECTION_TITLE: StringName = &"SectionTitle"

## Kart/satır adı: skin adı, güç adı, ödül rarity'si.
const CARD_TITLE: StringName = &"CardTitle"

## Küçük ama ÖNEMLİ veri: "Stok: ×3", "120 Hamur", "TAKILI".
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
