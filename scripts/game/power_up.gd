class_name PowerUp
extends RefCounted
## Dört tüketilebilir gücün TEK tanım noktası (GAME_DESIGN.md §10).
##
## Tip için proje genelinde dağınık string kullanılmıyor: enum burada,
## kayıt anahtarı/isim/davranış eşlemeleri de burada. Yeni bir güç eklemek
## için tek dokunulacak yer bu dosya + efektin kendisi.

enum Type {
	BOMB,         ## Seçilen tek dumpling'i yok eder.
	UPGRADE,      ## Seçilen dumpling'i bir üst tier'a çıkarır.
	SHAKE,        ## Board'a kontrollü impulse uygular, parçalar karışır.
	CLEAR_SMALL,  ## Tüm tier 1 ve 2 parçaları kaldırır.
}

## Kayıt dosyasındaki anahtar. DEĞİŞTİRİLMEMELİ — eski kayıtlar bunu okuyor.
const SAVE_KEYS: Dictionary = {
	Type.BOMB: "bomb",
	Type.UPGRADE: "upgrade",
	Type.SHAKE: "shake",
	Type.CLEAR_SMALL: "clear_small",
}

const DISPLAY_NAMES: Dictionary = {
	Type.BOMB: "Bomba",
	Type.UPGRADE: "Büyütücü",
	Type.SHAKE: "Sarsıntı",
	Type.CLEAR_SMALL: "Temizleyici",
}

## Eski metin işaretleri. ARTIK HİÇBİR YERDE KULLANILMIYOR ve yeni bir
## çağıran EKLENMEMELİ.
##
## M8.5-08 bunları güç çubuğundan kaldırdı ama mağaza kartı gözden kaçmıştı;
## M8.5-09 orayı da gerçek ikona çevirdi. Dördü de artık bilinçli olarak
## "son çare" DEĞİL: hiçbiri Baloo 2 / Nunito cmap'inde yok (U+2738, U+25B2,
## U+2248, U+232B — dört font dosyasının cmap'i okundu), yani bu işaretlere
## düşmek boş kutu ya da bambaşka bir yazı tipi demek olurdu.
##
## `icon()` null dönerse doğru davranış boş bir TextureRect bırakmaktır,
## metne düşmek değil.
const GLYPHS: Dictionary = {
	Type.BOMB: "✸",
	Type.UPGRADE: "▲",
	Type.SHAKE: "≈",
	Type.CLEAR_SMALL: "⌫",
}

## Güç ikonlarının dosya yolları (M8.5-08'de DOLDURULDU).
##
## Dördü de owner'ın ChatGPT asset'lerinden türetildi (`_visual_source/
## chatgpt_ui/`). Bomba / Büyütücü / Temizleyici tekil kaynak dosyalardan;
## Sarsıntı yalnızca 3'lü sheet içinde olduğu için sheet'in ölçülmüş boş
## sütun aralığından (x 1408-2030) temiz kesildi. Sheet'lerin kendisi
## runtime'da KULLANILMIYOR, yalnız `_visual_source` arşivinde duruyor.
##
## Hepsi 256x256, saydam zeminli, trim edilip kareye ortalanmış.
const ICON_PATHS: Dictionary = {
	Type.BOMB: "res://assets/visual/ui/power_bomb.png",
	Type.UPGRADE: "res://assets/visual/ui/power_upgrade.png",
	Type.SHAKE: "res://assets/visual/ui/power_shake.png",
	Type.CLEAR_SMALL: "res://assets/visual/ui/power_clear.png",
}


## Güç başına vurgu rengi. Dört gücün tek bakışta ayırt edilmesi için;
## seçili çerçevesinde ve stok yazısında kullanılıyor. Renkler candy
## paletinden, birbirinden uzak hue'larda seçildi.
const ACCENTS: Dictionary = {
	Type.BOMB: Color("ff8fa8"),        # pembe
	Type.UPGRADE: Color("ffd166"),     # altın
	Type.SHAKE: Color("7fd4ff"),       # camgöbeği
	Type.CLEAR_SMALL: Color("b6f2a8"), # yeşil
}


## Kayıt başına bir kez verilen başlangıç stoğu (GAME_DESIGN.md §10).
const STARTER_COUNT: int = 1

## Temizleyicinin kaldırdığı en yüksek tier.
const CLEAR_SMALL_MAX_TIER: int = 2


## Gücün ikonu, ya da tanımlı/yüklenebilir değilse null.
## null dönmesi bir hata durumudur; çağıran taraf metne DÜŞMEZ (bkz. GLYPHS).
static func icon(type: Type) -> Texture2D:
	var path: String = String(ICON_PATHS.get(type, ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


## Bu güç için gerçek ikon var mı?
static func has_icon(type: Type) -> bool:
	return icon(type) != null


static func accent(type: Type) -> Color:
	return ACCENTS[type]


static func all() -> Array[Type]:
	return [Type.BOMB, Type.UPGRADE, Type.SHAKE, Type.CLEAR_SMALL]


## Enum aralığı dışındaki bir int'i güç sanmayı engeller. Satın alma yolu
## dışarıdan int alıyor (UI sinyalleri int taşıyor), o yüzden gerekli.
static func is_valid_type(type: int) -> bool:
	return SAVE_KEYS.has(type)


static func save_key(type: Type) -> String:
	return SAVE_KEYS[type]


static func display_name(type: Type) -> String:
	return DISPLAY_NAMES[type]


static func glyph(type: Type) -> String:
	return GLYPHS[type]


## Bu güç bir dumpling seçmeyi gerektiriyor mu? Bomba ve Büyütücü ortak
## targeting akışını kullanıyor; Sarsıntı ve Temizleyici anında çalışıyor.
static func is_targeted(type: Type) -> bool:
	return type == Type.BOMB or type == Type.UPGRADE
