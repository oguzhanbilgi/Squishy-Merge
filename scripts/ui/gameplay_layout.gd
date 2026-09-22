class_name GameplayLayout
extends RefCounted
## Oyun ekrani yerlesim sozlesmesi (M8.6-02). Tam belge:
## docs/UI_VISUAL_SYSTEM.md §13 "Gameplay Shell".
##
## Ekran dikeyde DORT bolgeye ayrilir (720 px tasarim tuvali, yukseklik
## serbest — 1280 (16:9) ile 1560 (19.5:9) arasinda dogrulanir):
##
##   +-----------------------------+  0
##   |  HUD  (skor / hedef / guc)  |  SAFE_TOP .. hud.end       sabit yukseklik
##   +-----------------------------+
##   |                             |
##   |  BOARD (fizik penceresi)    |  esnek: kalan alanin tamami
##   |                             |
##   +-----------------------------+
##   |  STRIP (evrim seridi)       |  sabit yukseklik
##   +-----------------------------+
##   |  BANNER (AdMob, M8.9-02)    |  `banner_height` (yuva + alt güvenli pay)
##   +-----------------------------+  H
##
## Kurallar:
##   - Fizik referans koordinat sisteminde kalir (GameBoard.FLOOR_Y 1180,
##     RIM_ABOVE_LINE 420 ...). BOARD bolgesine bir Camera2D ile
##     SIGDIRILIR (`fit_board`): zoom = min(en, boy) oranindan, ust sinir
##     ZOOM_MAX. Fizik olculeri DEGISMEZ.
##   - Kontroller (guc slotlari, ayarlar, Sıradaki) yalniz HUD bolgesinde;
##     BOARD ve BANNER bolgelerine hicbir kontrol girmez.
##   - BANNER bolgesi (M8.9-02, owner karari): AdMob banner yuvasi
##     (`UiKit.bottom_inset` = yuva + alt guvenli pay) `banner_height`'i
##     doldurur, STRIP ve BOARD yukari kayar, HUD ve guc slotlari yerinden
##     oynamaz; hicbir kontrol ve kap bu bolgeye girmez. Gameplay yeniden
##     yazilmadi: FIZIK, kap olculeri, FLOOR_Y, tasma cizgisi, yaricaplar
##     DEGISMEDI — yalniz kamera/yerlesim.
##   - KOMPAKT mod: banner varken kullanilabilir yukseklik (H - banner)
##     COMPACT_BELOW'un altindaysa (16:9 telefonlar) ONCE dekoratif
##     araliklar daraltilir (HUD-board / serit araliklari 8->4, serit dip
##     payi 10->6: 12 px geri kazanilir; HUD satir yukseklikleri ve satir
##     arasi kart minimumlari/plaka tasmasi oldugu icin DEGISMEZ), kap
##     olcegi ancak ondan sonra kucukur (720x1280'de zoom 1.064 -> 0.958,
##     -%10; A36'da kap genislik sinirli, degisim ~0). Bannersiz ve uzun
##     ekranda kompakt mod hic devreye girmez.
##   - Uzun ekranda (1560) fazla dikey alan BOARD'a gider: kap once
##     buyur (ZOOM_MAX'a kadar), kalan pay kabin ustune (dusurme
##     bolgesi) ve altina (tezgah) EXTRA_ABOVE oraniyla dagitilir.
##     HUD/strip/slot OLCEKLENMEZ.

## Tasarim tuvali genisligi (project.godot canvas_items + expand).
const CANVAS_WIDTH: float = 720.0
## Ust guvenli pay ve yan kenar payi.
const SAFE_TOP: float = 10.0
const SIDE: float = 18.0
## HUD satirlari: 1) geri+ayarlar | skor | siradaki+cikis  2) tepsi(2 guc) | hedef | tepsi(2 guc)
const ROW1_HEIGHT: float = 64.0
const ROW2_HEIGHT: float = 104.0
const ROW_GAP: float = 8.0
## HUD ile board arasi nefes payi.
const HUD_BOARD_GAP: float = 8.0
## Guc slotu olcusu ve ikili aralik (dokunma hedefi >= 48 — 80 px); iki
## slot bir TEPSI (PanelTray) icinde durur, tepsi ic payi TRAY_PAD.
const SLOT_SIZE: Vector2 = Vector2(78.0, 82.0)
const SLOT_GAP: float = 8.0
const TRAY_PAD: float = 7.0
## Ikili slot grubu ile ortadaki hedef plakasi arasi.
const GOAL_GAP: float = 14.0
## Kose butonlari (geri, ayarlar, cikis) ve Sıradaki plakasi.
const SETTINGS_SIZE: float = 56.0
const CORNER_GAP: float = 8.0
const NEXT_SIZE: Vector2 = Vector2(146.0, 62.0)
## Evrim seridi.
const STRIP_HEIGHT: float = 64.0
const STRIP_GAP: float = 8.0
const STRIP_BOTTOM_GAP: float = 10.0
## Kamera sigdirma ust siniri: tier sprite'lari 512 px + mipmap, 1.2x'te
## hala keskin; daha fazlasi kabi ekrana tasirdi.
const ZOOM_MAX: float = 1.2
## Fazla dikey alanin kabin USTUNE giden orani (kalan alta: tezgah payi).
const EXTRA_ABOVE: float = 0.5
## Kompakt mod esigi: banner dusuldukten sonra kalan yukseklik bunun
## altindaysa (16:9 = 1280 - 112 = 1168) araliklar daraltilir.
const COMPACT_BELOW: float = 1240.0
const COMPACT_GAP: float = 4.0
const COMPACT_STRIP_BOTTOM_GAP: float = 6.0


