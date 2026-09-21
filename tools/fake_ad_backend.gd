class_name FakeAdBackend
extends AdBackend
## Deterministik reklam arka ucu TEST ÇİFTİ (M8.9-01). İnternet, cihaz ve
## eklenti YOK: MonetizationManager'ın gördüğü her SDK olayı test tarafından
## elle tetiklenir (`complete_*` / `emit_*`). Production'da bu sınıf YOKTUR
## (`tools/` export dışı); gerçek arka uç `AdmobBackend`.
##
## Kayıt tutar: hangi çağrı kaç kez geldi, hangi ad_id'ler yüklendi/gösterildi,
## banner kaç kez show/hide edildi — böylece "spam yok", "tek talep", "gizle"
## iddiaları ölçülür.

var calls: Array[String] = []
var init_calls: int = 0
var consent_update_calls: int = 0
var consent_form_loads: int = 0
var consent_form_shows: int = 0
var rewarded_loads: int = 0
var rewarded_shows: Array[String] = []
var rewarded_removed: Array[String] = []
var banner_loads: int = 0
var banner_shows: Array[String] = []
var banner_hides: Array[String] = []
var banner_removed: Array[String] = []

## SDK'nın rıza durumu (test ayarlar); `consent_status()` bunu döner.
var status: ConsentStatus = ConsentStatus.UNKNOWN
var form_available: bool = false
## Sabit uyarlanabilir banner yüksekliği (dp) ve yoğunluk (A36: 64 dp × 2.625).
var adaptive_height_dp: int = 64
var density_value: float = 2.625

var _rewarded_seq: int = 0
var _banner_seq: int = 0
## Bekleyen (cevaplanmamış) yükleme kimlikleri — test cevaplar.
var pending_rewarded: Array[String] = []
var pending_banner: Array[String] = []


func backend_name() -> String:
	return "fake"


func _log(name: String) -> void:
	calls.append(name)


# --- AdBackend ------------------------------------------------------------------

func attach(_host: Node) -> void:
	_log("attach")


func initialize() -> void:
	_log("initialize")
	init_calls += 1


func request_consent_update() -> void:
	_log("request_consent_update")
	consent_update_calls += 1


func consent_status() -> ConsentStatus:
	return status


func is_consent_form_available() -> bool:
	return form_available


func load_consent_form() -> void:
	_log("load_consent_form")
	consent_form_loads += 1


func show_consent_form() -> void:
	_log("show_consent_form")
	consent_form_shows += 1


func load_rewarded() -> void:
	_log("load_rewarded")
	rewarded_loads += 1
	_rewarded_seq += 1
	pending_rewarded.append("rewarded_%d" % _rewarded_seq)


func show_rewarded(ad_id: String) -> void:
	_log("show_rewarded:" + ad_id)
	rewarded_shows.append(ad_id)


func remove_rewarded(ad_id: String) -> void:
	_log("remove_rewarded:" + ad_id)
	rewarded_removed.append(ad_id)


func load_banner() -> void:
	_log("load_banner")
	banner_loads += 1
	_banner_seq += 1
	pending_banner.append("banner_%d" % _banner_seq)


func show_banner(ad_id: String) -> void:
	_log("show_banner:" + ad_id)
	banner_shows.append(ad_id)


func hide_banner(ad_id: String) -> void:
	_log("hide_banner:" + ad_id)
	banner_hides.append(ad_id)


func remove_banner(ad_id: String) -> void:
	_log("remove_banner:" + ad_id)
	banner_removed.append(ad_id)


func adaptive_banner_height_dp() -> int:
	return adaptive_height_dp


func density() -> float:
	return density_value


# --- Test sürücüleri (SDK olaylarını taklit eder) --------------------------------

func complete_init() -> void:
	initialization_completed.emit()


## `ok`: güncelleme başarılı (durum `status`'tan okunur). Başarısızsa SDK
## önceki oturumun değerini taşır — testte yine `status`.
func complete_consent_update(ok: bool, code: int = 2, message: String = "network") -> void:
	if ok:
		consent_info_updated.emit()
	else:
		consent_info_update_failed.emit(code, message)


func complete_form_load(ok: bool, code: int = 3, message: String = "form") -> void:
	if ok:
		consent_form_loaded.emit()
	else:
		consent_form_failed_to_load.emit(code, message)


## Form kapandı; `new_status` verilirse SDK durumu ona geçer (oyuncu seçti).
func dismiss_form(new_status: int = -1, code: int = 0, message: String = "") -> void:
	if new_status >= 0:
		status = new_status as ConsentStatus
	consent_form_dismissed.emit(code, message)


## Bekleyen ilk ödüllü yüklemeyi cevaplar; ad_id döner ("" = bekleyen yok).
func complete_rewarded_load(ok: bool, code: int = 3, message: String = "No fill") -> String:
	if pending_rewarded.is_empty():
		return ""
	var ad_id: String = pending_rewarded.pop_front()
	if ok:
		rewarded_loaded.emit(ad_id)
	else:
		rewarded_failed_to_load.emit(ad_id, code, message)
	return ad_id


func emit_rewarded_showed(ad_id: String) -> void:
	rewarded_showed.emit(ad_id)


func emit_rewarded_impression(ad_id: String) -> void:
	rewarded_impression.emit(ad_id)


func emit_rewarded_earned(ad_id: String, reward_type: String = "reward", amount: int = 1) -> void:
	rewarded_earned.emit(ad_id, reward_type, amount)


func emit_rewarded_dismissed(ad_id: String) -> void:
	rewarded_dismissed.emit(ad_id)


func emit_rewarded_show_failed(ad_id: String, code: int = 1, message: String = "show failed") -> void:
	rewarded_failed_to_show.emit(ad_id, code, message)


func complete_banner_load(ok: bool, code: int = 3, message: String = "No fill") -> String:
	if pending_banner.is_empty():
		return ""
	var ad_id: String = pending_banner.pop_front()
	if ok:
		banner_loaded.emit(ad_id, 411, adaptive_height_dp, false)
	else:
		banner_failed_to_load.emit(ad_id, code, message)
	return ad_id


func emit_banner_refreshed(ad_id: String) -> void:
	banner_loaded.emit(ad_id, 411, adaptive_height_dp, true)


func emit_banner_impression(ad_id: String) -> void:
	banner_impression.emit(ad_id)


func emit_banner_clicked(ad_id: String) -> void:
	banner_clicked.emit(ad_id)


func count(call_name: String) -> int:
	var n: int = 0
	for c in calls:
		if c == call_name:
			n += 1
	return n
