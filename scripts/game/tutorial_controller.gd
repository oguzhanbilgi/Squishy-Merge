class_name TutorialController
extends Node
## İlk açılış tutorial'ının durum makinesi (M8.10 — docs/TUTORIAL_SYSTEM.md).
##
## SORUMLULUK DAĞILIMI (§3):
##   GameBoard          : GERÇEK fizik, merge, ses/titreşim, geometri. Ürün
##                        onboarding'ini bilmez; yalnız pasif dikişler sunar
##                        (kuyruk, girdi kilidi, tutorial pause, bırakma yardımı).
##   TutorialOverlay    : coach-mark sunumu. Adım bilmez, kalıcılık yazmaz.
##   Onboarding/SaveManager : tamamlanmanın TEK kalıcı yolu.
##   TutorialController : aradaki her şey — adım sırası, girdi kapıları,
##                        deterministik ilk iki drop, gerçek merge beklemesi.
##
## SAHTE FİZİK YOK (§5): merge'i biz üretmiyoruz. İki T1 gerçekten bırakılıyor,
## gerçek `_resolve_merge` T2'yi doğuruyor ve adım ancak `GameState.
## merge_performed` geldiğinde ilerliyor. Skor, sayaç, ses ve titreşim
## production yolundan geçiyor; tutorial'ın ürettiği T2 board'da KALIYOR.
##
## ÇÖKME/YENİDEN BAŞLATMA (§25): adım adım kalıcılık YOK. Tamamlanmadan
## kapatılırsa `onboarding_completed` false kalır ve tutorial bir sonraki
## açılışta baştan başlar — yarım kalmış fizik durumu diske yazmaktan daha
## sağlam bir davranış.

## Tutorial bitti (tamamlandı ya da atlandı). `source`: Onboarding.SOURCE_*.
signal completed(source: String)
## Adım değişti (harness/çekim kancası).
signal step_changed(step: int)

enum Step {
	INACTIVE,
	WELCOME,
	FIRST_DROP,
	MATCH_DROP,
	MERGE_SUCCESS,
	GOAL,
	DANGER,
	POWERS,
	READY,
	COMPLETE,
}

## Adım adı (olay bağlamı ve harness çıktısı).
const STEP_NAMES: Dictionary = {
	Step.INACTIVE: "inactive", Step.WELCOME: "welcome", Step.FIRST_DROP: "first_drop",
	Step.MATCH_DROP: "match_drop", Step.MERGE_SUCCESS: "merge_success", Step.GOAL: "goal",
	Step.DANGER: "danger", Step.POWERS: "powers", Step.READY: "ready",
	Step.COMPLETE: "complete",
}

## Öğretim kuyruğu: iki T1 (§6). Normal DropBag'e DOKUNULMAZ.
const DROP_QUEUE: Array[int] = [1, 1]
## Rehberli merge'in ürünü: T1 + T1 -> T2. Adım yalnız bununla ilerler.
const MERGE_RESULT_TIER: int = 2
## İlk drop kabın ortasında bu yarı genişlikte tutulur (duvara yapışıp
## sekmesin). Kap genişliğinin oranı olarak hesaplanır.
const FIRST_DROP_CLAMP_RATIO: float = 0.24
## --- "İlk parça oturdu" niteliği (M8.10) ---
##
## Bu KURAL TUTORIAL'A AİTTİR: yalnız `TutorialController`'ın ilk rehberli
## T1'i GÖZLEMLEME biçimini tarif eder. `GameBoard` ve `Dumpling` üretim
## davranışı (drop cooldown, fizik, merge, taşma, nişan) DEĞİŞMEDİ.
##
## Üç şartın ÜÇÜ birden gerekir:
##   1. gözlem penceresi  — parça en az `SETTLE_MIN` sn yaşamış olmalı.
##      Doğduğu KARE'de `linear_velocity` SIFIRDIR (fizik henüz işlemedi);
##      tek başına hıza bakmak "anında oturdu" der ve adım hemen atlanır.
##   2. kaba girmiş olmalı — merkezi taşma çizgisinin ALTINDA (gerçekten
##      oyun alanına inmiş, hâlâ düşme bölgesinde değil).
##   3. durmuş olmalı     — hız `SETTLE_SPEED`'in altında.
## Hiçbiri tutmazsa `SETTLE_TIMEOUT` sonunda yine de devam edilir (oyuncu
## beklemede kalmaz); o durumda da adım gerçek bir parçayı hedefler.
const SETTLE_SPEED: float = 34.0
const SETTLE_MIN: float = 0.45
const SETTLE_TIMEOUT: float = 2.4
## Gerçek merge için tanınan süre; dolarsa adım güvenli biçimde yeniden
## kurulur (oyuncu ASLA takılı kalmaz, §33).
const MERGE_TIMEOUT: float = 3.0
## "Harika!" kutlaması kısa: birkaç saniye bloke etmiyoruz (§8 D).
const MERGE_SUCCESS_HOLD: float = 1.25
## MATCH_DROP hedef halkasının parçanın dışına taşan payı.
const PIECE_PAD: float = 16.0