## Gelecek banner'in ayirdigi alt pay (v1: 0). AdMob geldiginde
## sağlayıcı bunu doldurur; hicbir kontrol bu bolgeye girmez.
static var _banner_height: float = 0.0


static func banner_height() -> float:
	return _banner_height


static func set_banner_height(height: float) -> void:
	_banner_height = maxf(0.0, height)


## Etkin banner payi: test/arac override'i (`set_banner_height`) ile canli
## reklam yuvasinin (`UiKit.bottom_inset`: yuva + alt guvenli pay) buyugu.
## Eklentisiz masaustunde ve onboarding bitmeden yuva 0 → eski duzen birebir.
static func effective_banner_height(view: Vector2) -> float:
	return maxf(_banner_height, UiKit.bottom_inset(view))


## Banner varken kisa ekranda kompakt aralik modu (bkz. ust not).
static func is_compact(view: Vector2, banner_height: float) -> bool:
	return banner_height > 0.0 and (view.y - banner_height) < COMPACT_BELOW


## Bolge dikdortgenleri. `view` viewport boyutu (720 x H), `banner_height`
## gelecek banner'in ayirdigi alt pay (v1: 0), `safe_top` cihazin ust
## guvenli alan payi (tuval px; centik/punch-hole — A36'da 92 fiziksel px =
## 61 tuval px, skor plakasinin tam ustune dusuyordu). HUD bu payin altina
## iner, BOARD kucuLur; 16:9/centiksiz ekranda SAFE_TOP.
static func compute(view: Vector2, banner_height: float = 0.0,
		safe_top: float = 0.0) -> Dictionary:
	var w: float = view.x
	var h: float = view.y
	var compact: bool = is_compact(view, banner_height)
	var row1_h: float = ROW1_HEIGHT
	var row2_h: float = ROW2_HEIGHT
	var row_gap: float = ROW_GAP
	var hud_gap: float = COMPACT_GAP if compact else HUD_BOARD_GAP
	var strip_gap: float = COMPACT_GAP if compact else STRIP_GAP
	var strip_bottom: float = COMPACT_STRIP_BOTTOM_GAP if compact else STRIP_BOTTOM_GAP
	var top: float = maxf(SAFE_TOP, safe_top + 4.0)
	var row1 := Rect2(SIDE, top, w - SIDE * 2.0, row1_h)
	var row2 := Rect2(SIDE, row1.end.y + row_gap, w - SIDE * 2.0, row2_h)
	var hud := Rect2(0.0, 0.0, w, row2.end.y)
	var banner := Rect2(0.0, h - banner_height, w, banner_height)
	var strip := Rect2(SIDE, banner.position.y - strip_bottom - STRIP_HEIGHT,
		w - SIDE * 2.0, STRIP_HEIGHT)
	var board := Rect2(0.0, hud.end.y + hud_gap, w,
		strip.position.y - strip_gap - (hud.end.y + hud_gap))

	# Satir 1: [geri][ayarlar] ... skor (ekran ortasi) ... [siradaki][cikis]
	var corner_y: float = row1.position.y + (row1_h - SETTINGS_SIZE) * 0.5
	var back := Rect2(row1.position.x, corner_y, SETTINGS_SIZE, SETTINGS_SIZE)
	var settings := Rect2(back.end.x + CORNER_GAP, corner_y, SETTINGS_SIZE, SETTINGS_SIZE)
	var exit := Rect2(row1.end.x - SETTINGS_SIZE, corner_y, SETTINGS_SIZE, SETTINGS_SIZE)
	var next := Rect2(exit.position.x - CORNER_GAP - NEXT_SIZE.x,
		row1.position.y + (row1_h - NEXT_SIZE.y) * 0.5, NEXT_SIZE.x, NEXT_SIZE.y)
	# Skor plakasi ekran merkezinde; iki kumeye esit uzaklikta olacak
	# kadar genis bir span (icerik plakayi ortalar).
	var half: float = minf(w * 0.5 - settings.end.x, next.position.x - w * 0.5) - GOAL_GAP
	var score_span := Rect2(w * 0.5 - half, row1.position.y, half * 2.0, row1_h)

	# Satir 2: tepsi(2 slot) | hedef karti | tepsi(2 slot).
	var tray_size := Vector2(SLOT_SIZE.x * 2.0 + SLOT_GAP + TRAY_PAD * 2.0,
		SLOT_SIZE.y + TRAY_PAD * 2.0 + 4.0)
	var tray_y: float = row2.position.y + (row2_h - tray_size.y) * 0.5
	var tray_left := Rect2(Vector2(row2.position.x, tray_y), tray_size)
	var tray_right := Rect2(Vector2(row2.end.x - tray_size.x, tray_y), tray_size)
	var slot_y: float = tray_y + TRAY_PAD
	var slots: Array[Rect2] = []
	slots.append(Rect2(Vector2(tray_left.position.x + TRAY_PAD, slot_y), SLOT_SIZE))
	slots.append(Rect2(Vector2(slots[0].end.x + SLOT_GAP, slot_y), SLOT_SIZE))
	slots.append(Rect2(Vector2(tray_right.position.x + TRAY_PAD, slot_y), SLOT_SIZE))
	slots.append(Rect2(Vector2(slots[2].end.x + SLOT_GAP, slot_y), SLOT_SIZE))
	var goal := Rect2(tray_left.end.x + GOAL_GAP, row2.position.y,
		tray_right.position.x - GOAL_GAP - (tray_left.end.x + GOAL_GAP), row2_h)

	return {
		"view": Rect2(Vector2.ZERO, view), "safe_top": top, "compact": compact,
		"hud": hud, "row1": row1, "row2": row2,
		"back": back, "settings": settings, "score_span": score_span, "next": next, "exit": exit,
		"tray_left": tray_left, "tray_right": tray_right,
		"slots": slots, "goal": goal,
		"board": board, "strip": strip, "banner": banner,
	}


