extends RefCounted
## Basit oyun sezgisi — hem headless denge testi (bot_runner.gd) hem de
## ekran goruntusu araci (screenshot_runner.gd) tarafindan kullaniliyor.
## Uretim kodu degil; oyun calisirken cagrilmaz.
##
## Iki kural:
##  1) Tahtada ayni tier'dan bir parca varsa tam ustune birak (merge).
##  2) Yoksa yiginin en bos/en alcak noktasina birak.
## Amac "mukemmel oyun" degil, "makul oyun ile bitirilebiliyor mu" sorusu.

## Kap genisligi boyunca kac aday x noktasi denenir (bos vadi aramasi).
const AIM_SAMPLES: int = 24


static func pick_x(board: Node2D, tier: int) -> float:
	var layer: Node2D = board._dumpling_layer
	var left: float = board._left_x()
	var right: float = board._right_x()
	var margin: float = TierConfig.radius(tier)

	# 1) Ayni tier'dan bir parca ara — en YUKSEKTEKINI sec ki ustune dusen
	#    parca yigina gomulmeden ona carpsin.
	var best_same: Dumpling = null
	for child in layer.get_children():
		var d := child as Dumpling
		if d == null or d.tier != tier or d.is_merging:
			continue
		if best_same == null or d.global_position.y < best_same.global_position.y:
			best_same = d
	if best_same != null:
		return clampf(best_same.global_position.x, left + margin, right - margin)

	# 2) En bos sutun: her aday x icin yigin yuzeyini bul, en derini sec.
	var best_x: float = (left + right) * 0.5
	var best_depth: float = -1e20
	for i in AIM_SAMPLES:
		var x: float = lerpf(left + margin, right - margin,
			float(i) / float(AIM_SAMPLES - 1))
		var surface_y: float = board.FLOOR_Y
		for child in layer.get_children():
			var d := child as Dumpling
			if d == null:
				continue
			if absf(d.global_position.x - x) < TierConfig.radius(d.tier) + margin:
				surface_y = minf(surface_y,
					d.global_position.y - TierConfig.radius(d.tier))
		if surface_y > best_depth:
			best_depth = surface_y
			best_x = x
	return best_x
