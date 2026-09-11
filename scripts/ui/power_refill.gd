extends CanvasLayer
## Stok 0 güç refill penceresi — GAME_DESIGN.md §5.7.3.
##
## GÖRSEL (M8.5-08): pencere artık owner'ın candy panel + kanatlı kalp
## tepeliğini, CTA'lar candy pill butonları, başlıktaki işaret ise gücün
## GERÇEK ikonunu kullanıyor. Geçici metin işareti (`PowerUp.GLYPHS`)
## kaldırıldı. Devam (revive) penceresiyle aynı tasarım dilinde.
##
## ⚠️ BU PENCERE REKLAM OYNATMAZ ve STOK VERMEZ. "REKLAM İZLE"ye basmak
## yalnızca `rewarded_refill_requested(type)` yayar; gerçek rewarded ad
## provider'ı sonraki milestone'da bu sinyale bağlanacak ve stoğu YALNIZCA
## ödül kazanıldı callback'i geldiğinde verecek. Sahte reklam yok.
##
## Hamur yolu ise GERÇEKTEN çalışıyor: `dough_refill_requested(type)` →
## `PowerUpEconomy.purchase()`. Fiyat burada hardcode DEĞİL.
##
## Gelecekte üçüncü CTA (gerçek para Güç Paketi) buraya eklenecek; seam
## `power_pack_requested` sinyali olarak şimdiden duruyor ama HİÇBİR YERE
## BAĞLI DEĞİL ve buton gösterilmiyor (çalışmayan sahte satın alma butonu
## göstermek yanlış olurdu).

## Oyuncu ödüllü reklam CTA'sına bastı. Bu bir TALEP'tir, stok DEĞİL.
signal rewarded_refill_requested(type: int)
## Oyuncu Hamurla almayı seçti.
signal dough_refill_requested(type: int)
## ⚠️ KULLANILMIYOR — Google Play Billing kurulunca bağlanacak seam.
signal power_pack_requested(type: int)
signal closed

## Kota satırının rengi — candy panelin krem zemininde okunacak tonlar.
const QUOTA_COLOR: Color = Color(0.54, 0.32, 0.19)
const QUOTA_EMPTY_COLOR: Color = Color(0.78, 0.22, 0.28)

var _type: int = -1

@onready var _icon: TextureRect = $Center/Panel/VBox/Icon
@onready var _title: Label = $Center/Panel/VBox/Title
@onready var _detail: Label = $Center/Panel/VBox/Detail
@onready var _ad: Button = $Center/Panel/VBox/Ad
@onready var _quota: Label = $Center/Panel/VBox/Quota
@onready var _dough: Button = $Center/Panel/VBox/Dough
@onready var _note: Label = $Center/Panel/VBox/Note
@onready var _close: Button = $Center/Panel/VBox/Close


func _ready() -> void:
	visible = false
	# Candy pill butonlar tema yerine tek tek uygulanıyor — gerekçe:
	# scripts/ui/candy_button.gd başlığı.
	for button: Button in [_ad, _dough, _close]:
		CandyButton.style_cta(button)
	_ad.pressed.connect(_on_ad_pressed)
	_dough.pressed.connect(_on_dough_pressed)
	_close.pressed.connect(_on_close_pressed)


func current_type() -> int:
	return _type


## `provider_ready`: rewarded sağlayıcısı bağlı mı. Bu turda daima false —
## AdMob kurulmadı.
func show_refill(type: PowerUp.Type, provider_ready: bool) -> void:
	_type = int(type)
	_icon.texture = PowerUp.icon(type)
	_title.text = "%s bitti" % PowerUp.display_name(type)
	_detail.text = "Stok: ×%d" % SaveManager.powerup_count(type)
	# Iki satirli CTA: ust satir eylem (Baloo), alt satir odul/bedel (Nunito).
	CandyButton.set_cta_text(_ad, "REKLAM İZLE",
		"+1 %s" % PowerUp.display_name(type))
	CandyButton.set_cta_text(_dough, "HAMURLA AL",
		"%d Hamur" % PowerUpEconomy.price(type))
	_note.text = ""
	visible = true
	refresh(provider_ready)


## Butonların açık/kapalı durumunu ve kota satırını tazeler. Satın alma
## sonrası ve kota değişince tekrar çağrılıyor.
func refresh(provider_ready: bool) -> void:
	if _type < 0:
		return
	var type: PowerUp.Type = _type as PowerUp.Type
	_detail.text = "Stok: ×%d" % SaveManager.powerup_count(type)

	var quota_left: int = RewardedPolicy.remaining_today()
	_quota.text = "Bugünkü reklam hakkı: %d/%d" % [
		quota_left, RewardedPolicy.daily_cap()]
	# Kota dolduysa VEYA sağlayıcı yoksa CTA basılamaz — basılıp reddedilmek
	# kötü his, ve iki sebep ayrı ayrı yazıyla açıklanıyor.
	_ad.disabled = quota_left <= 0 or not provider_ready
	# Renk doğrudan yazıya veriliyor: `modulate` koyu erik yazının üstünde
	# bulanık bir ton bırakıyordu (candy panel krem zeminli).
	_quota.add_theme_color_override("font_color",
		QUOTA_EMPTY_COLOR if quota_left <= 0 else QUOTA_COLOR)

	_dough.disabled = not PowerUpEconomy.can_afford(type)
	# Pasiflik yazi rengini otomatik degistirmiyor (overlay Label'lar):
	# iki CTA'nin kontrasti burada elle tazeleniyor.
	CandyButton.refresh_cta(_ad)
	CandyButton.refresh_cta(_dough)

	if _ad.disabled and _dough.disabled:
		_note.text = _unavailable_reason(quota_left, provider_ready) \
			+ "  Hamur da yetmiyor."
	elif _ad.disabled:
		_note.text = _unavailable_reason(quota_left, provider_ready)
	elif _dough.disabled:
		_note.text = "Hamur yetmiyor (%d Hamur'un var)." % SaveManager.dough()
	else:
		_note.text = ""


func _unavailable_reason(quota_left: int, provider_ready: bool) -> String:
	if quota_left <= 0:
		return "Bugünkü reklam hakkın doldu, yarın yenilenir."
	if not provider_ready:
		return "Ödüllü reklam henüz bağlı değil."
	return ""


## Sağlayıcı talebi reddetti / reklam hazır değil / ödül kazanılmadı.
## Pencere AÇIK KALIR, kota tüketilmez.
func show_unavailable(message: String, provider_ready: bool) -> void:
	refresh(provider_ready)
	_note.text = message


func hide_refill() -> void:
	_type = -1
	visible = false


func _on_ad_pressed() -> void:
	if _type < 0:
		return
	# Çift dokunuşa karşı: cevap gelene kadar ikinci talep gitmesin.
	_ad.disabled = true
	CandyButton.refresh_cta(_ad)
	_note.text = "Reklam isteniyor…"
	rewarded_refill_requested.emit(_type)


func _on_dough_pressed() -> void:
	if _type < 0:
		return
	dough_refill_requested.emit(_type)


func _on_close_pressed() -> void:
	closed.emit()