## Referans (fizik) dunyasindaki `frame` dikdortgenini `region` ekran
## bolgesine sigdiran kamera: {zoom, position}. Camera2D DRAG_CENTER:
##   screen = (world - position) * zoom + view / 2
static func fit_board(frame: Rect2, region: Rect2, view: Vector2) -> Dictionary:
	var zoom: float = minf(region.size.x / frame.size.x, region.size.y / frame.size.y)
	zoom = minf(zoom, ZOOM_MAX)
	var shown: Vector2 = frame.size * zoom
	var extra: Vector2 = region.size - shown
	# Yatay: ortala. Dikey: EXTRA_ABOVE orani kabin ustune.
	var screen_top_left: Vector2 = region.position + Vector2(extra.x * 0.5, extra.y * EXTRA_ABOVE)
	var screen_center: Vector2 = screen_top_left + shown * 0.5
	var position: Vector2 = frame.get_center() - (screen_center - view * 0.5) / zoom
	return {"zoom": zoom, "position": position,
		"screen_rect": Rect2(screen_top_left, shown)}


## Uzun ekranda kap BOARD bolgesini doldurmuyorsa (genislik sinirli zoom)
## evrim seridi ekranin dibinde kalmayip kabin tabanina yaklasir: kap +
## raf tek parca okunur, bos alan en alta (banner bolgesinin ustune)
## toplanir. BOARD/BANNER dikdortgenleri degismez.
static func hug_strip(rects: Dictionary, board_bottom_screen: float) -> Dictionary:
	var strip: Rect2 = rects["strip"]
	var hugged_y: float = board_bottom_screen + (COMPACT_GAP if bool(rects.get("compact", false)) else STRIP_GAP)
	if hugged_y < strip.position.y:
		strip.position.y = hugged_y
		rects["strip"] = strip
	return rects


## Iki dikdortgen olculebilir sekilde cakisiyor mu (kenar temasi sayilmaz).
static func overlaps(a: Rect2, b: Rect2) -> bool:
	var inter: Rect2 = a.intersection(b)
	return inter.size.x > 0.5 and inter.size.y > 0.5
