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
##   |  BANNER (gelecek AdMob)     |  `banner_height` (v1'de 0)
##   +-----------------------------+  H
##
## Kurallar:
##   - Fizik referans koordinat sisteminde kalir (GameBoard.FLOOR_Y 1180,
##     RIM_ABOVE_LINE 420 ...). BOARD bolgesine bir Camera2D ile
##     SIGDIRILIR (`fit_board`): zoom = min(en, boy) oranindan, ust sinir
##     ZOOM_MAX. Fizik olculeri DEGISMEZ.
##   - Kontroller (guc slotlari, ayarlar, Sıradaki) yalniz HUD bolgesinde;
##     BOARD ve BANNER bolgelerine hicbir kontrol girmez.
##   - BANNER bolgesi v1'de 0 px'tir ama sozlesme buradadir: AdMob banner
##     geldiginde `banner_height` dolar, STRIP ve BOARD yukari kayar, HUD
##     ve guc slotlari yerinden oynamaz. Gameplay yeniden yazilmaz.
##   - Uzun ekranda (1560) fazla dikey alan BOARD'a gider: kap once
##     buyur (ZOOM_MAX'a kadar), kalan pay kabin ustune (dusurme
##     bolgesi) ve altina (tezgah) EXTRA_ABOVE oraniyla dagitilir.
##     HUD/strip/slot OLCEKLENMEZ.

## Tasarim tuvali genisligi (project.godot canvas_items + expand).
const CANVAS_WIDTH: float = 720.0
## Ust guvenli pay ve yan kenar payi.
const SAFE_TOP: float = 10.0
const SIDE: float = 14.0
## HUD satirlari: 1) ayarlar | skor | siradaki  2) guc x2 | hedef | guc x2
const ROW1_HEIGHT: float = 62.0
const ROW2_HEIGHT: float = 92.0
const ROW_GAP: float = 8.0
## HUD ile board arasi nefes payi.
const HUD_BOARD_GAP: float = 8.0
## Guc slotu olcusu ve ikili aralik (dokunma hedefi >= 48 — 84 px).
const SLOT_SIZE: Vector2 = Vector2(84.0, 88.0)
const SLOT_GAP: float = 8.0
## Ikili slot grubu ile ortadaki hedef plakasi arasi.
const GOAL_GAP: float = 12.0
## Ayarlar butonu ve Sıradaki plakasi.
const SETTINGS_SIZE: float = 58.0
const NEXT_SIZE: Vector2 = Vector2(138.0, 58.0)
## Evrim seridi.
const STRIP_HEIGHT: float = 64.0
const STRIP_GAP: float = 8.0
const STRIP_BOTTOM_GAP: float = 10.0
## Kamera sigdirma ust siniri: tier sprite'lari 512 px + mipmap, 1.2x'te
## hala keskin; daha fazlasi kabi ekrana tasirdi.
const ZOOM_MAX: float = 1.2
## Fazla dikey alanin kabin USTUNE giden orani (kalan alta: tezgah payi).
const EXTRA_ABOVE: float = 0.5


## Gelecek banner'in ayirdigi alt pay (v1: 0). AdMob geldiginde
## sağlayıcı bunu doldurur; hicbir kontrol bu bolgeye girmez.
static var _banner_height: float = 0.0


static func banner_height() -> float:
	return _banner_height


static func set_banner_height(height: float) -> void:
	_banner_height = maxf(0.0, height)