## Testler zamanlayıcıları hızlandırır (1.0 = gerçek süre).
static var time_scale: float = 1.0

var _board: Node2D = null
var _overlay: TutorialOverlay = null
var _step: Step = Step.INACTIVE
## Geri onayı açıkken saklanan adım (DEVAM ET ile aynen geri dönülür).
var _back_step: Step = Step.INACTIVE
var _back_open: bool = false
var _started_msec: int = 0
var _timer: SceneTreeTimer = null
## `completed` bir kez yayılır; çift dokunuş/çift callback ikinci kez bitiremez.
var _finished: bool = false
## MATCH_DROP'ta hedeflenen ilk T1.
var _match_target: Dumpling = null
## Tamamlanma olayının bağlamı (son adım + süre); Main `Onboarding.complete`
## çağrısında iletir.
var _completion_context: Dictionary = {}


## Son bitirmenin bağlamı (adım, elapsed_ms) — Main olaya ekler.
func completion_context() -> Dictionary:
	return _completion_context.duplicate()


func setup(overlay: TutorialOverlay) -> void:
	_overlay = overlay
	_overlay.cta_pressed.connect(_on_cta)
	_overlay.skip_pressed.connect(_on_skip)


func current_step() -> Step:
	return _step


func step_name() -> String:
	return String(STEP_NAMES.get(_step, "?"))


func is_active() -> bool:
	return _step != Step.INACTIVE and _step != Step.COMPLETE


## Geri onayı açık mı (Android geri, §12).
func is_back_prompt_open() -> bool:
	return _back_open


# --- Akış -----------------------------------------------------------------------

## Tutorial'ı başlatır. `board` ZATEN kurulmuş gerçek Level 1 board'u
## (`setup_tutorial_queue(DROP_QUEUE)` ile yaratılmış olmalı).
func begin(board: Node2D) -> void:
	if is_active() or board == null or not is_instance_valid(board):
		return
	_board = board
	_finished = false
	_started_msec = Time.get_ticks_msec()
	_board.dumpling_dropped.connect(_on_dumpling_dropped)
	GameState.merge_performed.connect(_on_merge_performed)
	TutorialEvents.emit(&"tutorial_started", {"source": "fresh_install"})
	_enter(Step.WELCOME)


func _exit_tree() -> void:
	_disconnect_board()
	_cancel_timer()


func _disconnect_board() -> void:
	if _board != null and is_instance_valid(_board) \
			and _board.dumpling_dropped.is_connected(_on_dumpling_dropped):
		_board.dumpling_dropped.disconnect(_on_dumpling_dropped)
	if GameState.merge_performed.is_connected(_on_merge_performed):
		GameState.merge_performed.disconnect(_on_merge_performed)


