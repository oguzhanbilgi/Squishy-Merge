class_name PowerUpController
extends Node
## Güç seçimi/hedefleme DURUM MAKİNESİ (GAME_DESIGN.md §10).
##
## Bu dosya bilerek EFEKTSİZ: hangi gücün silahlandığını, hangi hedeflerin
## geçerli olduğunu ve iptali biliyor — ama hiçbir dumpling'i silmiyor,
## hiçbir parçacık oynatmıyor. Efektleri GameBoard yürütüyor ve başarılı
## olursa `consume()` çağırıyor.
##
## Ayrım kasıtlı: "hangi hedef geçerli" kuralı testle doğrulanabilir kalsın,
## görsel efekte bağlanmasın.

## Silahlanan güç değişti (iptal ve kullanım sonrası ARMED_NONE ile de yayılır).
signal armed_changed(type: int)
## Stok 0 iken güç butonuna basıldı. İLERİDE monetization buraya bağlanacak
## (rewarded ad / Hamur / Power Pack). Şu anda hiçbir şey tüketmiyor,
## hiçbir şey vermiyor — yalnızca olay yayılıyor.
signal refill_requested(type: int)
## Stok değişti; UI kendini tazelesin.
signal stock_changed

## "Hiçbir güç silahlanmadı." enum'da ayrı bir üye açmak yerine -1:
## PowerUp.Type saf kalıyor.
const ARMED_NONE: int = -1

var _armed: int = ARMED_NONE
## Round bittiğinde hiçbir güç silahlanamaz.
var _round_active: bool = true


func armed_type() -> int:
	return _armed


func is_armed() -> bool:
	return _armed != ARMED_NONE


func set_round_active(active: bool) -> void:
	_round_active = active
	if not active:
		cancel()


## Güç butonuna basıldığında çağrılır.
##
## Dönüş: hedefleme moduna girildiyse true. Anında çalışan güçler (Sarsıntı,
## Temizleyici) için HER ZAMAN false döner — onları GameBoard doğrudan
## yürütür; buradan "silahlandı" demek yanlış olurdu.
##
## Stok yoksa refill_requested yayılır ve hiçbir şey silahlanmaz.
func request(type: PowerUp.Type) -> bool:
	if not _round_active:
		return false
	if not SaveManager.has_powerup(type):
		refill_requested.emit(int(type))
		return false
	# Aynı güce tekrar basmak = iptal (toggle).
	if _armed == int(type):
		cancel()
		return false
	# Başka bir güç silahlıysa önce o temizlenir — ikisi aynı anda aktif olamaz.
	if not PowerUp.is_targeted(type):
		cancel()
		return false
	_armed = int(type)
	armed_changed.emit(_armed)
	return true


func cancel() -> void:
	if _armed == ARMED_NONE:
		return
	_armed = ARMED_NONE
	armed_changed.emit(_armed)


## Efekt gerçekten gerçekleştiğinde çağrılır: stok burada düşer.
##
## Çift input koruması: silahlı güç zaten temizlenmişse (ilk dokunuş işlendi)
## ikinci dokunuş buraya hiç gelmez, çünkü GameBoard `is_armed()` kontrolüyle
## eleniyor. Ayrıca SaveManager.consume_powerup stok yetmezse false dönüyor.
func consume(type: PowerUp.Type) -> bool:
	var ok: bool = SaveManager.consume_powerup(type)
	if ok:
		stock_changed.emit()
	return ok


# --- Hedef geçerliliği ---
#
# Ortak koşullar: parça canlı, board'da ve merge işleminde değil.

static func _is_live(dumpling: Dumpling) -> bool:
	return (dumpling != null and is_instance_valid(dumpling)
		and not dumpling.is_queued_for_deletion() and not dumpling.is_merging)


## Silahlı güce göre bu dumpling geçerli bir hedef mi?
func is_valid_target(dumpling: Dumpling) -> bool:
	if not is_armed() or not _is_live(dumpling):
		return false
	match _armed:
		int(PowerUp.Type.BOMB):
			return true
		int(PowerUp.Type.UPGRADE):
			# Tier 8 daha fazla büyütülemez.
			return dumpling.tier < TierConfig.MAX_TIER
	return false


## Temizleyicinin kaldıracağı parçalar. Boş dönerse güç TÜKETİLMEZ.
static func clearable(dumplings: Array) -> Array[Dumpling]:
	var result: Array[Dumpling] = []
	for node in dumplings:
		var dumpling := node as Dumpling
		if _is_live(dumpling) and dumpling.tier <= PowerUp.CLEAR_SMALL_MAX_TIER:
			result.append(dumpling)
	return result


## Sarsıntının impulse uygulayacağı parçalar.
static func shakeable(dumplings: Array) -> Array[Dumpling]:
	var result: Array[Dumpling] = []
	for node in dumplings:
		var dumpling := node as Dumpling
		if _is_live(dumpling):
			result.append(dumpling)
	return result