## Bolge dikdortgenleri. `view` viewport boyutu (720 x H), `banner_height`
## gelecek banner'in ayirdigi alt pay (v1: 0), `safe_top` cihazin ust
## guvenli alan payi (tuval px; centik/punch-hole — A36'da 92 fiziksel px =
## 61 tuval px, skor plakasinin tam ustune dusuyordu). HUD bu payin altina
## iner, BOARD kucuLur; 16:9/centiksiz ekranda SAFE_TOP.
static func compute(view: Vector2, banner_height: float = 0.0,
		safe_top: float = 0.0) -> Dictionary:
	var w: float = view.x
	var h: float = view.y
	var top: float = maxf(SAFE_TOP, safe_top + 4.0)
	var row1 := Rect2(SIDE, top, w - SIDE * 2.0, ROW1_HEIGHT)
	var row2 := Rect2(SIDE, row1.end.y + ROW_GAP, w - SIDE * 2.0, ROW2_HEIGHT)
	var hud := Rect2(0.0, 0.0, w, row2.end.y)
	var banner := Rect2(0.0, h - banner_height, w, banner_height)
	var strip := Rect2(SIDE, banner.position.y - STRIP_BOTTOM_GAP - STRIP_HEIGHT,
		w - SIDE * 2.0, STRIP_HEIGHT)
	var board := Rect2(0.0, hud.end.y + HUD_BOARD_GAP, w,
		strip.position.y - STRIP_GAP - (hud.end.y + HUD_BOARD_GAP))

	# Satir 1: ayarlar sol, skor orta, siradaki sag.
	var settings := Rect2(row1.position.x, row1.position.y + (ROW1_HEIGHT - SETTINGS_SIZE) * 0.5,
		SETTINGS_SIZE, SETTINGS_SIZE)
	var next := Rect2(row1.end.x - NEXT_SIZE.x, row1.position.y + (ROW1_HEIGHT - NEXT_SIZE.y) * 0.5,
		NEXT_SIZE.x, NEXT_SIZE.y)
	# Skor plakasi: iki kenar arasinda ortalanir; genisligi icerige gore
	# (HUD `score_max_width` ile sinirlar).
	var score_span := Rect2(settings.end.x + GOAL_GAP, row1.position.y,
		next.position.x - GOAL_GAP - (settings.end.x + GOAL_GAP), ROW1_HEIGHT)

	# Satir 2: 2 slot | hedef | 2 slot.
	var slot_y: float = row2.position.y + (ROW2_HEIGHT - SLOT_SIZE.y) * 0.5
	var slots: Array[Rect2] = []
	slots.append(Rect2(Vector2(row2.position.x, slot_y), SLOT_SIZE))
	slots.append(Rect2(Vector2(row2.position.x + SLOT_SIZE.x + SLOT_GAP, slot_y), SLOT_SIZE))
	slots.append(Rect2(Vector2(row2.end.x - SLOT_SIZE.x * 2.0 - SLOT_GAP, slot_y), SLOT_SIZE))
	slots.append(Rect2(Vector2(row2.end.x - SLOT_SIZE.x, slot_y), SLOT_SIZE))
	var goal := Rect2(slots[1].end.x + GOAL_GAP, row2.position.y,
		slots[2].position.x - GOAL_GAP - (slots[1].end.x + GOAL_GAP), ROW2_HEIGHT)

	return {
		"view": Rect2(Vector2.ZERO, view), "safe_top": top,
		"hud": hud, "row1": row1, "row2": row2,
		"settings": settings, "score_span": score_span, "next": next,
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
## raf tek parca okunur, bos alan en alta (gelecek banner bolgesinin
## ustune) toplanir. BOARD/BANNER dikdortgenleri degismez.
static func hug_strip(rects: Dictionary, board_bottom_screen: float) -> Dictionary:
	var strip: Rect2 = rects["strip"]
	var hugged_y: float = board_bottom_screen + STRIP_GAP
	if hugged_y < strip.position.y:
		strip.position.y = hugged_y
		rects["strip"] = strip
	return rects


## Iki dikdortgen olculebilir sekilde cakisiyor mu (kenar temasi sayilmaz).
static func overlaps(a: Rect2, b: Rect2) -> bool:
	var inter: Rect2 = a.intersection(b)
	return inter.size.x > 0.5 and inter.size.y > 0.5