func _enter(step: Step) -> void:
	if _board == null or not is_instance_valid(_board):
		return
	_cancel_timer()
	_step = step
	TutorialEvents.emit(&"tutorial_step", {"step": step_name(),
		"elapsed_ms": _elapsed_ms(), "source": "fresh_install"})
	step_changed.emit(int(step))
	match step:
		Step.WELCOME:
			_gate(true, true)
			_board.clear_tutorial_drop_assist()
			_show({"title": "Hoş geldin!", "body": "Hamurları birleştirip büyüt.",
				"cta": "BAŞLA", "mascot": true})
		Step.FIRST_DROP:
			_gate(false, false)
			_board.set_tutorial_drop_clamp(_board.level.container_width * FIRST_DROP_CLAMP_RATIO)
			_show({"body": "Parmağını sağa–sola sürükle, sonra bırak.",
				"dim": false, "pointer": true})
		Step.MATCH_DROP:
			_gate(false, false)
			var target: Rect2 = _piece_rect(_match_target)
			if _match_target != null and is_instance_valid(_match_target):
				_board.set_tutorial_drop_snap(_match_target.position.x)
			_show({"body": "Aynı hamurları buluştur!", "dim": false,
				"target": target, "guide_x": _board.tutorial_guide_screen_x()})
		Step.MERGE_SUCCESS:
			_gate(true, true)
			_board.clear_tutorial_drop_assist()
			_show({"title": "Harika!", "body": "Aynılar birleşip büyür."})
			_start_timer(MERGE_SUCCESS_HOLD, func() -> void: _enter(Step.GOAL))
		Step.GOAL:
			_gate(true, true)
			_show({"title": "Hedefin burada.",
				"body": "Birleştirerek gerekli büyüklüğe ulaş.", "cta": "DEVAM",
				"target": _board.tutorial_goal_rect()})
		Step.DANGER:
			_gate(true, true)
			_show({"body": "Parçaların bu çizginin üstünde kalmasına izin verme!",
				"cta": "DEVAM", "target": _board.tutorial_danger_rect()})
		Step.POWERS:
			_gate(true, true)
			_show({"title": "Zorlanırsan güçler burada.", "body": "Şimdilik sakla.",
				"cta": "DEVAM", "target": _board.tutorial_powers_rect()})
		Step.READY:
			_gate(true, true)
			_show({"title": "Hazırsın!", "body": "Şimdi Level 1'i tamamla.",
				"cta": "DEVAM", "mascot": true, "skip": false})


## Coach yüzeyini kurar. Her adım, kartın ve ATLA kontrolünün girebileceği
## GÜVENLİ BANDI da verir (HUD'un altı ↔ şeridin üstü): kart hiçbir HUD
## kontrolünü, evrim şeridini ya da banner yuvasını örtmez.
func _show(spec: Dictionary) -> void:
	var full: Dictionary = spec.duplicate()
	if _board != null and is_instance_valid(_board):
		full["bounds"] = _board.tutorial_safe_band()
	_overlay.show_step(full)


## Adım girdi/dondurma kapısı (§10). `locked`: board girdisi kapalı.
## `paused`: board donuk (parçalar coach kartının altında sürüklenmesin).
func _gate(locked: bool, paused: bool) -> void:
	if _board == null or not is_instance_valid(_board):
		return
	_board.set_tutorial_input_locked(locked)
	_board.set_tutorial_paused(paused)


# --- Oyuncu etkileşimi ------------------------------------------------------------

func _on_cta() -> void:
	if _back_open:
		# Geri onayındaki DEVAM ET: kaldığın adıma dön.
		_back_open = false
		_enter(_back_step)
		return
	match _step:
		Step.WELCOME:
			_enter(Step.FIRST_DROP)
		Step.GOAL:
			_enter(Step.DANGER)
		Step.DANGER:
			_enter(Step.POWERS)
		Step.POWERS:
			_enter(Step.READY)
		Step.READY:
			_finish(Onboarding.SOURCE_TUTORIAL)
		_:
			pass


func _on_skip() -> void:
	_finish(Onboarding.SOURCE_SKIP)


## Test/harness kancası: açık CTA'ya basılmış gibi ilerletir.
func advance() -> void:
	_on_cta()


