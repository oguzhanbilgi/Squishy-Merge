extends RefCounted
## Drop havuzu: "bag randomizer" (Tetris'in 7-bag'i ile ayni fikir).
##
## Neden: eskiden her drop bagimsiz uniform cekiliyordu (randi_range(1, 3)).
## Bu, oyuncunun elinden bagimsiz sanssiz seriler uretiyordu — owner L9/L10'u
## bitirdi ama "adil hissetmedi" dedi. Olcum (80 drop'luk bir round, 200.000
## deneme):
##
##   model              medyan en uzun seri   p95   max   >=5'li seri
##   bagimsiz uniform   4                     7     16    %48
##   torba 9 (3'er)     3                     4     6     %4.3
##
## Kompozisyon adaleti de duzeliyor: 80 drop'ta bir tier'i gorme sayisi
## bagimsizda p5-p95 araligi 20-34 iken torbada 26-27 (ideal 26.7).
##
## COPIES_PER_TIER neden 3: torba 6 (2'ser) 5+ serileri tamamen siliyor ama
## "iki tane gordum, ucuncusu gelmez" diye tahmin edilebilir hale geliyor.
## 3'er kopya adaletin neredeyse tamamini veriyor, cesitliligi koruyor.

const COPIES_PER_TIER: int = 3

## Karilmis torba. Cekim sondan yapiliyor (pop_back ucuz).
var _bag: Array[int] = []


## Sonraki drop tier'i. Torba bosalinca yeniden dolduruluyor.
func next_tier() -> int:
	if _bag.is_empty():
		_refill()
	return _bag.pop_back()


func _refill() -> void:
	_bag.clear()
	for tier in range(1, TierConfig.DROP_POOL_MAX_TIER + 1):
		for i in COPIES_PER_TIER:
			_bag.append(tier)
	_bag.shuffle()
