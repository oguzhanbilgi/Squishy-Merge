extends CanvasLayer
## Devam etme (revive) teklifi penceresi — GAME_DESIGN.md §11.
##
## GÖRSEL (M8.5-08): owner'ın candy panel + kanatlı kalp tepeliği, CTA'lar
## candy pill butonlar. Refill penceresiyle AYNI tasarım dilinde — ikisi de
## `CandyButton.style_cta` kullanıyor, tepelik ve çerçeve aynı asset.
##
## ⚠️ BU PENCERE REKLAM OYNATMAZ ve DEVAM HAKKI VERMEZ. "DEVAM ET"e basmak
## yalnızca `rewarded_revive_requested` sinyalini yayar. Gerçek rewarded ad
## provider'ı (AdMob) sonraki milestone'da bu sinyale bağlanacak ve devam
## hakkını YALNIZCA ödül kazanıldı callback'i geldiğinde verecek. Sahte reklam
## veya otomatik bedava devam YOKTUR.

## Oyuncu ödüllü reklam CTA'sına bastı. Bu bir TALEP'tir, devam hakkı DEĞİL.
signal rewarded_revive_requested
## Oyuncu "Bitir" dedi: round kesin bitsin. Devam hakkı tüketilmez.
signal decline_pressed

@onready var _title: Label = $Center/Panel/VBox/Title
@onready var _detail: Label = $Center/Panel/VBox/Detail
@onready var _remaining: Label = $Center/Panel/VBox/Remaining
@onready var _continue: Button = $Center/Panel/VBox/Continue
@onready var _note: Label = $Center/Panel/VBox/Note
@onready var _decline: Button = $Center/Panel/VBox/Decline


func _ready() -> void:
	visible = false
	# Candy pill butonlar tema yerine tek tek uygulanıyor — gerekçe:
	# scripts/ui/candy_button.gd başlığı.
	for button: Button in [_continue, _decline]:
		CandyButton.style_cta(button)
	# Birincil CTA iki satirli: eylem Baloo, aciklama Nunito. "Bitir" ikincil
	# ve tek satir — tema yazisiyla birakiliyor.
	CandyButton.set_cta_text(_continue, "DEVAM ET", "Reklam izle")
	_continue.pressed.connect(_on_continue_pressed)
	_decline.pressed.connect(func() -> void: decline_pressed.emit())


## `remaining`: bu round'da KALAN devam hakkı (2 veya 1).
func show_offer(remaining: int, max_revives: int) -> void:
	_title.text = "Devam etmek ister misin?"
	_detail.text = "Taşan parçalar temizlenir, kaldığın yerden devam edersin."
	_remaining.text = "Devam hakkı: %d/%d" % [remaining, max_revives]
	_note.text = ""
	# Talep gönderilip cevap beklenirken buton kapanıyor; yeni bir teklifte
	# yeniden açılmalı.
	_continue.disabled = false
	CandyButton.refresh_cta(_continue)
	visible = true


func hide_offer() -> void:
	visible = false


## Provider talebi reddetti / reklam hazır değil. Teklif AÇIK KALIR: oyuncu
## tekrar deneyebilir ya da "Bitir" diyebilir. Devam hakkı tüketilmez.
func show_unavailable(message: String) -> void:
	_note.text = message
	_continue.disabled = false
	CandyButton.refresh_cta(_continue)


func _on_continue_pressed() -> void:
	# Çift dokunuşa karşı: cevap gelene kadar ikinci talep gitmesin.
	_continue.disabled = true
	CandyButton.refresh_cta(_continue)
	_note.text = "Reklam isteniyor…"
	rewarded_revive_requested.emit()