## Test/harness kancası: ATLA.
func skip() -> void:
	_on_skip()


## Android geri (§12): kabuğa GİTMEZ, küçük bir onay gösterir. Tekrar geri
## basılırsa onay kapanır ve adım sürer. Dönüş: olay tüketildi mi.
func handle_back() -> bool:
	if not is_active():
		return false
	if _back_open:
		_back_open = false
		_enter(_back_step)
		return true
	_back_open = true
	_back_step = _step
	_cancel_timer()
	_gate(true, true)
	_show({"title": "Eğitimi bırakmak mı istiyorsun?",
		"body": "İstersen kaldığın yerden devam edebilirsin.",
		"cta": "DEVAM ET", "cta_alt": "ATLA", "skip": false})
	return true


# --- Board olayları ---------------------------------------------------------------

func _on_dumpling_dropped(_tier: int) -> void:
	match _step:
		Step.FIRST_DROP:
			TutorialEvents.emit(&"tutorial_first_drop", {"elapsed_ms": _elapsed_ms()})
			# İkinci drop'a kadar girdi kapalı: parça otursun, hedef belli olsun.
			_board.set_tutorial_input_locked(true)
			_show({"dim": false})
			_await_settle()
		Step.MATCH_DROP:
			# Merge garanti ama üçüncü bir parça düşmesin: girdi kapanır ve
			# GERÇEK merge beklenir. Gelmezse adım yeniden kurulur (§33).
			_board.set_tutorial_input_locked(true)
			_start_timer(MERGE_TIMEOUT, _retry_match_drop)
		_:
			pass


## Rehberli merge KİMLİĞİ (M8.10): adım YALNIZ öğrettiğimiz merge'le ilerler.
##
## Bu durumda başka bir merge OLAMAZ — board'da yalnız iki parça var, ikisi de
## tutorial kuyruğundan gelen T1, ikinci bırakmadan sonra girdi kilitli ve
## güçler pasif. Yine de kimlik AÇIKÇA doğrulanıyor: yalnız T1+T1'in ürünü
## (`MERGE_RESULT_TIER`) kabul edilir; başka bir tier'dan gelen sinyal
## (ileride bir özellik board'a parça eklerse) adımı ilerletemez.
func _on_merge_performed(tier: int, _position: Vector2) -> void:
	if _step != Step.MATCH_DROP:
		return
	if tier != MERGE_RESULT_TIER:
		push_warning("Tutorial: beklenmeyen merge tier %d (yalnız %d ilerletir)"
			% [tier, MERGE_RESULT_TIER])
		return
	TutorialEvents.emit(&"tutorial_first_merge", {"tier": tier, "elapsed_ms": _elapsed_ms()})
	_match_target = null
	_enter(Step.MERGE_SUCCESS)


## İlk T1'in durmasını bekler, sonra MATCH_DROP'u hedefiyle kurar. Fizik
## beklenmedik biçimde uzarsa (kenardan sekme) zaman aşımıyla yine de devam
## edilir — oyuncu beklemede kalmaz.
func _await_settle() -> void:
	var waited: float = 0.0
	while waited < SETTLE_TIMEOUT:
		if _board == null or not is_instance_valid(_board) or not is_active():
			return
		if waited >= SETTLE_MIN and _has_settled_piece():
			break
		waited += _wait_step()
		await get_tree().physics_frame
	if _board == null or not is_instance_valid(_board) or not is_active():
		return
	var live: Array = _board.live_dumplings()
	_match_target = live[0] if not live.is_empty() else null
	_enter(Step.MATCH_DROP)


## TEK bir parça "oturmuş" sayılır mı (yukarıdaki üç şarttan 2 ve 3; gözlem
## penceresini `_await_settle` sayar). Saf fonksiyon: herhangi bir board ile
## çağrılabilir, hiçbir şey değiştirmez — testler doğrudan bunu ölçüyor.
static func piece_settled(piece: Dumpling, board: Node2D) -> bool:
	if piece == null or not is_instance_valid(piece) or piece.is_queued_for_deletion():
		return false
	if board == null or not is_instance_valid(board):
		return false
	if piece.global_position.y <= board.overflow_line_y():
		return false  # hâlâ düşme bölgesinde / kaba inmemiş
	return piece.linear_velocity.length() < SETTLE_SPEED


