class_name RewardedPolicy
extends RefCounted
## Ödüllü reklamla güç refill politikasının TEK tanım noktası
## (GAME_DESIGN.md §5.7.3).
##
## KİLİTLİ KURALLAR:
##
##   - Günlük kota **dört gücün TOPLAMI** içindir, tip başına DEĞİL.
##   - Kotayı yalnızca **başarılı reward grant** tüketir. Reklam isteği,
##     reklamın açılması, yüklenememesi ve ödülsüz kapanması TÜKETMEZ.
##   - Yeni gün kotayı sıfırlar. Round değişimi ve uygulama yeniden
##     başlatması sıfırlamaz (kayıt tarih + sayaç tutuyor).
##   - Revive hakları (§11) bu kotadan TAMAMEN BAĞIMSIZDIR. Aynı round'da
##     hem güç refill'i hem iki revive reklamı görülebilir.
##
## ⚠️ GERÇEK ADMOB YOK. Bu dosya yalnızca politikayı ve kotayı tutar;
## reklamı kimse göstermiyor. Sağlayıcı `main.gd` üzerinden bağlanacak.

## Günde kaç ödüllü güç refill'i verilir (dört gücün toplamı).
##
## SEÇİM GEREKÇESİ (ölçüldü, `python tools/shop_economy.py caps`,
## 3000 deneme/senaryo, 90 gün). Yoğun oyuncu (10 round/gün, yüksek
## kullanım) — kararın verildiği senaryo:
##
## | cap | reklam/gün | bedava | Hamurla | bedava% | karşılanmayan | gün90 Hamur |
## |---|---|---|---|---|---|---|
## | yok | 0.00 | 0 | 379 | %0 | 67 | 330 |
## | **1** | **1.00** | **90** | **348** | **%20,5** | **8** | **3.735** |
## | 2 | 1.99 | 179 | 265 | %40,3 | 1 | 14.685 |
## | 3 | 2.92 | 263 | 182 | %59,1 | 0 | 25.610 |
## | cap yok (1/round) | 4.96 | 446 | 0 | %100 | 0 | 50.220 |
##
## **1 seçildi — ama "mağazayı en çok koruyan" olduğu için değil.** Asıl
## gerekçe marjinal fayda/maliyet:
##
##   - 1/gün, karşılanmayan güç isteğini zaten **67 → 8 (%88)** düşürüyor,
##     yani oyuncunun yaşadığı mahrumiyetin neredeyse tamamını çözüyor.
##   - 2/gün bunun üstüne yalnızca **7 istek** daha karşılıyor (90 günde,
##     yani günde 0,08) ama 90. gün Hamur fazlasını **3.735 → 14.685'e
##     (4 kat)** çıkarıyor. Kötü takas.
##   - 3/gün elendi: 90. gün Hamur'u **25.610**, yani güç sink'i OLMAYAN
##     referansın (50.025) yalnızca yarısı kadar aşağıda. M8.5-05'te
##     çözülen geç oyun enflasyonuna yarı yola kadar geri dönmek demek.
##     Ayrıca güçlerin %59'u bedava geliyor — rewarded artık ana kaynak.
##
## Reklam yükü ayırt edici değil: yoğun oyuncuda revive'ın teorik tavanı
## zaten 20 reklam/gün (10 round × 2), güç capi 1 → 3 toplam tavanı
## yalnızca 21 → 23 yapıyor.
const DAILY_POWER_REFILLS: int = 1


static func daily_cap() -> int:
	return DAILY_POWER_REFILLS


## Bugün kaç ödüllü güç refill'i alındı.
static func grants_today() -> int:
	return SaveManager.rewarded_power_grants_today(_today())


static func remaining_today() -> int:
	return maxi(0, DAILY_POWER_REFILLS - grants_today())


## Ödüllü refill hakkı kaldı mı? (Sağlayıcının hazır olup olmadığından
## BAĞIMSIZ — o ayrı bir kontrol.)
static func can_grant() -> bool:
	return remaining_today() > 0


## Ödül GERÇEKTEN kazanıldığında çağrılır: +1 güç verir ve kotadan bir
## düşer. İkisi tek transaction (tek mutasyon + tek save).
##
## Dönüş: verildiyse true. Kota dolmuşsa ya da tip geçersizse hiçbir şey
## değişmez.
##
## ⚠️ Bu metodu YALNIZCA "reward earned" callback'i çağırmalı. "Reklam
## kapandı" callback'i ödül DEĞİLDİR (§11.2'deki revive invariant'ının
## aynısı).
static func grant(type: PowerUp.Type) -> bool:
	return SaveManager.grant_rewarded_powerup(type, _today())


## Cihazın yerel tarihi.
##
## ⚠️ SAAT MANİPÜLASYONU: backend yok, doğrulanabilir sunucu saati yok.
## Cihaz saatini ileri alan bir oyuncu günlük kotayı tazeleyebilir. Bu,
## günlük giriş ödülünün (§5.4) zaten taşıdığı aynı açık ve BİLİNÇLİ
## kabul ediliyor: v1'de backend bir non-goal, ve kazanılabilecek şey
## kozmetik/tüketilebilir. Sunucu doğrulaması olmadan yapılacak her
## "önlem" güvenlik tiyatrosu olurdu.
static func _today() -> String:
	return Time.get_date_string_from_system()
