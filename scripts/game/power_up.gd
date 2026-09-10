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

## Geçici placeholder işaretler. Final power-up art'ı YOK (M8.5-03).
const GLYPHS: Dictionary = {
	Type.BOMB: "✸",
	Type.UPGRADE: "▲",
	Type.SHAKE: "≈",
	Type.CLEAR_SMALL: "⌫",
}

## Kayıt başına bir kez verilen başlangıç stoğu (GAME_DESIGN.md §10).
const STARTER_COUNT: int = 1

## Temizleyicinin kaldırdığı en yüksek tier.
const CLEAR_SMALL_MAX_TIER: int = 2


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