func _has_settled_piece() -> bool:
	for piece: Dumpling in _board.live_dumplings():
		if piece_settled(piece, _board):
			return true
	return false


## Test/teşhis kancası: `_await_settle`'ın kullandığı nitelik.
func has_settled_piece() -> bool:
	return _board != null and is_instance_valid(_board) and _has_settled_piece()


## Merge gelmedi (nadir): ikinci bir T1 daha verilir ve hedef tazelenir.
func _retry_match_drop() -> void:
	if _step != Step.MATCH_DROP or _board == null or not is_instance_valid(_board):
		return
	var live: Array = _board.live_dumplings()
	var best: Dumpling = null
	for piece: Dumpling in live:
		if is_instance_valid(piece) and piece.tier == 1:
			best = piece
			break
	if best == null:
		# T1 kalmadı (beklenmedik): öğretim kısmını bitir, akış sürsün.
		_enter(Step.MERGE_SUCCESS)
		return
	_match_target = best
	_board.set_tutorial_pending_tier(1)
	_enter(Step.MATCH_DROP)


# --- Bitiş -------------------------------------------------------------------------

## Tamamlama IDEMPOTENT (§26): birden fazla callback/dokunuş tek kayıt
## mutasyonu üretir, `completed` bir kez yayılır.
func _finish(source: String) -> void:
	if _finished:
		return
	_finished = true
	_cancel_timer()
	_back_open = false
	var last_step: String = step_name()
	_step = Step.COMPLETE
	_completion_context = {"step": last_step, "elapsed_ms": _elapsed_ms()}
	_disconnect_board()
	if _overlay != null:
		_overlay.hide_overlay()
	if _board != null and is_instance_valid(_board):
		_board.clear_tutorial_drop_assist()
		_board.set_tutorial_input_locked(false)
		_board.set_tutorial_paused(false)
	# Tamamlanma OLAYI burada YAYILMAZ: tek kanonik yol `Onboarding.complete`
	# (Main bunu çağırır) — çift bitirme ikinci bir olay üretemesin.
	completed.emit(source)


## Round tutorial açıkken bitti (savunma yolu, Main çağırır): tutorial
## kanonik tamamlanma yolundan bitirilir — oyuncu bir round'u tamamladı,
## onboarding yarım kalmaz.
func finish_for_round_end() -> void:
	_finish(Onboarding.SOURCE_TUTORIAL)


## Round terk edildi / sahne yıkılıyor: overlay kapanır, kayıt DEĞİŞMEZ
## (onboarding false kalır, tutorial bir sonraki açılışta baştan başlar).
func abort() -> void:
	if not is_active():
		return
	_cancel_timer()
	_disconnect_board()
	_back_open = false
	_step = Step.INACTIVE
	_match_target = null
	if _overlay != null:
		_overlay.hide_overlay()
	_board = null


# --- Yardımcılar --------------------------------------------------------------------

func _piece_rect(piece: Dumpling) -> Rect2:
	if piece == null or not is_instance_valid(piece) or _board == null:
		return Rect2()
	return _board.tutorial_dumpling_rect(piece).grow(PIECE_PAD)


func _elapsed_ms() -> int:
	return Time.get_ticks_msec() - _started_msec


func _wait_step() -> float:
	return maxf(0.001, get_process_delta_time())


func _start_timer(delay: float, action: Callable) -> void:
	_cancel_timer()
	_timer = get_tree().create_timer(maxf(0.01, delay * time_scale), true, false, true)
	_timer.timeout.connect(action)


func _cancel_timer() -> void:
	if _timer != null:
		for connection in _timer.timeout.get_connections():
			_timer.timeout.disconnect(connection["callable"])
		_timer = null
