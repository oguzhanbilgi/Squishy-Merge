class_name PowerUpEconomy
extends RefCounted
## Güç ekonomisinin TEK tanım noktası (GAME_DESIGN.md §5.7).
##
## Fiyatlar burada; UI hiçbir yerde sayı hardcode etmiyor. Bir fiyat
## değişirse `tools/shop_economy.py` içindeki POWER_PRICES de değişmeli ve
## simülasyon yeniden çalıştırılmalı.
##
## Güç edinme yolları (GAME_DESIGN.md §5.7):
##   1. Başlangıç hediyesi — kayıt başına BİR KEZ her güçten ×1 (§10.1)
##   2. Hamur ile satın alma — BU DOSYA
##   3. Ödüllü reklam ile sınırlı refill — HENÜZ YOK, bkz. §5.7.3
##   4. Gerçek para Power Pack — HENÜZ YOK, bkz. §5.7.4
##
## Revive AYRI bir sistemdir (§11): Hamurla satın alınmaz ve güç envanteri
## VERMEZ. İkisini karıştırma.

## Rarity başına skin fiyatlarının (Shop.PRICES) yanındaki karşılığı.
## Index = PowerUp.Type sırası (BOMB / UPGRADE / SHAKE / CLEAR_SMALL).
##
## SEÇİM GEREKÇESİ (ölçüldü, `python tools/shop_economy.py sweep`):
##
## Fiyatın ŞEKLİ gameplay değerinden türetildi, kullanım sıklığından değil:
## Büyütücü en pahalı çünkü level'ın tier hedefini doğrudan karşılayabilen
## tek güç (§10.3'teki istisna); Sarsıntı en ucuz çünkü tek başına round
## kurtarmıyor.
##
## Fiyatın SEVİYESİ tarandı (taban 80'den 200'e, n=1200/nokta). Yoğun
## oyuncuda (10 round/gün) 30. gün Hamur medyanı:
##
## | taban | fiyat seti           | gün30 | gün90 | karşılanmayan/30g |
## |---|---|---|---|---|
## | —   | (güç sink'i yok)       | 14745 | 49975 | — |
## | 80  | [80,120,70,110]        |  2895 | 10045 |  4 |
## | 100 | [100,150,80,140]       |   950 |  1925 | 11 |
## | **120** | **[120,180,100,160]** | **315** | **330** | **27** |
## | 140 | [140,210,120,190]      |   235 |   235 | 42 |
## | 200 | [200,300,170,270]      |   235 |   230 | 71 |
##
## 120 seçildi çünkü:
##   - Hamur enflasyonunu fiilen bitiriyor (49.975 → 330, %99).
##   - 140 ve üstü DAHA FAZLA Hamur emmiyor: güce giden Hamur 16.200'de
##     doyuyor, artan tek şey karşılanmayan istek sayısı. Yani pahalıya
##     kaçmanın ekonomik getirisi yok, sadece oyuncuyu mahrum bırakıyor.
##   - Kasual oyuncu (3 round/gün) hiç mahrum kalmıyor (karşılanmayan 0) ve
##     ilk hafta ~335 Hamur ile geziyor.
##   - Önerilen 1 ödüllü refill/gün ile birlikte yoğun oyuncunun
##     karşılanmayan isteği 27 → ~7'ye iniyor, 30. gün Hamur'u 1.395'te
##     sağlıklı bir tampona oturuyor.
##
## Skin fiyatlarıyla tutarlılık: Sarsıntı 100 = iki Common skin (50),
## Büyütücü 180 > bir Rare skin (150), hepsi Legendary'nin (900) çok altında.
## Tüketilebilir bir güç, kalıcı bir Common ile Rare skin arasında duruyor.
const DOUGH_PRICES: Array[int] = [120, 180, 100, 160]


static func price(type: PowerUp.Type) -> int:
	return DOUGH_PRICES[int(type)]


## Oyuncunun Hamur'u bu kadar güce yetiyor mu?
static func can_afford(type: PowerUp.Type, amount: int = 1) -> bool:
	if amount <= 0:
		return false
	return SaveManager.dough() >= price(type) * amount


static func total_price(type: PowerUp.Type, amount: int = 1) -> int:
	return price(type) * maxi(amount, 0)


## Hamur ile güç satın alır.
##
## TEK LOGICAL TRANSACTION: Hamur düşmesi ve stok artışı SaveManager'da tek
## mutasyon + tek `save_game()` ile yapılıyor. İki ayrı yazma yapılsaydı
## aradaki bir çökme Hamur'u yakıp gücü vermeyebilirdi.
##
## Dönüş: satın alma gerçekleştiyse true. Başarısız durumda (geçersiz tip,
## amount <= 0, Hamur yetmiyor) HİÇBİR ŞEY değişmez.
static func purchase(type: PowerUp.Type, amount: int = 1) -> bool:
	return SaveManager.purchase_powerup_with_dough(type, amount)
