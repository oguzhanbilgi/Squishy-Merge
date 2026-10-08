# PROJECT_STATUS.md — Squishy Merge, tam proje raporu

**Son güncelleme:** 2026-10-06 · **Durum:** M0–M8 tamamlandı; M8.5–M8.10
(release/product stabilization: UI yeniden inşası, gameplay cilası, ses,
AdMob TEST-reklam monetizasyonu + günlük ödüller, ilk açılış tutorial'ı)
tamamlandı ve main'de; M9-01 production release hazırlığı (kod) tamamlandı,
M9-01.1 Samsung A36 UMP/gizlilik cihaz kapısı GEÇTİ; `task/037` shell_shots
bakım düzeltmesi main'de. Runtime / gameplay / TEST-reklam temeli donduruldu.
**Kalıcı paket kimliği kilitlendi (owner, 2026-09-24):** üretim / Play
`com.obappstudio.squishymerge`, QA / test `com.obappstudio.squishymerge.qa`.
**Hedef kitle kararı (owner, 2026-09-25 — FİNAL):** 13+ genel kitle, 13 yaş
altı için tasarlanmadı (Play 13–15 / 16–17 / 18+; `[Audience]
decision=general_13_plus`, reklam istekleri değişmedi) — ürün kitlesi KAPALI;
**13–17 genç reklam işlemi / yargı bölgesi uyumu AÇIK** (üretimden önce).
**TASK/040 (main'de, 2026-09-27):** dünya geneli dağıtım owner kararı; GMA 25.3.0 TEEN Godot
4.6.3'te Samsung A36'da kanıtlandı (spike; yeteneği TASK/042 üretim eklentisine taşıdı —
main'de, spike araçları kaldırıldı); Play Age Signals reklam kararında KULLANILMAZ; strateji
karar tablosu docs/monetization/GLOBAL_TEEN_AD_TREATMENT.md. TASK/040 bulgusu (üretim
eklentisi RequestConfiguration'ı hiç uygulamıyordu, derece G etkin değildi) **TASK/041'de
KAPANDI** (2026-09-27, main'de; TASK/042'de de kapalı): üretim yaması 0002, Samsung A36'da
derece G / TFCD / TFUA / test cihazları ilk reklam yüklemesinden önce uygulanıyor (TASK/041
yığını GMA 24.9.0 / UMP 3.2.0 idi; TASK/042 ile main'de GMA 25.3.0 / UMP 4.0.0).
**TASK/042 (2026-09-27, main'de — owner onayıyla ff-only alındı):** üretim AdMob yığını
GMA **25.3.0** / UMP **4.0.0** (play-services-ads-api 25.3.0 üzerinden geçişli) — üretim
yaması 0003, onaylı AAR'lar debug `a78acb22…` / release `f5a563a7…` (TASK/041'in
`14c745e9…`'u artık onaylı değil, geri gelirse CODE); TFAT (`AgeRestrictedTreatment`
UNSPECIFIED / CHILD / TEEN) üretim eklentisinde teknik olarak hazır, **üretim varsayılanı
herkes için UNSPECIFIED**; istek yapılandırması `MobileAds.initialize()`'dan ÖNCE bir kez
uygulanıp geri okunarak doğrulanıyor, uyuşmazlıkta SDK başlatılmıyor (fail-closed); SDK
yapılandırıldıktan sonra yaş işlemi kilitli. Derece G, TFCD / TFUA değişmedi; Play Age
Signals reklamda asla kullanılmaz. Samsung A36 kapısı GEÇTİ; main'de release kapısı BLOCKED
— CODE 0 · OWNER 9 · CONFIG 0. **TASK/043 (2026-09-27, main'de — owner onayıyla ff-only alındı):** nötr doğum tarihi ekranı (tutorial ve tutorial
kaynaklı Level 1'den sonra İLK güvenli kabukta; eski kayıtta açılıştaki Ana Sayfa) + yaş
bandı reklam yönlendirmesi — **13–17 → TFAT TEEN + derece T, 18+ → UNSPECIFIED + MA, 13 altı
/ bilinmeyen → reklam SDK'sı / UMP / reklam YOK** (13 altı: nötr kısıt ekranı, ilerleme
silinmez); ham doğum tarihi saklanmaz / gönderilmez / loglanmaz (kayıtta yalnız
`age_ad_band` + `next_age_transition_date`); 18. yaş günü (ve 13 altı → TEEN) soğuk açılışta
SDK'dan önce; Ayarlar'da "Yaş bilgisi"; Play Age Signals reklamda KULLANILMAZ. Resmî
araştırma iki somut açık madde buldu → yeni OWNER / UYUM satırları (Play "Uygunsuz
reklamlar": uygulamanın içerik derecesi T / MA'ya uygun olmalı; yargı bölgesi yaş
yükümlülükleri); **Samsung A36 kapısı GEÇTİ** (vakalar A–F, yalnız QA paketi) ve owner
stratejisi kaydedildi (`teen_ad_treatment = "age_band_routing"`) → main'de kapı BLOCKED — CODE 0
· OWNER 10 · CONFIG 0 (ayrıntı docs/monetization/AGE_BAND_ROUTING.md). **TASK/044
(2026-09-28, main'de — owner onayıyla ff-only alındı):** Player Meta V1 — gameplay skinleri
EMEKLİ (parça her zaman kanonik tier sprite'ı), Koleksiyon V1 + Profil + 3 yuva vitrin,
Ayarlar Profil'in dişli çarkında; Samsung A36 yerel kapısı GEÇTİ (§4.20). **TASK/045
(2026-09-28, main'de — owner onayıyla ff-only alındı):** Player Progression V1 — oyuncu
seviyesi + XP (kümülatif `player_xp`, seviye türetilir), 12 başarım, varsayılan + 8 unvan,
Profil'de seviye / BAŞARIMLAR / pencereler, sonuç ekranında kompakt XP şeridi (§4.21); bulut
kapısı + Samsung A36 yerel kapısı GEÇTİ (bulgu yok). **TASK/045.1 (2026-09-29, main'de —
owner onayıyla ff-only alındı; Samsung A36 yerel kapısı GEÇTİ, iki kurtarma bulgusu
giderildi):** çökmeye dayanıklı kayıt (geçici dosya + doğrulama + yer değiştirme, deterministik
kurtarma), Bomba / Büyütücü hedef dokunuşunun bırakışı artık parça düşürmüyor, otomatik günlük
pencere Koleksiyon detayının üstüne açılmıyor (§4.22). **TASK/045.2 (2026-09-29, main'de —
owner onayıyla ff-only alındı; bulut kapısı + Samsung A36 yerel kapısı GEÇTİ, bulgu yok):** oyun içi Ayarlar → Android geri
sonrası kaybolan ilk tahta bırakışı düzeltildi — 300 ms parmak yatışması artık dizi bazında
(pencerede başlayan dizi tamamen yutulur, pencereden önce başlamış dizi bölünmez), süre aynen
(§4.23). **TASK/046 (2026-09-29; main'de 2026-09-30 — masaüstü + Samsung A36 yerel kapısı
GEÇTİ, TASK/046.1 ile birlikte owner onayıyla ff-only alındı):**
Günlük / Haftalık Görevler V1 — 6 kilitli görev (günlük 15 merge / 2 tur / 1 level +10'ar,
haftalık 120 / 12 / 5 +40'ar; haftada ≤ 330 Hamur), ödül otomatik, gün = GÜNLÜK ÖDÜLLER günü,
hafta pazartesi; Ana Sayfa GÖREVLER girişi + pencere, sonuç ekranında görev rozeti (§4.24).
**TASK/046.1 (2026-09-30, main'de — masaüstü + Samsung A36 yerel kapısı GEÇTİ, tek cihaz bulgusu
`98d209e` ile düzeltildi):** yaş ekranı yalnız 13+ doğum tarihi sunar (GÜN / AY / YIL seçicisi;
tuş takımı ve 13 altı kısıt / ÇIKIŞ ekranı EMEKLİ), eski UNDER_13 → UNKNOWN + yeniden sorma,
TEEN / ADULT yönlendirmesi ve 18. yaş günü geçişi aynen, yaş arayüzü açıkken banner yok (§4.25);
**AÇIK uyum riski** — 13+ seçim ↔ Play nötr yaş ekranı rehberi (owner "Build as specified";
AGE_BAND_ROUTING §9.10). **TASK/046.2 (2026-10-01, main'de — masaüstü + Samsung A36 yerel kapısı
GEÇTİ, owner onayıyla ff-only alındı `afc10be → 6d3dbca`):** iptal edilen oyun dokunuşu (Android ACTION_CANCEL →
`canceled == true`) artık bekleyen parçayı düşürmez — `GameBoard._unhandled_input`'ta tek satırlık
koruma, TASK/047'nin önkoşulu (§4.26). **TASK/047 (2026-10-01; main'de 2026-10-02 — Günlük Merge
Challenge V1, oyuncuya "MEYDAN OKUMA"; masaüstü kapıları tamam, Samsung A36 yerel kapısı GEÇTİ — bulgu
yok; son engel "monoton kabul edilen gün" `f8c8ffb` ile kapatıldı, hedefli A36 kapısı 13/13 GEÇTİ;
owner onayıyla ff-only alındı `6d3dbca → aa6f867`):** isteğe bağlı günlük mod — hedef tier'ı sınırlı gerçek bırakışla, günün
deterministik parça dizisiyle oluştur; kilitli haftalık preset tablosu, güç / devam yok, ilerleme
yalıtımı (XP / görev / başarım / sandık / yıldız / istatistik / sonsuz etkisi yok), ilk başarı günde bir
kez +20 Hamur, Ana Sayfa'da GÖREVLER'in altında giriş (§4.27). **TASK/048 (2026-10-02; main'de — normal
RESULT_DELAY eski sonuç yarışı koruması + geçiş reklamı fırlatma sahipliği; masaüstü + Samsung A36 kapıları GEÇTİ;
owner onayıyla ff-only alındı `848797a → b9ae345`):** mola açıkken biten round 0,8 sn içinde değiştirilince
(yeniden başlatma / Ana Menüye Dön → başka level / Sonsuz / meydan okuma) eski sonuç ve geçiş reklamı artık açılmaz —
bellek içi round nesli (`_clear_board`'da ilerler) gecikmeden önce yakalanır, sonra doğrulanır; son engel (geçiş
reklamı fırlatma aralığı) de kapatıldı — reklam SDK'ya verildikten sonra round değişimi mola bitene dek ertelenir;
süre, ilerleme, reklam politikası ve TASK/047 aynen (§4.28). **TASK/049 (2026-10-03; main'de — round bitişi pencere
sahipliği; masaüstü + Samsung A36 kapıları + final kabul GEÇTİ — kontrollü kanonik tam masaüstü kapısı 44 / 44 temiz;
owner onayıyla ff-only alındı `25860df → f6cd072`):** Büyütücü dönüşümü molanın (ya da stok 0 refill penceresinin)
altında normal round'u bitirince sonuç ve geçiş reklamı artık o pencerenin altında açılmaz — kesinleşmede (ilerleme
yazıldıktan sonra, 0,8 sn beklemeden önce) mola / refill eylemsiz kapanır, board menü duraklamasından çıkar, kapalı
mola hiçbir eylem yaymaz; RESULT_DELAY, ilerleme, kayıt şeması, reklam politikası, TASK/048 savunması ve TASK/047
aynen (§4.29). **TASK/050 (2026-10-03; main'de — meydan okuma bitişi pencere sahipliği; masaüstü + Samsung A36
kapıları GEÇTİ — kontrollü kanonik tam masaüstü kapısı 45 / 45 temiz; owner onayıyla ff-only alındı `c543cd1 →
8f9e259`):** aynı karede merge meydan okumayı açık molada meşru biçimde bitirince mola artık meydan okuma sonucunun
üstünde kalmaz, girdisini tutmaz — meydan okuma bitiş işleyicisi TASK/049'un paylaşılan temizliğini ödül / tamamlanma
işleminden sonra, 0,8 sn beklemeye girmeden önce eşzamanlı çağırır (ayrı iş mantığı); TASK/047 sözleşmesi, TASK/048
savunması ve TASK/049 normal bitiş sahipliği aynen (§4.30). **TASK/051 (2026-10-04; main'de — round başlangıcında
dokunuş sahipliği; masaüstü + Samsung A36 kapıları GEÇTİ — kontrollü kanonik tam masaüstü kapısı 46 / 46 temiz; owner
onayıyla ff-only alındı `1293eb2 → 4bae821`):** "Yeniden Başlat" / TEKRAR / Harita / Sonsuz düğümüne hızlı ikinci dokunuş
(basılı tutulsa da) ve değişimden önce basılmış, canlı bir kontrolün tutmadığı parmak artık yeni board'da parça
bırakmaz — `_start_level` mevcut 300 ms yatışmayı board ağaca eklendikten sonra bir kez kurar, `GameBoard` basışı
kendisine ulaşmamış dizinin sürüklemesini / bırakışını işlemez (§4.31). **TASK/052 (2026-10-04; main'de — tam ekran mola
kurtarma + gelir odaklı geçiş politikası; masaüstü + Samsung A36 kapıları GEÇTİ — kontrollü tam masaüstü kapısı 49 / 49
temiz; owner onayıyla ff-only alındı `1d2fb28 → c7e3ccc`):** bitmeyen tam ekran molası düzeltildi (token'lı tam ekran
kirası; ödül asla kurtarmayla verilmez; Godot Vulkan'ın onStart RESUMED'ı reklam üstteyken sayılmaz) + gelir odaklı
zorunlu geçiş politikası `AdPolicy` (owner kabulüyle ilk üretim varsayılanı: 2 kesinleşen normal round + 300 aktif sn,
önce 900 sn; ödüllü kotalar değişmedi, app-open ertelendi); mutasyon 47 / 47, tam masaüstü kapısı 49 / 49 temiz (6100
kontrol), Samsung A36: GEÇTİ — normal TEST geçiş reklamı, bayat mola kurtarması (sahte + gerçek), arka plan / kayıp öne
dönüş / Vulkan onStart (L1-1), ödüllü D1–D3 (sahte ödül yok), sıklık politikası, TASK/049–051 korunması; logcat temiz,
QA kaldırıldı (§4.32). **TASK/053 (2026-10-05; Ayarlar / terminal sonuç sahipliği; masaüstü + Samsung A36 kapıları
GEÇTİ — kontrollü tam masaüstü kapısı 50 / 50 temiz; owner onayıyla ff-only alındı `5b7a727 → 275c537`):** kabul edilen
round bitişi ön planın sahibi — terminal temizlik açık Ayarlar'ı da kapatır, kesinleşen round'un board'u ekrandayken
Ayarlar açılmaz (`open_settings()` açılışı raporlar; HUD dişlisi yalnız açılışta dondurur), gizlenen Ayarlar eylem
üretmez; mutasyon 19 / 19, tam masaüstü kapısı 50 / 50 temiz (6228 kontrol), Samsung A36: GEÇTİ (bitişte açık Ayarlar
bitişte kapandı, beklemede gerçek dişli reddedildi, GERİ / meydan okuma / TASK/049–050 korunuyor; logcat temiz, QA
kaldırıldı) (§4.33). **TASK/054 (2026-10-05; Koleksiyon basılı dokunuş + Android GERİ; masaüstü + Samsung A36 kapıları
GEÇTİ — son tam masaüstü kapısı 51 / 51 temiz; owner onayıyla ff-only alındı `6a4a2b2 → 88c8570`):** pozitif dokunuş
sahipliği — Koleksiyon düğmesinin eylemi yalnız düğme ekrandayken ve basışın gerçek, iptal edilmemiş bırakışı görüldüyse
çalışır; gizlenen / odak kaybındaki basılı düğmenin basışı biter; X / karartma ACTION_CANCEL'da kapatmaz; taban farkı 59
→ 0 FAIL, mutasyon 25 / 25, tam masaüstü kapısı 51 / 51 temiz (son aday `db5542f`, üretim kodu `158022e` ile bayt-aynı:
6324 kontrol, 0 FAIL, 0 SCRIPT ERROR; ilk koşunun açığa çıkardığı, main'de de aynı olan `age_gate_test` tarih fikstürü
hatası yalnız-test düzeltmesiyle giderildi), Samsung A36: GEÇTİ (§4.34); Koleksiyon basılı dokunuş + Android GERİ bayat
bırakış sorunu KAPANDI (eski açık madde (4) — FIXED + MAIN).
**TASK/055 (2026-10-06; genel GUI ACTION_CANCEL; masaüstü + Samsung A36 kapıları GEÇTİ — kontrollü tam masaüstü kapısı
52 / 52 temiz; owner onayıyla ff-only alındı `60f8b71 → e0c1a71`):** `GestureGuard` sahiplik modeli — sonuç doğuran GUI
kontrolleri (ekonomi, ödül / reklam, seviye / round, kalıcı yazma, gezinme / pencere, HUD / güç, karartma / kapatma)
iptal edilen, bayat ya da geçersiz kılınan dokunuşta eylem üretmez; taban farkı 100 → 0 FAIL, mutasyon 45 / 45, tam
masaüstü kapısı 52 / 52 temiz (`7671882`: 6472 kontrol, 0 FAIL, 0 SCRIPT ERROR), Samsung A36: GEÇTİ (Mağaza onay SATIN
AL iptalinde Hamur değişimi 0, taze geçerli alım tam −180) (§4.35); genel GUI ACTION_CANCEL sorunu KAPANDI (eski açık
madde (5) — FIXED + MAIN).
**TASK/056 (2026-10-06; HUD hedef kartı T5 kırpması `Büyük Dumpl…`; masaüstü + Samsung A36 kapıları GEÇTİ —
kontrollü tam masaüstü kapısı 53 / 53 temiz; owner onayıyla ff-only alındı `a8bf454 → ee2778a`):** skor hedefi ad
satırından başlık satırına taşındı, ad 20 px'ten en az 16 px'e sınırlı sığdırma (çizilen metin, tam sayı genişlik, 2
px pay); kopya ve kart geometrisi aynı; taban farkı 141 → 0 FAIL, mutasyon 19 / 19 uygulanabilir ve 1 eşdeğer, tam
masaüstü kapısı 53 / 53 temiz (`0c0dc09`: 6800 kontrol, 0 FAIL, 0 SCRIPT ERROR), Samsung A36: GEÇTİ (L03 ve meydan
okuma T5 `Büyük Dumpling` tam; ürün dili Türkçe, EN / RTL yalnız-test vekilleri) (§4.36); T5 hedef kartı kırpması
KAPANDI (eski açık madde (6) — FIXED + MAIN). Bilinen, izlenen açık ürün maddesi: 0 (ürünün hatasız olduğu iddia
edilmez). Sonraki ürün / stabilizasyon görevi owner seçimi (TASK/057 oluşturulmadı). *(Sonra (2026-10-06): owner
Product Vision V3'ü başlattı — aşağıda TASK/057, tamam + main'de `84964af`.)*
**Product Vision V3 — AKTİF (2026-10-06; [GitHub Issue #1](https://github.com/oguzhanbilgi/Squishy-Merge/issues/1)):**
UI/UX yenileme + ödüllü güçler + görevler + başlangıç paketi + harita / meydan okuma yol haritası (TASK/057–065);
Release Readiness PAUSED / YELLOW. **TASK/057 (Squishy UI System V3 + küresel gezinme kabuğu) — TAMAM + MAIN
(COMPLETE + MAIN)** — owner / ChatGPT görsel onayı APPROVED (2026-10-07), owner onayıyla ff-only `d5237bf → 84964af`
(merge commit / rebase / squash / cherry-pick / force push yok; dal duruyor): mevcut `UiTokens` / `UiType` / `UiKit`
katmanının evrimi olan V3 temeli + beş hub ekranında küresel alt gezinme (tek candy-madalyon simge ailesi, oyun benzeri
seçili durum, tek parça tepsi, hub geri okları kaldırıldı, Android GERİ aynen); son üretim / test adayı `a126ace`
masaüstü tam kapısından (55 / 55, 7122 kontrol) ve gerçek Samsung A36 görsel kapısından + gerçek Google TEST banner
yerleşiminden GEÇTİ — hepsi entegrasyondan önce, entegrasyon ve doküman eşitlemesi sırasında yeniden koşulmadı (§4.37).
**TASK/058 Ana Sayfa V3 — TAMAM + MAIN** — owner görsel onayı APPROVED (2026-10-08; yalnız Ana Sayfa V3, K10 TEXT-LIGHT
kompakt GÜNLÜK | MEYDAN dahil), owner onayıyla ff-only `28a5bf1 → 7025bd4` (2026-10-08; merge commit / rebase / squash / cherry-pick / force push YOK; dal `task/058-home-v3` = `7025bd4` duruyor); son üretim / test adayı `9b4e2ed` masaüstü tam
kapısından (56 / 56, 7286 kontrol, 0 FAIL) ve gerçek Samsung A36 kapısından entegrasyondan ÖNCE geçti — entegrasyon ve doküman
eşitlemesi sırasında yeniden koşulmadı (§4.38) · TASK/059 BAŞLAMADI · Release PAUSED.
Release izi ayrı. Sırada: içerik derecesi + yargı bölgesi kararları + 13+ seçici uyum riski (owner) → gizlilik
politikası → upload anahtarı → gerçek AdMob kimlikleri → mağaza varlıkları / Play Console,
sonra ilk imzalı üretim AAB'si ve M10 (Play kapalı test) ·
**Branch / main:** `main` == origin/main ⊇ `7025bd4` (TASK/058 entegrasyon çapası) + `docs/058-main-sync` doküman
eşitlemesi — TASK/058 `task/058-home-v3` (main `28a5bf1`'den; 15 commit `c5d3bbc` … `9b4e2ed` son üretim / test adayı ·
`7025bd4` dal-aşaması doküman) owner onayıyla ff-only `28a5bf1 → 7025bd4` (2026-10-08; merge commit / rebase / squash / cherry-pick / force push YOK; dal `task/058-home-v3` = `7025bd4` duruyor) · önce TASK/057 doküman eşitlemesi
`docs/057-main-sync` ff-only (`84964af → 28a5bf1`, 2026-10-07) · önce TASK/057 `task/057-ui-system-v3-global-nav` (main `d5237bf`'ten
— `d5237bf` = TASK/056 doküman eşitlemesi; 12 commit `86bde6c` … `a126ace` son üretim / test adayı · `84964af` son
doküman; masaüstü + gerçek Samsung A36 görsel kapıları GEÇTİ 2026-10-07) owner / ChatGPT görsel onayıyla ff-only
entegre (`d5237bf → 84964af`, 2026-10-07; merge commit / rebase / squash / cherry-pick / force push yok; dal duruyor,
son incelenen HEAD `84964af`) · önce TASK/056 doküman eşitlemesi `docs/056-main-sync` owner onayıyla ff-only (`ee2778a →
d5237bf`, 2026-10-06; merge commit yok; dal duruyor) · önce TASK/056 `task/056-t5-target-card-truncation` (main
`a8bf454`'ten — `a8bf454` = TASK/055 doküman eşitlemesi; 4 commit: `721b97a` düzeltme · `c17fa4c` test · `0c0dc09`
inceleme sertleştirmesi (masaüstü kapısından ve Samsung A36'dan geçen son üretim / test adayı) · `ee2778a` doküman /
A36 kaydı (yalnız doküman); masaüstü + Samsung A36 kapıları GEÇTİ 2026-10-06) owner onayıyla ff-only entegre
(`a8bf454 → ee2778a`, 2026-10-06; merge commit / rebase / squash / cherry-pick / force push yok; dal duruyor, son
incelenen HEAD `ee2778a`) · önce TASK/055 doküman eşitlemesi `docs/055-main-sync` owner onayıyla ff-only (`e0c1a71 →
a8bf454`, 2026-10-06; merge commit yok; dal duruyor) · önce TASK/055 `task/055-gui-action-cancel` (main `60f8b71`'den —
`60f8b71` = TASK/054 doküman eşitlemesi; 5 commit: `1db02b6` düzeltme · `855d49a` test · `287781f` inceleme
sertleştirmesi · `7671882` gereksiz dal temizliği (masaüstü kapılarından ve Samsung A36'dan geçen son üretim / test
adayı) · `e0c1a71` doküman / A36 kaydı (yalnız doküman); masaüstü kapıları 2026-10-05, Samsung A36 2026-10-06 GEÇTİ)
owner onayıyla ff-only entegre (`60f8b71 → e0c1a71`, 2026-10-06; merge commit / rebase / squash / cherry-pick / force
push yok; dal duruyor, son incelenen HEAD `e0c1a71`) · önce TASK/054 doküman eşitlemesi `docs/054-main-sync` owner
onayıyla ff-only (`88c8570 → 60f8b71`, 2026-10-05; merge commit yok; dal duruyor) · önce TASK/054
`task/054-collection-hold-android-back` (main
`6a4a2b2`'den — `6a4a2b2` = TASK/053 doküman eşitlemesi; 9 commit: `e49293e` düzeltme · `ef08df1` + `6322101` test ·
`84770b3` inceleme sertleştirmesi · `3d4cb4a` + `158022e` test (A36 ve mutasyondan geçen üretim adayı) · `a5b3e35`
doküman / A36 kaydı · `db5542f` yalnız test (`age_gate_test` tarih fikstürü; son tam masaüstü kapısından geçen test
adayı) · `88c8570` doküman (yalnız doküman); masaüstü + Samsung A36 kapıları GEÇTİ 2026-10-05) owner onayıyla ff-only
entegre (`6a4a2b2 → 88c8570`, 2026-10-05; merge commit / rebase / squash / cherry-pick / force push yok; dal duruyor,
son incelenen HEAD `88c8570`) · önce TASK/053 doküman eşitlemesi `docs/053-main-sync` owner onayıyla ff-only (`275c537 →
6a4a2b2`, 2026-10-05; merge commit yok; dal duruyor) · önce TASK/053 `task/053-settings-terminal-ownership` (main
`5b7a727`'den — `5b7a727` = TASK/052 doküman eşitlemesi; 5 commit: `796e1e7` düzeltme · `4b29c26` test · `fd4f6e6`
inceleme sertleştirmesi · `be44ca4` test (kapılardan geçen üretim / test adayı) · `275c537` doküman / A36 kaydı (yalnız
doküman); masaüstü + Samsung A36 kapıları GEÇTİ 2026-10-04 / 05) owner onayıyla ff-only entegre (`5b7a727 → 275c537`,
2026-10-05; merge commit / rebase / squash / cherry-pick / force push yok; dal duruyor, son incelenen HEAD `275c537`) ·
önce TASK/052 doküman eşitlemesi `docs/052-main-sync` owner onayıyla ff-only (`c7e3ccc → 5b7a727`, 2026-10-04; merge
commit yok; dal duruyor) · önce TASK/052 `task/052-fullscreen-break-recovery-monetization` (main
`1d2fb28`'den, 10 commit: `635917b` düzeltme (kira) · `4649af1` politika (`AdPolicy`) · `5e3f707` + `6ec4f93` + `5de685d`
testler · `334422c` inceleme sertleştirmesi · `050ddac` testler · `41b194d` sertleştirme takibi · `e16da5a` testler
(kapılardan geçen üretim / test adayı) · `c7e3ccc` doküman / A36 kaydı (yalnız doküman); masaüstü + Samsung A36 kapıları
GEÇTİ 2026-10-04) owner onayıyla ff-only entegre (`1d2fb28 → c7e3ccc`, 2026-10-04; merge commit / rebase / squash /
cherry-pick / force push yok; dal duruyor, son incelenen HEAD `c7e3ccc`) · önce TASK/051 doküman eşitlemesi
`docs/051-main-sync` owner onayıyla ff-only (`4bae821 → 1d2fb28`, 2026-10-04; merge commit yok; dal duruyor) · önce
TASK/051 `task/051-start-level-touch-settle` (main
`1293eb2`'den, 6 commit: `abe05c1` düzeltme · `5b76a68` yeni suite · `aa14b4b` TASK/048 suite uyarlaması · `ec8d14c` +
`12ca7ba` suite sağlamlaştırması (yalnız test; `12ca7ba` kapılardan geçen üretim / test adayı) · `4bae821` doküman /
A36 kaydı (yalnız doküman); masaüstü + Samsung A36 kapıları GEÇTİ 2026-10-04) owner onayıyla ff-only entegre
(`1293eb2 → 4bae821`, 2026-10-04; merge commit / rebase / squash / cherry-pick / force push yok; dal duruyor, son
incelenen HEAD `4bae821`) · önce TASK/050 doküman eşitlemesi `docs/050-main-sync` owner onayıyla ff-only (`8f9e259 →
1293eb2`, 2026-10-03; merge commit yok; dal duruyor) · önce TASK/050 `task/050-daily-challenge-terminal-modal-ownership`
(main `c543cd1`'den, 4 commit: `43a528d` düzeltme · `9a02bd7` test · `537e8d8` inceleme sağlamlaştırması (yalnız test;
kapılardan geçen üretim adayı) · `8f9e259` doküman / A36 kaydı (yalnız doküman); masaüstü + Samsung A36 kapıları GEÇTİ
2026-10-03) owner onayıyla ff-only entegre (`c543cd1 → 8f9e259`, 2026-10-03; merge commit / rebase / squash /
cherry-pick / force push yok; dal duruyor, son incelenen HEAD `8f9e259`) · önce TASK/049 doküman eşitlemesi
`docs/049-main-sync` owner onayıyla ff-only (`f6cd072 → c543cd1`, 2026-10-03; merge commit yok; dal duruyor) · önce
TASK/049 `task/049-round-finish-modal-ownership` (main
`25860df`'den, 8 commit: `8a204bd` düzeltme · `acfb28e` test · `6a17162` TASK/048 suite uyarlaması · `7f46272`
sağlamlaştırma · `4649ae7` + `6d247c7` test · `db4564f` doküman / A36 kaydı (kapılardan geçen üretim adayı) ·
`f6cd072` final kabul kaydı (yalnız doküman); A36 GEÇTİ + final kabul GEÇTİ 2026-10-03) owner onayıyla ff-only entegre
(`25860df → f6cd072`, 2026-10-03; merge commit / rebase / squash / cherry-pick / force push yok; dal duruyor, son
incelenen HEAD `f6cd072`) · önce TASK/048 doküman eşitlemesi `docs/048-main-sync` owner onayıyla ff-only (`b9ae345 →
25860df`, 2026-10-03; merge commit yok; dal duruyor) · önce TASK/048 `task/048-result-delay-race-guard` (main
`848797a`'dan, 11 commit: `c58c88d` düzeltme · `9ab9917` test · `83dc208` nesil sırası · `2592a1b` test
sağlamlaştırma · `0f6996d` doküman / A36 kaydı · son engel `3633d6a` düzeltme · `8157b56` + `f5d005a` + `1b5b300`
test · `441a114` yorum · `b9ae345` doküman / hedefli A36 kaydı; A36 GEÇTİ 2026-10-02) owner onayıyla ff-only entegre
(`848797a → b9ae345`, 2026-10-02; merge commit / rebase / squash / cherry-pick / force push yok; dal duruyor, son
incelenen HEAD `b9ae345`) · önce TASK/047 doküman eşitlemesi `docs/047-main-sync` owner onayıyla ff-only (`aa6f867 →
848797a`, 2026-10-02; merge commit yok; dal duruyor) · önce TASK/047 `task/047-daily-merge-challenge`
(main `6d3dbca`'dan, 10 commit: `befbbbd` model + kayıt · `bf553e0` board · `201764d` akış + yalıtım ·
`e805736` arayüz + sonuçlar · `54e8411` + `e002dff` inceleme düzeltmeleri · `743e5d7` kapı / doküman ·
`7395280` A36 kapısı kaydı · `f8c8ffb` monoton gün · `aa6f867` monoton gün doküman / hedefli A36 kaydı;
A36 GEÇTİ 2026-10-02, hedefli monoton gün kapısı dahil) owner onayıyla ff-only entegre (`6d3dbca →
aa6f867`, 2026-10-02; merge commit / rebase / squash / cherry-pick / force push yok; dal duruyor, son
incelenen HEAD `aa6f867`) · önce TASK/046.2
`task/046-2-action-cancel-drop-guard` (`471a2ab` · `2149fc3` · `b364a0c` · `6d3dbca` doküman / A36 kapısı
kaydı) owner onayıyla ff-only entegre (`afc10be → 6d3dbca`, 2026-10-01; merge commit yok; dal duruyor) ·
önce `afc10be` (`b90bc3c` üstünde yalnız doküman eşitlemesi) — TASK/046 `task/046-daily-weekly-missions`
(`efb9763` … `5092dad`, 4 commit) + TASK/046.1 `task/046-1-age-gate-13plus-redesign` (`bc40da1` …
`b90bc3c`, 5 commit) owner onayıyla BİRLİKTE ff-only entegre (`56106ef → b90bc3c`, 2026-09-30;
merge commit / rebase / squash / cherry-pick yok; dallar duruyor) · önce TASK/045.2 `task/045-2-settings-back-input-focus` (`c990b63` + `a32ee2d`)
owner onayıyla ff-only entegre (`e474fb3 → a32ee2d`, 2026-09-29; A36 kapısı geçti, düzeltme
commit'i yok) · önce TASK/045.1 `task/045-1-persistence-input-hardening` (`aac0895` …
`5b1f952`, 8 commit; son commit A36 kapısı düzeltmesi) owner onayıyla ff-only entegre
(`017f2dc → 5b1f952`, 2026-09-29) · önce TASK/045 `task/045-player-level-achievements` (`514ec9a` + `285856c` +
`d4c8548`) owner onayıyla ff-only entegre (`115252c → d4c8548`, 2026-09-28) · önce TASK/044
`task/044-player-meta-v1` (`d2832dc` + `e6c1c07` + `c5b4db5` +
`239f2e7`) owner onayıyla ff-only entegre (`327dd60 → 239f2e7`, 2026-09-28) · önce TASK/043
`task/043-age-band-routing` (`b0e69f0` + `753503a`) owner onayıyla ff-only entegre ·
`main` == origin/main — `task/042-gma25-production` (`83b86a9` kod + `3d15402`
A36 kapısı / doküman kaydı) ff-only alındı (2026-09-27, owner onayıyla; ağaç eşit); önce
aynı gün `task/041-fix-request-configuration` (`7e1e378` + `d32a4d3`) ve
`task/040-global-teen-compliance` (`025214a` + `e152986`, TASK/040 fizibilite denetimi +
spike araçları)

> Güncel engel listesi ve sıradaki adımın kanonik yeri: `PROJECT_CONTEXT.md` →
> Current state / Current release blockers / Next action. Aşağıdaki tarihçe
> ve §7–§8 yazıldıkları anın durumunu anlatır; oradaki bazı "açık" maddeler
> sonraki milestone'larda kapandı.

---

## Bu dosya ne işe yarıyor

Bu, projenin **anlatı hâlindeki tam tarihçesi**: ne yapıldı, hangi kararlar
alındı, **neden** öyle karar verildi, ne ölçüldü ve ne ölçülmedi. Hedef, bu
dosyayı okuyan yeni bir geliştiricinin (insan ya da AI) projeye sıfırdan
hakim olabilmesi.

Diğer dokümanlarla ilişkisi — **bu dosya hiçbirinin yerine geçmiyor:**

| dosya | rolü |
|---|---|
| `PROJECT_CONTEXT.md` | **Kısa ve güncel durum.** Kapsam, non-goal'lar, blokajlar, sıradaki iş. Hızlı bakış için önce burası. |
| `GAME_DESIGN.md` | **Kilitli tasarım spec'i.** Sayılar ve kurallar burada; owner onayı olmadan değişmez. Çelişki olursa **GAME_DESIGN kazanır**, bu dosya değil. |
| `CLAUDE.md` | Çalışma disiplini, Godot sürüm uyarısı, git akışı. |
| `DEVLOG.md` | Milestone başına tek satır, kronolojik ham kayıt. |
| `assets/visual/CREDITS.md` | Görsel asset'lerin kaynağı ve teknik detayı (uzun, çok değerli). |
| `assets/audio/CREDITS.md` | Ses asset'lerinin kaynağı. |
| **`PROJECT_STATUS.md`** | **Bu dosya.** Tarihçe + gerekçeler + envanter + kalan işler. |

> **Öncelik sırası (CLAUDE.md'den):** owner'ın en son açık talimatı >
> `GAME_DESIGN.md` (kilitli sayılar) > `PROJECT_CONTEXT.md` (durum) >
> `PROJECT_STATUS.md` / `DEVLOG.md` (tarihçe, otorite değil) >
> `OWNER_WORKING_PROFILE.md`.
>
> Yani **bu dosya kural koymaz.** Buradaki bir cümle kilitli bir sayıyla
> çelişirse GAME_DESIGN ve kod kazanır.

---

## 1. Proje konsepti ve hedef kitle

**Squishy Merge**, fizik tabanlı (Suika Game / watermelon-game tarzı) bir
dumpling birleştirme oyunu. Üstten kaba düşen dumpling'ler aynı tier'da
çarpışınca birleşip bir üst tier'a evriliyor.

- **Tema:** sevimli/kawaii squishy dumpling karakterleri, ASMR/rahatlatıcı his
- **Yapı:** 10 sabit level + level 10 sonrası açılan sonsuz mod
- **Platform:** Android (Google Play), portrait, 720×1280 viewport
- **Oturum:** 30-90 saniyelik kısa round'lar

**Hedef kitle:** casual mobil oyun oynayan geniş kitle; özellikle merge/idle/
ASMR-cozy oyun sevenler, kısa oturumları tercih edenler. **Owner kararı
(2026-09-25, FİNAL): 13+ genel kitle** — 13 yaş altı çocuklar için tasarlanmadı
ve onlara pazarlanmaz; Play hedef yaş grupları 13–15 / 16–17 / 18+
(docs/monetization/AUDIENCE_DECISION.md §0).

**Çözmeye çalıştığı boşluk:** mevcut merge oyunlarının çoğu ya karmaşık
grid-tabanlı sistemler (fazla UI/kural) ya da zayıf duyusal geri bildirim
sunuyor. Squishy Merge basit fizik + güçlü duyusal tatmin (squash-stretch,
escalating ses, combo efekti) + net/kısa level ilerlemesi ile bu boşluğu
hedefliyor.

### İş modeli

> **Güncellendi (M8.9, 2026-09-21).** Eski "v1 reklamsız, ödüllü reklam
> v1.1'de" cümlesi ARTIK GEÇERSİZ.

- **v1 (soft-launch öncesi plan):** ödüllü devam (revive) + ödüllü güç
  refill'i + banner (Ana Sayfa / Harita / Mağaza / Koleksiyon / oyun) +
  **geçiş reklamı** (TASK/052'den beri main'de: önceki gerçek gösterimden bu
  yana 2 kesinleşen normal round + 300 aktif sn — önce 15 dk; yalnız round
  bitişi molası, 60 sn bekleme) + **günlük ödüller** (ücretsiz sandık 1/gün, reklamlı sandık 2/gün,
  reklamlı +150 Hamur 1/gün) — Google AdMob, `M8.9-01` ve `M8.9-02` **ikisi de
  main'de** (33b6382 / 9561a4c) ve Samsung A36'da TEST reklamlarıyla doğrulandı
  (docs/monetization/); üretim kimlikleri/hesap kurulumu ayrı adım. App-open
  / rewarded interstitial / mediation yok. IAP / Play Billing hâlâ yok.
- **v1'de oyun içi mağaza VAR** ama gerçek para geçmiyor — "Hamur" adlı soft
  currency ile kozmetik skin alınıyor. Bu bir para sink'i, IAP değil.
- **Sonra:** gerçek para Güç Paketi (GAME_DESIGN §5.7.4, billing yok),
  muhtemel kozmetik IAP — gerçek kullanıcı verisiyle.

### Başarı ölçütü

v1 için başarı = **Play Console kapalı test track'inde canlı, crash'siz, tam
oynanabilir bir build.** Ticari/growth kararları v1.1'de gerçek veriyle
alınacak; şimdi tahmin veya vaat yok.

### Non-goal'lar (v1'de bilinçli olarak YAPILMIYOR)

Çoklu kavanoz/tema · IAP/ödeme (Billing) · **app-open / rewarded interstitial
reklam, mediation, analitik SDK** (ödüllü + banner + interstitial + günlük
ödüller M8.9'da v1'e alındı) · native haptik plugin
(yerleşik titreşim M8.5-15'te v1'e alındı) · leaderboard ·
bulut kayıt · hesap sistemi · backend/sunucu · **otomatik test framework'ü
(GUT vb.)** · iOS build.

> Otomatik test framework'ü bilinçli bir non-goal: bu ölçekte
> disproportionate overhead. Yerine **manuel playtest checklist**
> (GAME_DESIGN §9) ve **headless bot simülasyonu** (`tools/bot_runner.gd`)
> kullanılıyor. Bot, denge ölçümü için gerçek fizikle gerçek `GameBoard`
> oynatıyor — bu projede "test" denince kastedilen şey büyük ölçüde budur.

---

## 2. Teknoloji ve ortam

| | |
|---|---|
| Motor | **Godot 4.6.3-stable**, GDScript |
| Render | Mobile renderer, D3D12 (Windows) |
| Fizik | Godot 2D fizik, `RigidBody2D`, yerçekimi 1200 |
| Viewport | 720×1280, `canvas_items` stretch, `expand` aspect, portrait kilitli |
| Hedef | Android → Google Play (Play App Signing, AAB) |
| Repo | https://github.com/oguzhanbilgi/Squishy-Merge |
| Yerel yol | Makineye göre değişir (ev: `C:\dev\squishy-merge`, iş: `D:\dev\squishy-merge`) — **sabit yol varsayma** |

### ⚠️ Godot sürümü — kritik uyarı

Projeyi **SADECE 4.6.3** ile aç. İş makinesinde kanonik kopya:
`C:\Users\ledaj\AppData\Local\Godot463\Godot_v4.6.3-stable_win64.exe`

Başka bir Godot kurulumuyla açmak `project.godot`'u **sessizce 4.7'ye
çeviriyor** (`config/features` yeniden yazılıyor) ve o sürümün export
template'leri 4.6.3 ile uyumsuz olduğu için Android export'u bozuyor.
**Bu iki makinede de birer kez oldu** (M7'de yakalandı).

- **Belirti:** `git diff project.godot` içinde
  `config/features=PackedStringArray("4.7", ...)`
- **Çözüm:** `git checkout -- project.godot`, doğru binary ile tekrar aç

### Ortam durumu (2026-09-09'da iş makinesinde doğrulandı)

| bileşen | durum |
|---|---|
| Godot 4.6.3 | ✅ `4.6.3.stable.official.7d41c59c4` |
| Export template'leri | ✅ `4.6.3.stable` kurulu (`android_debug.apk`, `android_release.apk`, `android_source.zip`). `4.7.2.stable` seti de duruyor, zararsız. |
| Android SDK | ✅ `%LOCALAPPDATA%\Android\Sdk` — platform-tools, build-tools 36.0.0/36.1.0/37.0.0, platforms android-34/35/36/36.1, ndk 28.2.13676358, cmdline-tools |
| JDK | ✅ Godot **JDK 17**'yi kullanıyor (`C:\Program Files\Microsoft\jdk-17.0.16.8-hotspot`, editor settings'te tanımlı) |
| Debug keystore | ✅ `%APPDATA%\Godot\keystores\debug.keystore` |
| `ANDROID_HOME` / `ANDROID_SDK_ROOT` | ⚠️ **boş** — ama sorun değil, Godot yolu kendi editor settings'inden okuyor |
| PATH'teki `java` | ⚠️ Java **26** — Godot bunu kullanmadığı için çakışma yok |
| `export_presets.cfg` | ❌ **yok** (gitignore'lu, M9'da oluşturulacak) |
| Release/upload keystore | ❌ **yok** (sadece debug var) |

---

## 3. Milestone tarihçesi — M0'dan M8'e

Kaynak: `DEVLOG.md` + commit geçmişi + `GAME_DESIGN.md` içindeki karar
notları.

### M0 — Ortam ve iskelet (2026-09-05)

Ortam doğrulandı, proje iskeleti kuruldu: klasör yapısı, `main.tscn`, üç
autoload (`GameState` / `AudioManager` / `SaveManager`), mobil portrait
ayarları.

- **İlk blokaj:** dokümanlar Godot 4.7.2 diyordu, kurulu olan 4.6.3'tü.
  4.6.3'te karar kılındı, tüm doküman referansları düzeltildi.
- Export template'leri (4.6.3.stable) kuruldu, debug keystore oluşturuldu.

### M1 — Çekirdek fizik ve merge (2026-09-05)

8 tier config, `RigidBody2D` dumpling, drag-drop kontrolü, merge +
squash-stretch + pop efekti, tier 8 kutlaması, 1.5 sn taşma fail state.

**Ölçümle alınan kararlar:**

- **Oynanabilir yükseklik 880 → 400 px.** 880'de kap taşmıyordu, round
  bitmiyordu. 400 px'te ~11-12 adet tier 5 ile taşma oluyor — gerilim var
  ama adaletsiz değil. Bu değer o günden beri **tüm level'larda sabit**.
- **Squash-stretch çarpma hızına orantılı** (0.08-0.25 sapma, ~120 ms,
  130 ms debounce). İlk deneme (0.05-0.2) owner'a "cansız" geldi.
- **Duvar ve tabana da `PhysicsMaterial`** verildi (bounce 0.13, efektif
  ~0.24). Yoksa yalnızca dumpling-dumpling çarpışmaları zıplıyordu ve kap
  ölü hissettiriyordu.
- **Gövde fizikte serbest döner** — bu M1'de kilitlendi ve hâlâ geçerli.

**O zamanki açık sorun:** tier yarıçapları kaba göre küçüktü; M2'ye
devredildi (ve asıl olarak M8'de çözüldü).

### M2 — Level sistemi ve ilk balans (2026-09-05)

Level datası **data-driven** hâle geldi: `.tres` Resource'lar, klasör
tarayan `LevelLibrary`. Kod değiştirmeden yeni level eklenebiliyor. 10 level
+ sonsuz mod, level seçim ve sonuç ekranları.

- **Kap genişlikleri ölçümle belirlendi:** 600 / 540 / 480 / 420 / 370.
- **Merge puan tablosu kilitlendi:** tier 2:50, 3:70, 4:90, 5:110, 6:130,
  7:150, 8:200.
  **Neden:** önceki tablo (30/40/50/60/70/80/100) tier 8'de sadece ~2630
  puan veriyordu ve level 10'un "skor ≥ 5000" hedefini pratikte imkânsız
  kılıyordu. Yeni tabloyla tier 8'e ulaşan oyuncunun skoru medyan ~4740
  (p5 4360 / p95 5150) — hedefe 2-3 merge kalıyor, yani hedef anlamlı ama
  ikinci bir yığın kurmayı gerektirmiyor.

### M3 — Sandık, skin kataloğu, yıldızlar (2026-09-05)

Rarity kurası (60/25/12/3, **20.000 kurada doğrulandı**), 20 skinlik
data-driven katalog, duplicate→Hamur dedupe (bu kural M8.5'te değişti,
bkz. §4.8), her 75 merge'de bonus sandık,
teselli ödülü, gecikmeli yıldız + sandık reveal animasyonu.

**Yıldız formülü iki kez değişti:**

1. Önce deterministik çarpanlar (minimum × 1.15 / × 1.35).
2. Sonra **percentile tabanına** çevrildi: 2★ = p50, 3★ = p85.
   Dağılım Monte Carlo ile üretiliyor (`tools/star_thresholds.py`, 40.000
   örnek). **Neden geçerli:** bir tier'a ulaşmak için gereken merge sayısı
   oyuncu becerisinden bağımsız; beceri sadece hayatta kalıp kalmadığını
   belirliyor. Dolayısıyla "hedefe ulaşıldığı andaki skor" dağılımı
   simülasyonla doğru çıkıyor.

### M4 — Koleksiyon albümü (2026-09-05)

20 skinlik grid, açılmamışlar silüet, rarity çerçevesi, Hamur/ilerleme
sayacı.

### M5 — Günlük döngü (2026-09-05)

Günlük giriş ödülü (15 Hamur, sabit) + ardışık gün sayacı. Seri kırılırsa
sıfırlanıyor ve oyuncuya söyleniyor. **Cihaz saati geriye alınırsa ödül
verilmiyor** (basit exploit koruması).

### M6 — Ses (2026-09-06)

Kenney.nl CC0 placeholder SFX (7 dosya), Master → SFX/Music bus yapısı,
`AudioManager` kimlik tabanlı çalmaya geçti, combo zinciri ve danger sesi.

- **Tier başına pitch escalation tek sample üzerinden** yapılıyor, tier
  başına ayrı dosya yok.
- **Dosya isimleri sabit** — owner kendi seslerini aynı isimle üzerine
  yazarsa kod hiç değişmiyor.
- **Blokaj:** kazanma/kaybetme jingle seçimi kulakla doğrulanamadı (ortamda
  ses çözücü yok).

### M7 — İlk görsel geçiş (2026-09-07)

Kenney CC0 placeholder görselleri: tek gövde+yüz sprite'ı 8 tier'a
`TierConfig` paletiyle tint'lenerek uygulandı, UI Pack 9-patch teması 4
ekrana bağlandı, yıldızlar metin karakterinden sprite'a geçti.

- **Bu turda Godot 4.7.2 kazası oldu:** proje yanlışlıkla 4.7.2 ile açıldı,
  `project.godot` 4.7'ye çevrildi. Geri alındı ve `CLAUDE.md`'ye kalıcı
  uyarı eklendi.

### M8 — Büyük balans + juice + owner asset'leri (2026-09-08/09)

Projenin en yoğun milestone'u. Sırayla:

**a) Tier geometrisi yeniden ölçüldü.** Eski merdiven
(22/30/40/52/66/84/106/132) L9-L10'u fiilen kazanılamaz kılıyordu: headless
bot en dar kapta **20 koşuda tier 8'e bir kez bile ulaşamadı** (0/20).
Yalnızca tier 7-8'i küçültmek yetmedi (en iyi 2/20) — tepe doluluk tier 5-6
artıklarından da besleniyordu, o yüzden **merdivenin tamamı** yeniden
ölçeklendi: 22/27/34/42/52/65/81/100, büyüme oranı 1.26 → **1.241**.
Merge puan tablosuna dokunulmadı (skor modeli geometriden bağımsız), yıldız
eşikleri de geçerliliğini korudu.

**b) Juice/polish pası** (Kenney Particle Pack CC0): tier'a ölçekli merge
patlaması, kamera sarsıntısı, sprite parlama overlay'i, arka plan bokeh'i,
skor "+N" pop'u, sandık ışık patlaması, danger highlight'ı.

**c) Süre limiti tamamen kaldırıldı** (owner kararı) — aşağıda "Kilitli
kararlar"a bakın.

**d) UI teması** Kenney'den **Wenrexa "UI Casual Game Interface"** (CC0)
paketine geçti: camgöbeği aksan + koyu panel, 5 durumlu buton, sandık kartı
için `CardPanel` varyantı.

**e) Zorluk ayarı:** L4 tier 5→6, L6 tier 6→7, L8'e skor eşiği (6750).
Ölçüm **hedef tier artışının işe yaramadığını** gösterdi (L4/L6 hâlâ
%97/%100) — asıl kaldıraç kap genişliği ve skor eşiği.

**f) Tier paleti doygunlaştırıldı** ("candy" hedefi, hue sabit, saturation
+0.22). Sonra tier 1 bir tık daha açıldı (`#ffc368` → `#ffd08a`): 44 px
çapta gövde gradyanı yüzünden çamurlu okunuyordu.

**g) Owner'ın 8 dumpling karakteri** entegre edildi (ChatGPT üretimi).
Tint kaldırıldı, ayrı yüz katmanı ve parlama overlay'i kaldırıldı (ikisi de
sprite'a gömülü).

**h) Drop havuzu bag randomizer'a çevrildi** — aşağıda.

**i) Sonsuz mod:** tier 8 annihilation + kap genişliği 600 → 720.

**j) Mağaza + alt sekme navigasyonu:** Ana Sayfa / Harita / Koleksiyon /
Mağaza.

**k) Owner'ın 9 UI asset'i** (harita zemini, logo, kilitli skin silueti,
tehlike şeridi, rozet, banner, tutorial pozu, 2 adaptive icon katmanı).

**l) `icon_sheet.png`'den 7 HUD ikonu** kesildi ve bağlandı.

---

## 4. Kilitli tasarım kararları ve gerekçeleri

> Bunlar `GAME_DESIGN.md`'de kilitli. Değiştirmeden önce owner'a sor.

### 4.1 Tier merdiveni: 22/27/34/42/52/65/81/100

Sabit büyüme oranı **1.241**. Oran her adımda sabit olduğu için boyut farkı
gözle net okunuyor.

**Neden bu değerler:** en dar kap (370 px) tier 8'in 200 px çapına 170 px,
iki tier-7'nin yan yana 324 px'ine 46 px pay bırakıyor. Eski merdivende bu
paylar 106 px ve **−54 px** idi (yani sığmıyordu).

**Doğrulama yöntemi:** `tools/tier_geometry.py` alan modeliyle adayları
daraltıyor, ardından `tools/bot_runner.gd` gerçek fizikle karar veriyor.
Sonuç: L10 %40 (16/40), L9 %50 (15/30) — süre limiti kaldırılınca ikisi de
%43'e oturdu.

### 4.2 Süre/hamle limiti YOK — tek fail state taşma

**Owner kararı, M8. Tekrar sorulmasına gerek yok.**

Süre limiti konseptin "rahatlatıcı/ASMR" pozisyonuyla çelişiyordu.
`LevelData.time_limit` alanı, saat UI'ı ve süre dolunca kaybetme yolu
tamamen silindi.

**Ölçüm ne dedi:** limitler zaten pratikte bağlayıcı değildi. Kaldırmadan
önce/sonra bot sonuçları L9 %50→%43, L10 %40→%43 — fark gürültü içinde.
Koşular saat dolmadan çok önce taşmayla bitiyordu. Yani bu değişiklik
zorluğu değil, oyunun **hissini** değiştirdi.

### 4.3 Zorluğun asıl kaldıracı: kap genişliği ve skor eşiği

M8'in en önemli ölçüm bulgusu. Bot kazanma oranları:

| level | kap | hedef | kazanma |
|---|---|---|---|
| 4 | 540 | tier 6 | %97 (n=30) |
| 5 | 480 | tier 6 | %100 (n=30) |
| 6 | 480 | tier 7 | %100 (n=30) |
| 7 | 420 | tier 7 | %97 (n=30) |
| 8 | 420 | tier 7 + 6750 skor | **%70 (n=60)** |
| 9 | 420 | tier 8 | %43 (n=30) |
| 10 | 370 | tier 8 + 5000 skor | %43 (n=30) |

Hedef tier'ı artırmak L4/L6'da neredeyse hiçbir şeyi değiştirmedi. Süre
baskısı olmayan geniş kapta bot hedef tier 5 de olsa 7 de olsa kazanıyor.
L8'deki sıçrama (%97 → %70) tek etkili kaldıracın **skor eşiği** olduğunu
gösteriyor.

**L1-L7'nin kolay kalması bilinçli** (owner kararı): giriş/ısınma
level'ları, kolay olmaları rahatlatıcı konseptle tutarlı. Asıl zorluk
L8-L10'da. **Kap genişliği zorluk kaldıracı olarak kullanılmayacak.**

### 4.4 Bag randomizer (torba) — bağımsız rastgele DEĞİL

Owner L9/L10'u bitirdi ama **"adil hissetmedi"** dedi. Kök sebep: her drop
bağımsız uniform çekiliyordu, bu da oyuncunun elinden bağımsız şanssız
seriler üretiyordu.

Ölçüm (80 drop'luk round, 200.000 deneme) — en uzun aynı-tier serisi:

| model | medyan | p95 | max | 5+ seri içeren round |
|---|---|---|---|---|
| bağımsız uniform (eski) | 4 | 7 | 16 | **%48** |
| torba, tier başına 3 kopya | 3 | 4 | 6 | **%4.3** |

Kompozisyon adaleti de düzeldi: 80 drop'ta bir tier'i görme sayısı bağımsızda
p5-p95 = 20-34 iken torbada 26-27 (ideal 26.7).

**Torba:** tier 1/2/3'ten üçer kopya = 9 parça, karılır, sırayla çekilir,
boşalınca yeniden doldurulur. Round başına yeni torba.

**Neden 3 kopya, 2 değil:** 2 kopya 5+ serileri tamamen siler ama
"iki tane gördüm, üçüncüsü gelmez" diye tahmin edilebilir hâle geliyor.

**Bot kazanma oranlarında belirgin değişim YOK** — beklenen, çünkü torba
şanssız serilerle birlikte şanslı serileri de siliyor. Kazanım **algılanan
adalette** ve bot bunu ölçemiyor.

### 4.5 Tier 8 annihilation — YALNIZCA sonsuz modda

Sonsuz modda iki tier 8 çarpışınca **ikisi de yok olur**: büyük patlama,
güçlü sarsıntı, **+600 puan**, combo sayacına normal merge gibi katkı.

**Neden gerekli:** tier 8'ler birikip yer açmıyordu, oturum erken bitiyordu.

**Neden 600:** oyundaki en büyük tek seferlik ödül tier 8 oluşması (200)
idi; annihilation bunun 3 katı olarak açık ara en büyük ödül ama tipik bir
oturumun toplam skoru (~13.000) içinde baskın hâle gelmiyor.

**Level modunda bu kural YOK.** §1'deki "tier 8 oluşunca round otomatik
bitmez, parça normal parça gibi kalır" kararı level'larda aynen geçerli;
orada tier 8'ler birikmeye devam eder ve taşma riskinin parçası olur.
Ayrım `LevelData.is_endless` → `Dumpling.annihilates_at_max`.

**Ölçüm — beklenen etkiyi TAM vermiyor** (bot, sonsuz mod, n=24):

| | kapalı | açık |
|---|---|---|
| süre medyan | 68 sn | 65 sn |
| süre **p90** | 87 sn | **119 sn** |
| merge p90 | 194 | 265 |
| skor p90 | 16.760 | 23.540 |

Yani annihilation **tipik oturumu uzatmıyor**, üst dilimi belirgin biçimde
uzatıyor.

### 4.6 Sonsuz mod kap genişliği 720 — level genişliklerinden bağımsız

Annihilation tek başına tipik oturumu uzatmıyordu; **genişlik medyanı
hareket ettiren kaldıraç** çıktı (medyan süre 72→91 sn, merge 153→199,
n=20). Etki 720'de doyuyor (780/800 ek katkı vermiyor).

**Bedeli kabul edildi (owner):** viewport 720 px olduğu için sonsuz modda
yan duvarlar ekran dışında kalıyor. Taban, taşma çizgisi ve danger bandı
görünür kalıyor; level modu etkilenmiyor.

**Elenen iki alternatif:** 680'e düşmek (kazancın sadece üçte birini
veriyor) ve kamerayı %5 uzaklaştırmak (dokunmatik nişan koordinatlarının da
dönüştürülmesi gerekiyordu; headless bot girdi yolunu hiç kullanmadığı için
—doğrudan `_set_aim` çağırıyor— eklenecek düzeltme otomatik doğrulanamazdı).

### 4.7 Yıldız eşikleri — percentile tabanlı

2★ = p50, 3★ = p85, hedef tier'a ulaşıldığı andaki skor dağılımından:

| hedef tier | 2★ (p50) | 3★ (p85) |
|---|---|---|
| 4 | 160 | 210 |
| 5 | 430 | 530 |
| 6 | 1040 | 1190 |
| 7 | 2260 | 2430 |
| 8 | 4730 | 4990 |

Eşikler `TierConfig.SCORE_P50` / `SCORE_P85` dizilerinde **sabit** duruyor —
percentile kapalı formülle çıkmadığı için koddan hesaplanamıyor.
**Merge puan tablosu değişirse `tools/star_thresholds.py` tekrar
çalıştırılıp bu diziler güncellenmeli.**

**Bilinen istisna (kasıtlı):** L8 ve L10'un bitirme koşulundaki skor eşiği,
3★ eşiğinin çok üstünde. Yani **bu iki level'ı bitirmek her zaman 3★
veriyor.** Formüle istisna eklenmedi; ikisi de skor biriktirmeyi gerektiren
level'lar ve bitirmek başlı başına üst düzey başarı sayılıyor.

### 4.8 Sandık ve mağaza ekonomisi

**Sandık (kilitli, owner onaylı):**

- Her level tamamlanışında 1 sandık + her 75 merge'de bonus sandık
- Rarity: Common %60 / Rare %25 / Epic %12 / Legendary %3
  (20.000 kurada doğrulandı)
- İçerik: kozmetik skin **veya** Hamur. Duplicate skin otomatik Hamur'a
  çevrilir: 10/25/60/150 (rarity'e göre). Teselli ödülü 5 Hamur.
- Günlük giriş ödülü: 15 Hamur

**Mağaza fiyatları** (`scripts/game/shop.gd` → `PRICES`, tune edilebilir tek yer):

| rarity | fiyat | adet | toplam |
|---|---|---|---|
| Common | 50 | 8 | 400 |
| Rare | 150 | 6 | 900 |
| Epic | 400 | 4 | 1600 |
| Legendary | 900 | 2 | 1800 |
| | | **20** | **4700 Hamur** |

> ### ⚠️ AÇIK DENGE SORUNU — geç oyun Hamur enflasyonu (M8.5'te güncellendi)
>
> **M8'deki sorun çözüldü.** O zamanki kural "sandık, o rarity'de açılmamış
> skin varsa her zaman skin verir" idi ve mağaza **hiçbir şey satmıyordu**
> (üç senaryoda da 30. günde satın alınan: 0). M8.5'te sandık ödül tipi
> açık bir **%30 skin / %70 Hamur** rulesine çevrildi (GAME_DESIGN §5.2).
>
> Yeni ölçüm (`tools/shop_economy.py`, 5000 deneme/senaryo, Monte Carlo —
> sonuçlar yaklaşıktır):
>
> | oyuncu | 20/20 (p25 / medyan / p75) | 30. günde mağazadan alınan | 30. günde artan Hamur |
> |---|---|---|---|
> | kasual (3 round/gün) | 14 / **17** / 20. gün | 11 / 20 | 2.610 |
> | orta (5 round/gün) | 9 / **11** / 12. gün | 10 / 20 | 6.115 |
> | yoğun (10 round/gün) | 5 / **6** / 6. gün | 9 / 20 | 14.815 |
>
> **Mağaza artık çalışıyor** — medyan oyuncu koleksiyonun yaklaşık yarısını
> satın alıyor. Ama iki sorun kaldı:
>
> 1. **Koleksiyon hâlâ hızlı doluyor** — üç senaryoda da 30 gün içinde
>    tamamlanma %100; yoğun oyuncu 6 günde bitiriyor.
> 2. **Tamamlandıktan sonra Hamur'un alıcısı yok.** Tek sink mağaza ve o da
>    yalnızca 20 skin satıyor. Koleksiyonun tamamı 4.700 Hamur; yoğun oyuncu
>    30. günde bunun üç katından fazlasını biriktiriyor.
>
> Çözüm alternatifleri (skin sayısı, fiyat, gelir, ikinci sink) **owner
> kararı**. M8.5'te hiçbir fiyat veya gelir kaynağı değiştirilmedi.

> ### ✅ ÇÖZÜLDÜ — ikinci sink eklendi (M8.5-05)
>
> Yukarıdaki iki sorundan **ikincisi** (Hamur'un alıcısı yok) çözüldü:
> dört güç artık Hamur ile satın alınabiliyor (GAME_DESIGN §5.7). Bu,
> oyunun ilk **tekrarlanabilir** sink'i — skin bir kez alınır ve biter,
> güç tükenir.
>
> **Skin fiyatlarına, sandık oranlarına ve Hamur gelir kaynaklarına
> DOKUNULMADI.** Birinci sorun (koleksiyon hızlı doluyor) hâlâ owner
> kararına açık; güç sink'i onu yalnızca 1-4 gün geciktiriyor.
>
> **Seçilen güç fiyatları:** Sarsıntı 100 · Bomba 120 · Temizleyici 160 ·
> Büyütücü 180 (`scripts/game/power_up_economy.gd` → `DOUGH_PRICES`).
>
> Fiyatın **şekli** gameplay değerinden türetildi (Büyütücü en pahalı: level
> tier hedefini doğrudan karşılayabilen tek güç). Fiyatın **seviyesi**
> tarandı (taban 80→200, `python tools/shop_economy.py sweep`).
>
> **Neden taban 120:** 140 ve üstü daha fazla Hamur EMMİYOR — güce giden
> Hamur 16.200'de doyuyor, artan tek şey karşılanmayan istek sayısı
> (27 → 42 → 71). Pahalıya kaçmanın ekonomik getirisi yok.
>
> #### Yeni ölçüm (`tools/shop_economy.py`, 4000 deneme/senaryo, 90 gün)
>
> ⚠️ **Güç kullanım sıklıkları VARSAYIM** — gerçek telemetry yok. Üç profil:
> düşük (~her 5-6 roundda 1), orta (~her 3-4 roundda 1), yüksek (~her 2
> roundda 1). Gerçek veri gelince yeniden kalibre edilmeli.
>
> **Kalan Hamur medyanı — enflasyon:**
>
> | oyuncu | | gün 30 | gün 60 | gün 90 |
> |---|---|---|---|---|
> | kasual (3/gün) | sink yok | 2.615 | 8.210 | 13.805 |
> | | **sink açık** | **1.515** | **4.865** | **8.200** |
> | orta (5/gün) | sink yok | 6.095 | 15.140 | 24.185 |
> | | **sink açık** | **1.995** | **5.170** | **8.245** |
> | yoğun (10/gün) | sink yok | 14.835 | 32.415 | 50.025 |
> | | **sink açık** | **325** | **335** | **335** |
>
> Yoğun oyuncunun 90 günlük fazlası **50.025 → 335 (%99,3)**; 51.220 Hamur
> güce gitti. Orta oyuncuda %66, kasualde %41 azalma.
>
> **Koleksiyon tamamlanma medyanı:** kasual 17→21, orta 11→15, yoğun 6→9 gün
> (önerilen rewarded cap ile 18/12/9). 30 gün içinde tamamlanma %92-99.
> Mağazadan alınan skin sayısı düşüyor (orta oyuncuda 10 → 4): oyuncu artık
> gerçekten **skin mi güç mü** seçiyor.
>
> **Kasual fakirleşmiyor:** karşılanmayan istek 0, 7. günde ~335 Hamur.
>
> #### Rewarded refill cap — ÖNERİ, implement EDİLMEDİ
>
> **ÖNERİ: günde 1 ödüllü refill, dört gücün TOPLAMI için** (round başına
> değil, gün başına). Ölçüm (yoğun oyuncu, 30. gün):
>
> | politika | Hamurla alınan | reklam/gün | 30. gün Hamur |
> |---|---|---|---|
> | rewarded yok | 119 | 0 | 325 |
> | **1/gün** | **108** | **1,0** | **1.395** |
> | 2/gün | 86 | 2,0 | 4.280 |
> | Model A (1/round, cap yok) | **0** | 4,9 | **14.915** |
> | Model B (1/round HER TİP) | **0** | 4,9 | 14.990 |
>
> **Round başına refill Hamur mağazasını tamamen öldürüyor.** Model A ve B
> normal kullanımda ayırt edilemiyor (oyuncu round başına ~0,5 güç istiyor);
> fark yalnızca spam altında çıkıyor — round başına 2 güç isteyen oyuncuda
> Model B günde **17,3 reklam** gerektiriyor ve her isteği bedava
> karşılıyor. **Model B elendi.** Asıl kaldıraç günlük cap.
>
> #### Gerçek para Power Pack — TASLAK, billing YOK
>
> | pack | içerik | Hamur değeri | yoğun oyuncunun geliri | round |
> |---|---|---|---|---|
> | Mini | her güçten ×3 | 1.680 | 3,1 gün | ~24 |
> | Power | her güçten ×6 | 3.360 | 6,2 gün | ~48 |
> | Mega | her güçten ×12 | 6.720 | 12,3 gün | ~96 |
>
> İlk taslak ×2/×5/×12 idi; ×2 Mini yoğun oyuncunun yalnızca 2,1 günlük
> gelirine denk geldiği (işleme değmeyecek kadar küçük) için ×3/×6/×12'ye
> çekildi. **TL/USD fiyat, product ID ve Play Billing YOK.**

> ### 📌 ÖDÜLLÜ GÜÇ CAP'İ KİLİTLENDİ — 1/gün (M8.5-06)
>
> M8.5-05 raporu "günde 1" ÖNERMİŞTİ ama yalnızca 1 ve 2 ölçülmüştü. Bu turda
> 1 / 2 / 3 ve kontrol olarak per-round modeli tam metrik setiyle karşılaştırıldı
> (`python tools/shop_economy.py caps`, 3000 deneme/senaryo, 90 gün).
>
> **Karar: günde 1 refill, dört gücün TOPLAMI için.**
> `scripts/game/rewarded_policy.gd` → `DAILY_POWER_REFILLS`.
>
> Yoğun oyuncu (10 round/gün, yüksek kullanım) — kararın verildiği senaryo:
>
> | cap | reklam/gün | bedava | Hamurla | bedava% | karşılanmayan | gün30 | gün60 | gün90 |
> |---|---|---|---|---|---|---|---|---|
> | yok | 0,00 | 0 | 379 | %0 | 67 | 325 | 320 | 330 |
> | **1** | **1,00** | **90** | **348** | **%20,5** | **8** | **1.380** | **2.570** | **3.735** |
> | 2 | 1,99 | 179 | 265 | %40,3 | 1 | 4.235 | 9.440 | 14.685 |
> | 3 | 2,92 | 263 | 182 | %59,1 | 0 | 7.490 | 16.565 | 25.610 |
> | cap yok (1/round) | 4,96 | 446 | 0 | %100 | 0 | 15.000 | 32.550 | 50.220 |
>
> **1, "mağazayı en çok koruyan" olduğu için seçilmedi** — marjinal
> fayda/maliyet hesabı:
>
> - 1/gün karşılanmayan güç isteğini **67 → 8 (%88)** düşürüyor, yani
>   oyuncunun yaşadığı mahrumiyetin neredeyse tamamını çözüyor.
> - 2/gün bunun üstüne 90 günde yalnızca **7 istek** daha karşılıyor (günde
>   0,08) ama 90. gün Hamur fazlasını **3.735 → 14.685'e (4 kat)** çıkarıyor.
> - **3/gün elendi:** 90. gün Hamur'u 25.610 — güç sink'i olmayan referansın
>   (50.025) yalnızca yarısı kadar aşağıda. M8.5-05'te çözülen enflasyona
>   yarı yola kadar geri dönmek demek. Ayrıca güçlerin %59'u bedava geliyor,
>   yani Hamur mağazası ikincil kaynağa düşüyor.
>
> Kasual (3 round/gün) tarafında 1/gün zaten isteklerin %84'ünü bedava
> karşılıyor; 2 ve 3'te %100 oluyor ve kasualdeki Hamur sink'i tamamen
> kayboluyor — daha yüksek cap'in orada da getirisi yok.
>
> **Reklam adedi ayırt edici değil.** Yoğun oyuncuda revive'ın *teorik*
> tavanı zaten 20 reklam/gün (10 round × 2 revive); güç capi 1 → 3 toplam
> tavanı yalnızca 21 → 23 yapıyor. Karar ekonomiye göre verildi, reklam
> yüküne göre değil.
>
> | round/gün | güç capi | güç reklam/gün | revive TAVANI/gün | toplam tavan |
> |---|---|---|---|---|
> | 3 | 1 | 1 | 6 | 7 |
> | 5 | 1 | 1 | 10 | 11 |
> | 10 | 1 | 1 | 20 | 21 |
>
> (Revive sütunu ulaşılamaz bir tavandır: yalnızca fail olan round'larda ve
> oyuncu kabul ederse oynar.)
>
> **Pack taslağı DEĞİŞMEDİ.** Yeni cap analizi Mini/Power/Mega ×3/×6/×12
> ladder'ında bir sorun göstermedi, o yüzden sessizce dokunulmadı.

### 4.9 Görsel/fizik ayrımı: sprite dönüşü ±20°

Gövde fizikte serbest dönmeye devam ediyor (M1 kararı) ama yüz sprite'ın
içine gömülü olduğu için, gövdeyle tam dönerse karakter baş aşağı kalıyor.

- Önce **tam ters dönüş** denendi (sprite dimdik): yüz okunuyordu ama yığın
  robotik ve cansız görünüyordu.
- Şimdiki hâl: sprite gövdeyi **±20°'ye kadar takip ediyor**, sonra
  sabitleniyor. `lerp_angle` ile yumuşatılıyor (gövde 180°'yi geçerken hedef
  açı +20°'den −20°'ye atlıyor; doğrudan atansa görünür sıçrama olurdu).
- **Fizik davranışı hiç değişmedi.**

---

### 4.10 Oyun ekranı görsel pası (M8.5-07)

M8.5-03/04/05/06 mekaniği ve monetization altyapısını bitirdi ama oyun
ekranı hâlâ prototip gibi duruyordu: **düz koyu gri zemin, çamurlu kahverengi
(`#6b5a52`) duvarlar, koyu generic Wenrexa panelli pencereler.** Mağaza ve
harita ekranları candy görünürken oyun ekranı başka bir üründen gibiydi.

#### Bağlanan owner asset'leri

Üçü de repoda **zaten duruyordu ama hiçbir yerden kullanılmıyordu**
(`_visual_source/chatgpt_ui/`):

| kaynak | çıktı | nerede |
|---|---|---|
| `bg_scene.png` | `ui/board_background.png` | Oyun ekranı zemini |
| `panel_frame.png` | `ui/panel_candy.png` + `ui/panel_candy_crown.png` | Devam + refill pencereleri |

**Zemin karartılıyor.** Kaynak parlak bir GÜNDÜZ karnavalı; ham hâliyle
dumpling'lerden parlak kalıyor ve zeminin kendi dumpling çizimleri oyun
parçalarıyla karışıyordu. Çalışma zamanında `modulate` (0.38, 0.36, 0.50)
+ alfa 0.50 scrim ile akşam hissine çekildi. Fizik geometrisine
DOKUNULMADI — zemin ayrı bir `CanvasLayer` (layer −1).

**Panel ikiye bölündü.** `panel_frame.png` 9-patch'e uygun değil: tepesinde
ortalanmış kanatlı kalp var, üst-orta şerit onu yatayda ezerdi. Kaynak
ölçülüp (çerçevenin düz üst kenarı y=131, tacın tabanı y=150) çerçeve ve
taç ayrı dosyalara çıkarıldı; çerçeve modal dikdörtgenine geriliyor
(oran farkı %1, görünmez), taç üstüne ortalanıyor.

#### Kap görünümü

Duvarlar `#6b5a52` → `#e8bfa8` (krem-pembe), taban `#d8a891` + ince açık iç
şerit. Kabın içine hafif koyu bir dolgu kondu: zemin tüm ekranı kapladığı
için kabın içi ile dışı aynı parlaklıktaydı ve "kap" okunmuyordu.

**Görsel duvar ile fizik duvarı ayrıldı:** `_draw_walls()` yalnızca çiziyor,
collider'lar `_build_walls()` içinde ayrı kuruluyor. `WALL_THICKNESS`,
`FLOOR_Y`, `RIM_ABOVE_LINE` ve kap genişlikleri DEĞİŞMEDİ.

#### Güç efektleri

Mekanik hiç değişmedi (impulse, hedef kuralları, stok tüketimi, skor/merge
etkisi aynı). Eklenen yalnızca sunum ve dört güç artık birbirinden renkle de
ayrılıyor (`PowerUp.ACCENTS`):

| güç | eklenen | renk |
|---|---|---|
| Bomba | hedefe kapanan kilitlenme halkası → büyüyerek fırlayan, yay çizen ve dönen mermi → genişleyen şok halkası + duman | pembe |
| Büyütücü | eski çaptan yeni çapa AÇILAN halka + yukarı parıltı sütunu + daha güçlü squash | altın |
| Sarsıntı | taban boyunca üç toz bulutu + kap kenarının kısa parlaması + geniş halka | camgöbeği |
| Temizleyici | ortak süpürme halkası (≥3 parça) + parça başına kısa yukarı iz | yeşil |

Normal merge'de halka YOK — halka bilerek güçlerin imzası, ikisi
karışmasın diye.

**Performans:** her efekt tek atışlık, ömrü < 0.6 sn, parçacık sayısı sabit
tavanlı (`FX_DUST_MAX` 20, `FX_SPARKLE_MAX` 16, Temizleyici izi parça başına
4). Tier 8 merge'i + güç efekti aynı anda oynasa bile toplam birkaç yüz
parçacık.

**RNG:** görsel rastgelelik ayrı bir `_fx_rng` üzerinden. Gameplay RNG
akışına (drop_bag / kamera sarsıntısı) dokunulmadı; mevcut RNG coupling
teknik borcu bu turda da refactor EDİLMEDİ.

#### Üst HUD

Yeni zemin yer yer parlak olduğu için HUD yazılarının arkasına yumuşak koyu
bir plaka kondu (`HUD/TopPlate`). Ayrıca skor pop rozeti hedef satırının
üstüne biniyordu: rozet küçültülüp pop sağ üst köşeye çekildi.

#### Balans doğrulaması

Hiçbir gameplay sabiti değişmedi — `tier_config.gd`, `drop_bag.gd` ve level
`.tres` dosyalarına dokunulmadı, `dumpling.gd` fizik satırları aynı.

`bot_test` L10'da 6/20 (%30) verdi. GAME_DESIGN §3'teki kilitli değer %43
(n=30). **Bu bir regresyon DEĞİL, bilinen ölçüm gürültüsü:** M8.5-03'te
kaydedildiği gibi `bot_runner` deterministik değil (kamera sarsıntısı
`_process` içinde global RNG tüketiyor) ve aynı kod için tarihsel olarak
%22–%43 arası sonuç vermişti. n=20'de %43'ün güven aralığı zaten %30'u
kapsıyor.

#### ⚠️ OWNER ASSET NEEDED

Bu turda **üretilmedi ve placeholder final sayılmadı**:

1. **Dört güç ikonu** — `power_bomb.png` / `power_upgrade.png` /
   `power_shake.png` / `power_clear.png` (kare, ~128 px, saydam zemin).
   Güç çubuğu ve refill penceresi hâlâ `PowerUp.GLYPHS` metin işaretlerini
   (`✸ ▲ ≈ ⌫`) gösteriyor. **Mimari hazır:** dosyalar konup
   `PowerUp.ICON_PATHS` doldurulunca ikisi de otomatik gerçek `Texture2D`'ye
   geçer, kod değişikliği gerekmez.
2. **Pastel bambu/ahşap duvar dokusu** — kap duvarları şu an düz pastel
   RENK. Bu bir renk düzeltmesidir, doku taklidi değil; gerçek doku
   geldiğinde `_draw_walls()` içindeki iki `draw_rect` bir
   `draw_texture_rect`e dönecek.
3. **Koyu gece varyantı `bg_scene`** (opsiyonel) — mevcut gündüz sahnesi
   çalışma zamanında karartılıyor; owner koyu bir varyant üretirse
   karartma gevşetilebilir.
4. **Candy buton seti** (`btn_normal_a/b`, `btn_disabled`) repoda VAR ama
   bağlanmadı — tema butonu tüm ekranlarda ortak, değiştirmek her ekranı
   yeniden stillendirmek demek. Owner kararı.

---

### 4.11 Final asset entegrasyonu (M8.5-08)

M8.5-07 mimariyi kurmuş ama iki asset'i eksik bırakmıştı (dört güç ikonu,
bambu duvar dokusu). Owner ikinci bir ChatGPT partisi üretti; bu tur onu
bağladı. Türetme `tools/make_gameplay_art.py` ile yeniden üretilebilir —
çıktının diskteki dosyalarla **byte-identical** olduğu doğrulandı.

Tam kaynak→çıktı tablosu ve reddedilenlerin gerekçesi:
`assets/visual/CREDITS.md` → "Final oyun ekranı asset'leri (M8.5-08)".

#### Bulunan asset sorunu: sahte şeffaflık

`board_wall_bamboo_vertical.png` **%100 opak** — satranç deseni gerçek
transparanlık değil, piksel olarak basılmış. Sıfır-alfa oranı ölçüldü:
**%0.0**. Ham hâliyle bağlansaydı kap duvarlarında gri-beyaz kareler
görünürdü. Desene değmeyen temiz sütun aralığı (x 350-677) ölçülüp
içinden yaprak süsü de içermeyen tek bir sütun kesildi (x 469-560).

#### Güç ikonları

Bomba / Büyütücü / Temizleyici tekil kaynak dosyalardan geldi. **Sarsıntı
tekil dosya olarak YOK**, yalnızca sheet'lerin içinde. 2×2 sheet'te temiz
bir dikey ayraç bulunmadığı (kesim komşu ikondan piksel taşırdı), 3'lü
sheet'te ise bulunduğu için (boş sütunlar 642-757 ve 1311-1408) kesit
oradan alındı. Sheet'lerin hiçbiri runtime'da kullanılmıyor.

#### Buton durumları: pill'ler aynı orana getirildi

Üç kaynak pill'in gövde oranı farklıydı: normal **2.45**, seçili **2.30**,
pasif **3.01**. Aynı dikdörtgene gerilselerdi uçlardaki yıldız süsleri
durum değiştikçe şekil değiştirirdi.

İki yaklaşım denendi ve **elendi**:

- **Düz alfa-bbox'a kırpma.** Dış parıltı gövdeden çok geniş ve neredeyse
  şeffaf; bbox onu da alınca pill butonun ancak **yarısını** dolduruyordu.
  Çözüm: gövde eşiği (alfa ≥ 150) + ölçülü parıltı payı (%7).
- **Kapak/orta sert kesimi.** Kesim yerinde görünür bir dikey Mach bandı
  kalıyordu, özellikle çok sıkışan gri pasif pill'de. Çözüm: sürekli bir
  sütun haritası — ölçek yıldız kapaklarında tam 1:1, farkın tamamı
  pill'in düz orta şeridinde soğuruluyor, arada smoothstep ile geçiyor.

Buton ölçüsü de kaynağın **doğal oranına** çekildi (172×86 = 2.0). İlk
denemede 164×104 (1.577) seçilmişti; pill'i ezip köşe yarıçaplarını
bozuyordu.

**Global tema DEĞİŞMEDİ.** `assets/visual/ui_theme.tres` beş ekranda ortak;
candy butonlar `scripts/ui/candy_button.gd` üzerinden yalnız oyun ekranına
ve iki penceresine tek tek uygulanıyor. Ana sayfa / harita / koleksiyon /
mağaza bu turda görsel olarak hiç değişmedi.

#### Stok-0 okunurluğu

İlk denemede stok 0 butonun TAMAMI `modulate` ile soldurulmuştu; yazı da
solunca "Bomba ×0" okunmaz hâle geldi (çekimle yakalandı). Solukluk artık
yalnızca pill dokusuna (`CandyButton.EMPTY_TINT`) ve ikona uygulanıyor,
yazı tam opak ve koyu kırmızı kalıyor.

#### Zemin: gündüz + ağır karartma → gerçek gece

Owner gerçek bir gece varyantı üretti (`gameplay_background_candy_night.png`,
941×1672 — 9:16'ya neredeyse tam oturuyor, merkezi koyu bir göl/yol, parlak
öğeler üstte ve kenarlarda). M8.5-07'nin ağır karartması **gevşetildi**:
`modulate` (0.38, 0.36, 0.50) → (0.82, 0.80, 0.92), scrim alfası
0.50 → 0.18. Kabın içindeki koyu dolgu (`WELL_COLOR`) **korundu** —
karakterlerin siluetini arka plandan ayıran şey o.

#### Kap: düz renk → bambu

`_draw_walls()` içindeki üç `draw_rect` iki `draw_texture_rect`e döndü.
**Fizik hiç değişmedi:** `WALL_THICKNESS`, `FLOOR_Y`, `RIM_ABOVE_LINE`,
kap genişlikleri ve `_build_walls()` aynı — diffle doğrulandı.

Görünür taban `FLOOR_APRON` (54 px) ile fizik tabanının **altına** iniyor:
yatay bambu rayı 20 px'e sıkıştırılsa boğumlar ve kalp süsleri okunmazdı.
Aşağı doğru büyüyor, oyun alanına girmiyor (FLOOR_Y 1180, viewport 1280).

> Sonsuz modda kap genişliği 720 = ekran genişliği, dolayısıyla dikey
> duvarlar ekran dışında kalıyor ve bambu görünmüyor. Bu M8'den beri
> böyle (düz renkte de görünmüyordu), regresyon DEĞİL.

#### VFX: prosedürel katman KALDIRILMADI

Owner asset'leri mevcut halka/toz/parıltı katmanlarının **yerine değil
üstüne** bindi: okunurluğu prosedürel katman taşıyor, karakteri asset
veriyor. Uçan bomba ile patlama **ayrı dosyalar** — uçan bomba görselini
"patlama" diye kullanmak yanlış olurdu.

Mermi çapı hedefe göre ölçekleniyor ama tavanlı (`tier 3` çapı): tier 8'e
atılan bomba hedefi kapatmasın. Büyütücünün yükselme sütunu `z_index = -1`
ile yeni parçanın ARKASINDA — dönüşen dumpling görünür kalmalı.

#### Taşma şeridi sakinleştirildi

`DANGER_STRIPE_ALPHA_IDLE` 0.55 → 0.34 ve sakin hâlde renk soğutuluyor
(`DANGER_STRIPE_IDLE_TINT`), tehlikede tam beyaza dönüyor. Yeni gece
zemininin üstünde eski değer sürekli alarm veriyordu ve şerit board'un en
parlak öğesiydi. **Mekanik değişmedi:** grace süresi, taşma alanı ve
`_danger_pulse` hesabı aynı; değişen yalnız çizim.

#### QA aracı

`tools/vfx_shots.gd` genişletildi: uçuştaki mermi, refill penceresi ve
devam penceresi çekimleri eklendi. Ayrıca `_fill_live()` eklendi — bot
bazen level 3'ün hedefini 10 bırakışta tamamlıyor, round bitince güç
çubuğu `set_enabled(false)` ile pasife düşüyor ve "normal güç çubuğu"
çekimi yanlışlıkla PASİF durumu gösteriyordu.

### 4.12 Tipografi sistemi (M8.5-09)

M8.5-08'e kadar oyunun HER yazısı Godot'un varsayılan fontu ve varsayılan
16 px'iydi — candy asset'lerin yanında "debug overlay" gibi duruyordu.
Bu tur iki font ailesi ve merkezi bir rol sistemi getirdi. **Mekanik,
ekonomi, fizik ve reklam kuralı DEĞİŞMEDİ**; diffte `tier_config`,
`drop_bag`, `dumpling`, `power_up_economy`, `rewarded_policy`,
`power_up_controller`, level `.tres` dosyaları YOK.

#### Font seçimi (kilitli art direction, owner)

| aile | ağırlık | iş |
|---|---|---|
| **Baloo 2** | ExtraBold 800 | pencere kahramanı ("Devam etmek ister misin?", "Bomba bitti", "Level 3 tamam!"), ekran başlığı |
| **Baloo 2** | Bold 700 | bölüm/kart başlığı, birincil CTA, level numarası |
| **Nunito** | Bold 700 | HUD, skor, stok, fiyat, "TAKILI", ikincil buton, sekme |
| **Nunito** | SemiBold 600 | gövde metni, kota/not satırları, rarity etiketi |

Kural: **başlık ve CTA Baloo, geri kalan her şey Nunito.** "Her şey Baloo"
bilinçli olarak yapılmadı — güç çubuğu ve koleksiyon kartı gibi dar
kutularda Baloo'nun tombulluğu okunurluğu düşürüyor. Kaynak resmi Google
Fonts (`fonts.gstatic.com` statik TTF'leri), lisans OFL 1.1, SHA ve
doğrulama `assets/fonts/CREDITS.md`.

#### Mimari: tema variation'ları + proje geneli varsayılan

- `assets/visual/ui_theme.tres` artık `default_font` (Nunito SemiBold 20)
  ve rol başına **type variation** tanımlıyor: `Display` 42, `ScreenTitle`
  38, `SectionTitle` 27, `CardTitle` 23, `Stat` 20, `Caption` 16,
  `HudPrimary` 25, `HudSecondary` 22, `HudObjective` (RichTextLabel) 25,
  `SecondaryButton` 22, `TabButton` 21; `Button` varsayılanı Baloo Bold 27.
- Tema `project.godot` → `gui/theme/custom` ile **proje geneli varsayılan**
  oldu. Sebep: oyun HUD'u (`game_board.tscn`) hiçbir temaya bağlı değildi;
  sahne başına `theme =` atamaları duruyor ama artık yalnızca belgeleyici.
- `scripts/ui/ui_type.gd` (`UiType`): rol adlarının tek tanımı. Kodla
  kurulan etiketler (mağaza, koleksiyon, güç çubuğu, sonuç kartı)
  `UiType.apply(label, UiType.CARD_TITLE)` diyor; string dağılmıyor.
- Sahnede boyut override'ı YALNIZCA rolün varsayılanının fiziksel olarak
  sığmadığı yerlerde ve her biri `tools/type_probe.gd` ölçümüyle
  gerekçeli (güç çubuğu 15, koleksiyon adı 16, level numarası 28, sonuç
  kartı 20/17).

#### Ölçümle bulunan ve düzeltilen şeyler

- **Fontlarda olmayan glyph'ler.** ★☆ (level düğümü), ✓ (mağaza
  "Sahipsin"), ●○ (günlük seri sayacı) ve mağaza güç kartında hâlâ duran
  eski metin işaretleri ✸▲≈⌫ — dördü de her iki ailede YOK (cmap okundu).
  Godot'un sistem fallback'i açık olduğu için masaüstünde "çalışıyor gibi"
  görünüyordu ama bambaşka bir yazı tipinden çiziliyordu; Android'de hangi
  fontun geleceği belirsiz. Yıldızlar mevcut `icon_star_*.png` asset'ine,
  güç işaretleri mevcut `power_*.png` ikonlarına (M8.5-08 güç çubuğunu
  çevirmiş, mağazayı atlamıştı), ✓ düz metne, ●○ ise iki renkli "•"ya
  (RichTextLabel) çevrildi. `PowerUp.GLYPHS` artık hiçbir yerde
  kullanılmıyor.
- **İki satırlı CTA.** "HAMURLA AL / 120 Hamur" tek `Button.text` iken iki
  satır aynı ağırlıkta çıkıyordu. `CandyButton.set_cta_text()` butonun
  üstüne Baloo başlık + Nunito alt satır bindiriyor (güç çubuğu deseni).
  Godot `font_disabled_color`u çocuk Label'a uygulamadığı için pasif
  kontrast `refresh_cta()` ile elle tazeleniyor — `power_refill.gd` ve
  `revive_offer.gd` her `disabled` değişiminde çağırıyor.
- **Pencere çerçeveleri büyüdü.** Refill 660→770 px, devam 580→650 px,
  sonuç paneli üst kenarı -300→-380: yeni satır yükseklikleriyle içerik
  eski çerçeveden taşıyordu ("Kapat" pencere dışına düşmüştü, çekimle
  yakalandı).
- **Buton dokusu gölgesi.** Level düğümü ve güç pill'i içeriği tam
  dikdörtgene yayılınca yazı/yıldız alt kenara yapışıyordu; kutular
  temanın kendi content margin'leriyle (üst 12 / alt 20) içeri alındı.
- **Harita başlığı** eklendi ("Harita", ScreenTitle + gölge): dört
  sekmenin üçünün kimliği vardı, haritanın yoktu. Parlak harita zemininde
  başlık ve rekor satırına gölge verildi.

#### CTA yazım kuralı (§14 tutarlılık)

Büyük harf yalnızca **ekranı kilitleyen pencerenin birincil eylemi**:
DEVAM ET, REKLAM İZLE, HAMURLA AL, SATIN AL (onay diyaloğu), TEKRAR DENE,
OYNA, AL. Liste satırındaki "Satın Al" ve tüm ikincil butonlar ("Kapat",
"Vazgeç", "Bitir", "Level listesi", "Sonsuz Mod") başlık/cümle düzeninde.
Düzeltilen gerçek tutarsızlık: onay diyaloğunda "Satın al" ile liste
satırında "Satın Al" farklıydı.

#### Araçlar

- `tools/type_probe.gd` (headless): glyph kapsamı (`has_char`), dar
  kutularda en büyük sığan boyut, en kötü durum metinleri ("Temizleyici
  ×99", "Hamur: 99999", level 10 hedef satırı). 0 uyarı.
- `tools/type_shots.gd` (pencereli): Türkçe glyph tablosu dört ağırlıkta,
  günlük ödül penceresi, en kötü durum değerleriyle HUD/sekmeler/refill.
  Kayda YAZMAZ (bellekte değiştirip geri koyar).

Bilinçli olarak YAPILMAYANLAR: skin art/tint, HUD ikon sistemi, logo,
copywriting, variable font, font subset (bkz. `assets/fonts/CREDITS.md`).

### 4.13 Production UI kabuğu (M8.5-10)

**Production UI shell TAMAMLANDI** — dört sekme, alt sekme çubuğu,
ayarlar, günlük ödül ve mağaza onayı tek tasarım sisteminde. Gameplay
ekranı, güç butonları, devam/refill pencereleri, logo ve tipografi
DEĞİŞMEDİ (owner'ın final kimliği referans alındı).

#### Tasarım sistemi (`scripts/ui/ui_palette.gd` + `assets/visual/ui_theme.tres`)

| katman | uygulama |
|---|---|
| BACKGROUND | `scenes/ui/shell_backdrop.tscn` — owner'ın gece zemini karartılmış (tint 0.62/0.60/0.78 + erik scrim 0.5 + alt gradyan). Harita kendi art'ını koruyor |
| SURFACE | tema `PanelContainer` — erik/lacivert yarı saydam, radius 26 |
| CARD | tema `CardPanel` / `QuietCardPanel` — biraz açık, ince pastel/rarity kenar, radius 20 |
| CHIP | tema `ChipPanel` — ikon + değer pill'i (Hamur, seri, koleksiyon, rekor) |
| PRIMARY CTA | owner'ın candy pill dokusu (OYNA, pencere CTA'ları) ya da tema `Button` (candy cyan StyleBoxFlat + koyu alt dudak) |
| SECONDARY | tema `SecondaryButton` (beyaz hayalet pill); krem panelde `UiPalette.style_ghost_on_cream` (erik hayalet) |
| SELECTED | nane (`UiPalette.SELECTED`, koleksiyon TAKILI) / altın (sekme, sıradaki level halkası) |
| DISABLED | lavanta-gri gövde + koyu okunur yazı |
| MODAL | candy panel + kanatlı kalp tepeliği (revive/refill ile aynı) — ayarlar, günlük ödül, mağaza onayı |

Renkler owner asset'lerinden ölçüldü (`cta_button_normal` #5eddf9,
logo #fee85f/#c694fa/#84d7fc/#d9799e, gece zemini #0d153f/#2d2a6c).
Wenrexa buton/panel dokuları temadan çıktı (dosyalar duruyor).
Dekorasyon bütçesi: hero/CTA yoğun (~%10), kartlar orta (~%30), yüzeyler
sakin (~%60).

#### Ekranlar

- **Ana Sayfa:** üst çubuk (seri cipi · ayarlar dişlisi), hero (logo +
  owner'ın `tutorial_pose` maskotu, hafif nefes animasyonu), Hamur +
  koleksiyon cipleri, OYNA (610 px candy pill, Display 40) + "Sıradaki:
  Level N" satırı.
- **Alt sekme çubuğu:** ikon + etiket, seçili altın + arkasında yumuşak
  pill + ikon pop. 112 px, tek `TabBarPanel` yüzeyi. **AdMob seam:**
  `TabBar.AD_SAFE_INSET` (şu an 0) — banner gelince çubuk yukarı kayar,
  ekran payları `TabBar.bottom_inset()` ile büyür.
- **Mağaza:** başlık + Hamur cipi; bölüm başlıkları ikon+başlık+not;
  güç kartı = vurgu renkli yuvarlak ikon kuyusu → ad → fiyat (Hamur
  ikonu, altın) → stok (sakin) → candy "Satın Al"; skin kartı rarity
  kenarlı, sahip olunan sakin yüzey + nane tik. Onay diyaloğu candy modal
  (başlık / detay / fiyat / SATIN AL / Vazgeç, karartmaya dokunma =
  vazgeç). Başarıda kart pop + bakiye cipi pop + cip toast.
- **Koleksiyon:** başlık + Hamur cipi, altın ilerleme çubuğu kartı
  (`ProgressBar`), 4 sütun kart: açık = rarity kenar, kilitli = koyu sakin
  yüzey + silüet, takılı = nane 3 px çerçeve + "TAKILI" nane rozeti + pop.
  Skin önizlemesi hâlâ placeholder (dokunulmadı).
- **Harita:** art korundu; başlık + Hamur cipi, düğümler tema candy
  butonu (kilitli lavanta + kilit rozeti), **sıradaki level altın halka +
  nabız**, Sonsuz Mod butonu, rekor + seri cipleri.
- **Ayarlar (yeni, `scenes/ui/settings_panel.tscn`):** Ses Efektleri
  (gerçek — `AudioManager.set_sfx_enabled` SFX bus mute, kayıtta
  `sfx_enabled`), Gizlilik (kısa doğru metin), "Squishy Merge · Sürüm
  0.8.5" (`config/version`), Kapat + sağ üst X + karartmaya dokunma.
  **Müzik anahtarı bilerek YOK** — Music bus'ı boş, çalışmayan anahtar
  koymadık. Müzik gelirse `_add_toggle_row` ile tek satır.
- **Android geri tuşu** (`main.gd` `_notification`): açık pencereyi
  kapatır → Ana Sayfa'ya döner → oyun sırasında yok sayılır.

#### Mikro-etkileşimler (`scripts/ui/ui_motion.gd`)

| ne | süre |
|---|---|
| buton basışı: 0.94 scale, TRANS_BACK ile geri | 0.06 s / 0.18 s |
| pop (sekme ikonu, satın alınan kart, bakiye cipi, TAKILI) | 0.22 s |
| pencere açılışı: karartma fade + panel 0.92→1.0 scale + fade | 0.20 s |
| sekme geçişi: içerik 14 px alttan solarak | 0.16 s |
| toast: yükselip sönen cip | 1.0 s |
| sıradaki level nabzı / maskot nefesi | 0.9 s / 1.2 s döngü |

Hepsi kesilebilir (`UiMotion._restart` eski tween'i öldürür). Sekme
geçişi yalnızca `Container` çocuklara uygulanır (zemin kaymaz, alfa 0
toast ellenmez — ilk denemede toast görünür olmuştu, çekimle yakalandı).

#### Free Casual GUI paketi

Yalnızca 14 beyaz ikon alındı (`tools/make_pack_icons.gd`, beyaz maske
olarak). Butonlar (neon-glass), paneller (krem), HUD, rozetler, lekeler
REJECT/REFERENCE — tablo ve gerekçeler `assets/visual/CREDITS.md`.
**Kaynak paket repoya EKLENMEDİ:** Unity Asset Store EULA ham paketin
yeniden dağıtımına izin vermiyor olabilir; `_visual_source/` politikasının
tek istisnası. Owner isterse `.gitignore`'a açık istisna yazılıp eklenir.

#### QA

- `tools/ui_shots.gd` (yeni): dört sekme, takılı koleksiyon, mağaza
  üst/alt, ayarlar, en kötü durum (Hamur 99999, 20/20, stok ×99, seri
  365), oyun ekranı — BEFORE (d214f63) ve AFTER aynı kayıtla üç ölçüde
  (720×1280, 720×1560, 540×960). Taşma/kırpılma yok.
- `tools/ui_smoke_test.gd` (yeni, headless): 26 davranış kontrolü —
  sekmeler, ayar anahtarı (bus mute + kayıt), gizlilik, geri tuşu, onay
  diyaloğu, satın alma sonrası stok/Hamur/cip, equip/rozet/kilitli skin.
- Regresyon: economy 100/100 (4 metin kalıbı "Stok ×N" / "N Hamur"a
  güncellendi — mantık değil, kopya), refill 119/119, revive 103/103,
  smoke boot temiz.
- `type_shots.gd` ve `screenshot_runner.gd` sekme/pencere çekimlerine 0.3 s
  bekleme eklendi (geçiş animasyonu bitmeden çekim yarı saydam çıkıyordu).

#### Kalan görsel borç

1. Skin art (placeholder daireler) — koleksiyon ve mağaza kartlarının tek
   zayıf noktası.
2. Harita düğümleri hâlâ düz grid (§7 #3) — patika takip etmiyor.
3. Round sonuç paneli koyu yüzey (candy krem modal değil) — bilinçli:
   sandık reveal katmanları koyu zeminde okunuyor; owner isterse modal
   şablonuna geçer.
4. Ayarlarda müzik satırı yok (müzik yok).

### 4.14 Dumpling teması ve game feel (M8.5-11)

**Physics collider DEĞİŞMEDİ. Çözüm yalnızca görsel.** `TierConfig`
yarıçapları, `CircleShape2D`, kütle, sürtünme, sekme, level `.tres`,
drop bag — hiçbirine dokunulmadı. Kanıt: `tools/contact_rig.gd` BEFORE
(55b0152 worktree) ve AFTER aynı deterministik sahnelerde **birebir aynı**
settle süresi / yığın yüksekliği / merge sayısı / kaçan gövde / overlap
verdi.

#### Kök sebep (ölçüldü, `tools/contact_audit.py`)

Owner'ın "fizik değiyor ama sprite'lar değmiyor" gözlemi doğru; sebep
**şeffaf padding DEĞİL** (sekiz dokunun alfa>0 bbox'ı tam doku). Sebep:
sprite'lar ~1.3–1.4 en/boy oranlı geniş bloblar, collider daire; M8'in
geometrik-ortalama ölçeği (`2r / sqrt(w·h)`) görsel gövdeyi dikeyde çapın
yalnızca **%70–79**'una sığdırıyordu.

| tier | r | eski yatay boşluk (A) | eski taban boşluğu (B) | eski duvar (C) | eski üst boşluk |
|---|---|---|---|---|---|
| 1 | 22 | +1.1 | +3.3 | +0.6 | 9.5 |
| 2 | 27 | −0.4 | +4.4 | −0.2 | 10.8 |
| 3 | 34 | +8.6 | +3.1 | +4.3 | 5.5 |
| 4 | 42 | +1.1 | +6.1 | +0.6 | 18.3 |
| 5 | 52 | +0.4 | +8.3 | +0.2 | 17.3 |
| 6 | 65 | +1.4 | +9.8 | +0.3 | 21.3 |
| 7 | 81 | −1.9 | +12.7 | −3.6 | 24.3 |
| 8 | 100 | +19.4 | +8.1 | +7.7 | 34.0 |

(px, dünya; + boşluk / − overlap; "üst boşluk" = collider üst kenarı ile
görsel gövde üstü arası — yığındaki dikey/çapraz temaslarda görünen boşluk
bunun ~iki katı.) Yani yan yana zeminde bile T3/T8 açık, taban her tier'da
havada, yığında 10–30 px boşluk.

#### Kalibrasyon (`DumplingVisual.CONTACT_FIT`, tier başına)

Aksesuarsız gövde silueti (satır/sütun genişliği en genişin %42'sinin
altına düşen şeritler — yaprak, taç, fiyonk ucu, gölge — hariç) esas alındı:

- `scale.x`: gövde genişliği = **2r + 2 px** (hafif overlap, yumuşak his)
- `scale.y`: gövde yüksekliği 2r'nin %90'ına yaklaşır; dikey uzama en fazla
  **1.25×** (T1 1.18, T2 1.22, T3 1.00, T4 1.22, T5 1.17, T6 1.15, T7 1.17,
  T8 1.02). Daire yapmak karakteri bozardı; "biraz daha tombul" kabul.
- `offset`: gövde yatayda collider merkezine, gövde alt kenarı collider alt
  kenarının **1 px** üstüne.

Sonuç sekiz tier'da: yan yana **−2 px**, taban **+1 px**, duvar **−1 px**;
üst boşluk T1 3.4 → T8 19 px (T3'te −3, yaprak taşıyor). Çapraz (45°)
temasta kalan boşluk ≈ 0.1r.

Elenen alternatifler: (a) uniform büyütme — yatay %25 overlap, "iç içe";
(b) padding kırpma — padding yok; (c) collider küçültme (0.90–0.97) —
gerekmedi, balans kalibrasyonuna dokunmamak için yapılmadı.

#### Game feel (yalnızca sunum)

| an | eklenen | süre |
|---|---|---|
| düşüş | hıza bağlı dikey gerilme (en fazla %10, `FALL_STRETCH`), dünya dikeyinde | sürekli, yumuşatılmış |
| iniş | mevcut hız-orantılı squash **alt kenardan basılıyor** (sprite lift telafisi); ≥ 420 px/sn'de 3–6 parçacık toz pufu (`impact_landed`) | 0.12 s / 0.28 s |
| merge | iki kaynağın hayaleti birleşme noktasına çekilir (80 ms) → yumuşak parlama (0.18 s, halka DEĞİL — halka güçlerin imzası) → yeni tier 0.7→1.12→1.0 açılış (`play_reveal`, 190 ms) → mevcut parçacık patlaması + HUD skor pop; tier ≥ 4'te birleşme noktasında "+N" | ~200 ms |
| tier 8 | ek altın parıltı yıldızı (dönerek açılır) + ikinci çapraz beyaz | 0.55 s |
| combo | mevcut xN rozeti; x2→x6 arası rozet altına/beyaza ısınır, x3+ çok hafif kamera darbesi (1.5–4 px) | — |
| kamera | tier ≤ 3 merge **sarsıntısız**, 4–6 hafif (2–5 px), 7–8 kısa belirgin (≤ 14 px); annihilation eski gibi | `SHAKE_DECAY` aynı |
| tehlike | düz kırmızı duvar dikdörtgeni yerine taşma çizgisinden solan pembe rim glow + duvar üst yarısı; nabız hızı sayaç doldukça 1.9 → 4.5 Hz | alfa 0.16–0.62 |
| hedef | "Hedef tamam!" pop + kap ağzından parıltı yağmuru (22+14 parçacık) + 5 px sarsıntı; `RESULT_DELAY` 0.8 s zaten okunabilir an veriyor | 0.3 s |

**RNG:** kamera sarsıntısı artık `_fx_rng` kullanıyor — GLOBAL RNG'yi
tüketen tek görsel kod buydu (§7 #14). Drop bag'e dokunulmadı; global RNG'yi
artık yalnızca o tüketiyor. Yeni efektlerin tamamı deterministik tween ya
da `_fx_rng`.

#### Ölçüm ve QA araçları

- `tools/contact_audit.py [--fit]` — alfa/gövde/collider tablosu + GDScript
  tablosu üretimi.
- `tools/contact_rig.gd` — deterministik temas/yığın rig'i (lineup T1/T2/T4,
  pile_contact/pile_merge en dar kapta, wall T1/T5, large T7+T7+T8, stress
  35 parça + zincir); settle/yükseklik/merge/kaçan/overlap raporu.
- `tools/feel_shots.gd` — düşüş, iniş, merge (temas/pop/açılış), zincir,
  tehlike, hedef, tier 7→8 kare dizileri.
- Stress (35 gövde + 17 zincir merge + parçacıklar): masaüstünde en kötü
  kare ~22 ms (spawn karesi), yerleşince < 8 ms. Android ölçümü M9'da.

#### Balans

Collider değişmediği için zorunlu regresyon yok; `contact_rig` fizik
metrikleri BEFORE/AFTER birebir aynı. Sanity: headless bot L10 n=40 (aşağıda
DEVLOG'da sayılar) — kamera RNG değişimi drop sırasını farklı örnekliyor,
oran gürültü bandında.

### 4.15 Level haritası: patika yerleşimi (M8.5-12)

> **M8.6-04 notu:** aşağıdaki sunum (düz cipli başlık, StyleBoxFlat kare
> düğümler, dört durum, tam ekran karartma, alt sekme çubuğu) production
> yolculuk haritasıyla DEĞİŞTİRİLDİ — düğüm konumları düzeltildi (2/4/5
> yola, 8/9/10 aralığı), `MapLevelNode` beş durum, `ScreenTopBar`, çubuk
> Harita'da gizli. Güncel kaynak: `docs/UI_VISUAL_SYSTEM.md` §15. Patika
> (Catmull-Rom), açılış animasyonu ve unlock/yıldız kuralı aynen.

Düz 5×2 grid kalktı; on düğüm owner'ın harita art'ındaki pembe kaldırım
taşı yolun orta hattını takip ediyor. **Level verisi, hedefler, yıldızlar,
unlock kuralı (`SaveManager.highest_level_unlocked`) DEĞİŞMEDİ** — yalnızca
yerleşim ve sunum (`scripts/ui/level_select.gd`, `scripts/ui/map_trail.gd`).

#### Yerleşim (doku uzayı, 720×1280 zemin)

| level | (x, y) | not |
|---|---|---|
| 1 | 420, 1120 | yolun alt geniş bölümü, sağ |
| 2 | 300, 1030 | sol |
| 3 | 440, 940 | sağ |
| 4 | 310, 850 | sol |
| 5 | 300, 740 | yolun sola kıvrımı (sol köprünün sağında) |
| 6 | 395, 645 | |
| 7 | 470, 555 | yolun sağa dönüşü |
| 8 | 410, 465 | |
| 9 | 475, 385 | lamba direğinin solunda |
| 10 | 440, 296 | kapı kemeri |
| Sonsuz | 445, 150 | kale (patikanın sonu) |

Zemin `KEEP_ASPECT_COVERED` çizildiği için uzun ekranda büyüyüp kırpılıyor;
düğümler aynı dönüşümle (`_map_to_screen`: ölçek = max(vw/720, vh/1280),
merkezleme) taşınıyor — 720×1560'ta patika hizası korunuyor, kesilme yok.
Düğüm 88 px (96'da on düğüm + kapı 1000 px'lik yola sığmıyordu), kapı
116 px. Dekoratif karakterler (sol alt sarı, sağ alt pembe), köprüler ve
başlık satırıyla çakışma yok.

#### Düğüm durumları

| durum | görünüm |
|---|---|
| LOCKED | tema pasif (lavanta), alfa 0.78, kilit rozeti, **yıldız sırası yok** |
| AVAILABLE | candy cyan + ince krem kenar (teorik — unlock sıralı olduğu için pratikte NEXT ile aynı düğüm) |
| NEXT | altın 3 px halka + arkasında nabız atan altın hale (`fx_dot`, 210 px, alfa 0.7↔1.0) + 1.05 ölçek nabzı |
| COMPLETED | candy cyan + 1/2/3 yıldız |

#### Patika (`MapTrail`)

Programatik, asset yok: düğüm merkezlerinden Catmull-Rom eğrisi, 6 px
krem çizgi + 10 px koyu gölge çizgisi, 26 px aralıklı noktalar (düğüm
altında kalanlar atlanır). Tamamlanmış segment sıcak krem-altın (alfa
0.95), gelecek segment beyaz alfa 0.32. `highest = H` → H−1 segment sıcak.

#### Açılış animasyonu

Bellek içi `_last_unlocked` (kayda yazılmaz): tazelemede `highest`
arttıysa yeni segment 0→1 yanar (0.4 s), yeni düğüm 0.4→1.15→1.0 pop
(0.32 s, 0.24 s gecikmeli), 12 parıltı. Toplam ~0.7 s, kesilebilir.
Sonsuz Mod açılışında aynı animasyon kapıya uygulanır.

#### Sonsuz Mod kapısı

Normal düğüm değil: kalenin önünde 116 px yuvarlak altın kapı (kupa +
"Sonsuz" içeride, dış altın parıltı gölgesi), altında tek cip — açıksa
"Rekor N" (kupa), kilitliyse "Level 10'u bitir" (kilit). Unlock kuralı
`is_endless_unlocked` aynı. Rekor/seri cipleri artık alt satırda değil:
seri + Hamur başlıkta, rekor kapının altında.

#### QA

`tools/map_shots.gd`: owner kaydı (10/10), orta ilerleme (1-3 tamam,
sıradaki 4), sıfır kayıt, açılış animasyonu ortası/sonu — 720×1280,
720×1560, 540×960. `ui_smoke_test` +9 kontrol (35/35): düğüm sayısı,
durumlar, kapı kilidi, grid olmadığı, `level_chosen`, açılış sonrası
sıradaki, sonsuz açılışı.

### 4.16 Skin sistemi temeli + koleksiyon vitrini (M8.5-13)

Amaç: "gerçek ürün gibi dursun" — sanat gelmeden önce **sistem** ve
**koleksiyon hissi** tamam olsun. **Gameplay, ekonomi (fiyatlar 50/150/
400/900), sandık oranları, kayıt formatı (`unlocked_skins` + `equipped_skin`,
boş string = varsayılan) DEĞİŞMEDİ.**

- **Veri modeli.** `SkinData` (katalog: id, ad, rarity, tint, **yeni**
  `preview_texture` — boşsa önizleme orijinal dumpling + SkinVisual'dan
  türetilir; owner'ın görseli gelince yalnız bu alan dolar) + **yeni
  `SkinEntry`** (oyuncuya göre durum: price / owned / equipped / locked,
  `SkinEntry.all(with_default)`, `find`, `equipped_entry`, `owned_count`).
  Koleksiyon, mağaza, ana sayfa ve sonuç ekranı skin durumunu artık tek
  kaynaktan okuyor — "sahip değil ama takılı" yapısal olarak imkânsız.
- **Sinyaller.** `SaveManager.skin_granted(id)` / `skin_equipped(id)`;
  `grant_skin`, `purchase_skin_with_dough`, `equip_skin`,
  `clear_equipped_skin` yayıyor. Koleksiyon abone: görünürken anında,
  görünmezken (mağazadan satın alma) bir sonraki açılışta yeni skin'i
  vitrine alıyor ("YENİ" + "Tak"). Gameplay abone değil — parça skin'ini
  doğarken okuyor, round içinde equip mümkün değil.
- **Önizleme.** `SkinSwatch` yeniden yazıldı: renkli daire placeholder'ı
  kalktı; sahip olunan skin **gameplay'deki materyalin aynısıyla**
  (`SkinVisual.apply` artık `CanvasItem` alıyor — Sprite2D ve TextureRect)
  tier-3 dumpling'i çiziyor, arkada rarity renginde radyal parıltı
  (GradientTexture2D, rarity başına önbellek); kilitli: silüet + kilit
  rozeti + soluk parıltı; varsayılan: nötr.
- **Koleksiyon ekranı.** Vitrin (150 px önizleme + ad + rarity pill +
  TAKILI/KİLİTLİ/YENİ pill + bağlam satırı + tek aksiyon: "Tak" candy CTA
  ya da kilitliyse "Mağazaya Git" ikincil buton → `shop_requested` →
  main.gd Mağaza sekmesi), ince albüm ilerleme şeridi, grid. Kartlar:
  sahip olunan plum + rarity kenar (Legendary altın 3 px), kilitli koyu +
  ad soluk + **fiyat bandı** (oyuncu neye ne kadar uzak olduğunu görsün),
  takılı nane + rozet, vitrindeki kilitli kart beyaz kenar. **Karar:**
  kilitli kartta ad artık "???" değil soluk ad — mağaza zaten adı
  gösteriyordu, iki ekran çelişiyordu; owner isterse tek satırlık geri alım.
- **Mağaza.** Skin satırları `SkinEntry`'den: sahip olunan "Sahipsin",
  takılıysa "Sahipsin · Takılı" + nane kenar; önizleme koleksiyonla aynı
  bileşen (72 px). Satın alma transaction'ı, onay diyaloğu, güç bölümü
  DEĞİŞMEDİ.
- **Dürüst sınır.** 20 skin'in tint verisi hâlâ placeholder
  (SKIN_ART_AUDIT.md): pastel dumpling üstünde luminans koruyan hue
  kaydırması **tüm rarity'lerde neredeyse görünmez** — koleksiyon
  önizlemeleri artık oyunu doğru yansıttığı için bu gerçek olarak ortaya
  çıktı (eski daireler bunu gizliyordu). Bilerek `STRENGTH` / tint
  DEĞİŞTİRİLMEDİ (owner kararı bekliyor, audit seçenek A/D). Sistem tarafı
  bu turla tamam; görsel ayrım tamamen veri/sanat işi.
- **QA.** `ui_smoke_test` +32 kontrol (67/67): fresh save (bozuk
  `equipped_skin` → güvenli fallback, 0/20, 21 kart, vitrin Varsayılan),
  kilitli dokunuş → vitrin/fiyat/"Mağazaya Git" → mağaza sekmesi, mağazadan
  satın alma (tek transaction, Hamur −150, takılı DEĞİL), koleksiyona dönüş
  → "Tak" → kayıt/kart/vitrin/mağaza "Takılı", **gameplay parçası skin
  materyalini taşıyor** (shader param = skin.tint), `load_game()` ile
  restore. `ui_shots` +1 kare (kilitli vitrin). Regresyon: economy
  100/100, refill 119/119, revive 103/103, bot L5 n=3 sanity. Owner kaydı
  byte-identical geri yüklendi (c46b9c80...).
- Yeni class_name'ler için `.godot/global_script_class_cache.cfg`
  yenilenmesi gerekti (`godot --headless --editor --quit`); editor
  açılmadan headless koşan test bunu kendisi yapmıyor.

### 4.17 Final skin sanatı + production gameplay skin render'ı (M8.5-14)

Owner'ın 20 final önizleme PNG'si bağlandı ve gameplay skin render'ı
placeholder hue-shift'ten production pipeline'a geçti. **Fizik, collider,
CONTACT_FIT, merge/skor, bag, level, ekonomi (50/150/400/900), sandık,
kayıt formatı, skin id'leri DEĞİŞMEDİ.** Ayrıntı: `SKIN_ART_AUDIT.md`
(yeniden yazıldı — artık "placeholder" demiyor).

- **Önizleme:** `assets/visual/skins/previews/skin_<rarity>_<ad>.png`
  (1254², saydam), import `size_limit=512` + mipmap (VRAM ~5 MB / 20 doku).
  `SkinData.preview_texture` ext_resource; `SkinSwatch` mipmap'li filtre.
  Kaynak PNG'ler ve arşiv zip'i (`_visual_source/`) dokunulmadı.
- **Veri:** `SkinData` render profili alanları (body/shade/highlight,
  pattern + renk/yoğunluk/ölçek/güç, gloss/pearl/sparkle, aura_color,
  anim_speed); `tint` alanı ve `skin_tint.gdshader` silindi. 20 `.tres`
  `tools/make_skin_resources.py` tablosundan üretiliyor (elle düzenleme
  yok). Adlar Türkçe diyakritikli ("Susamlı", "Gökkuşağı").
- **Gövde maskeleri:** `tools/make_skin_masks.py` → 8 gri maske
  (`assets/visual/skins/generated/`). Ton + V eşiği + elle dışlama elipsleri
  (tier 2/7 yanak, 6 yıldız, 7 fiyonk), `--debug` kontrol kareleri.
- **Shader:** `assets/visual/skins/skin_body.gdshader` — luminans tabanlı
  shade/body/highlight, 11 deterministik desen ailesi (sprite UV'si, hash/sin,
  TIME dışında rastgelelik yok), tier'a göre `detail_scale`, gloss/pearl/
  sparkle. Legendary aura `skin_aura.gdshader` (sprite çocuğu, arkada,
  paylaşılan doku+materyal). `SkinVisual.apply(item, skin, tier)` +
  `attach_fx`; (skin,tier) başına tek paylaşılan materyal.
- **Bulunan kök sebep:** Godot 4 canvas_item'da `COLOR` zaten doku×modulate;
  eski shader `src * COLOR` ile dokuyu iki kez çarpıyordu → hue-shift
  "görünmüyor"du. Yeni shader modulate'i vertex'ten varying ile alıyor.
- **QA araçları:** `tools/skin_gallery.gd` (rarity sayfaları tier 1/4/8 +
  final önizleme, tier 1 ×3, tier 8 detay, 8 skin gerçek gameplay merge anı
  — pencereli), `tools/skin_test.gd` (headless, 25 kontrol: 20 skin / sabit
  id / 8-6-4-2 / adlar / 20 önizleme / fiyatlar / 160 materyal + paylaşım /
  aura ekleme-kaldırma / varsayılan-Sade temiz dönüş / ghost materyali /
  global RNG tüketmiyor / takılı skin → yeni parça).
- **Sonuçlar:** skin_test 25/25, ui_smoke 67/67, economy 100/100, refill
  119/119, revive 103/103. Görsel: 20 skin birbirinden ayrılıyor, yüz/yanak/
  aksesuar boyanmıyor, aura kompakt, merge/parçacık/combo uyumlu; koleksiyon
  + mağaza 540×960 / 720×1280 / 720×1560 kırpılma yok.
- **Bilinen sınır:** Epic/Legendary önizlemelerindeki özel aksesuar/ifade
  gameplay'e taşınmadı (tier başına overlay art gerekir, 6×8 parça) —
  placeholder ile taklit edilmedi, `SkinVisual.attach_fx` takılma noktası.

### 4.18 Final SFX + titreşim + ses game-feel (M8.5-15)

Ses, görsel game-feel'in kalitesine çekildi. **Fizik, merge, bag, skor,
ekonomi, skin, harita, tipografi, reklam/billing DEĞİŞMEDİ.** Kayıt
formatına yalnız `haptics_enabled` (varsayılan true) eklendi. Ayrıntı ve
ölçümler: `docs/AUDIO_AUDIT.md`; eksik örnek şartnamesi:
`docs/AUDIO_ASSET_REQUIREMENTS.md`.

- **Denetim:** M6'nın 7 Kenney CC0 dosyası ölçüldü (`tools/audio_probe.gd`,
  AudioEffectCapture). Eski mimari 8 kanal round-robin idi: ödül sesi bir
  sonraki inişle kesilebiliyor, olay başına soğuma/tavan yok, bırakma /
  iniş / UI / güç aktivasyonu sessiz, `chest_open` ve `danger` üçer anlamda.
  `pluck_001` +0.4 dBFS (kırpıyor); `lowDown` 0.84 s tepe −0.6 dB ve 0.5
  s'de bir tekrar (siren etkisi). Digital Audio paketinden iki dosya
  (`sfx_danger`, `sfx_combo`) kaldırıldı; beşi `kenney_*` adıyla kategorili
  klasörlere taşındı.
- **Mimari:** `AudioManager.EVENTS` (olay → varyant havuzu, gain_db, pitch,
  jitter, cooldown_ms, max_voices, steal_self, priority, layers, fallback);
  12 kanal; kanal çalma LOW<NORMAL<HIGH<CRITICAL, CRITICAL asla kesilmez;
  yerel `RandomNumberGenerator` (global RNG'ye dokunmuyor — test `seed()`
  dizisiyle doğruluyor); eksik dosya → fallback → sessiz, tek uyarı; SFX
  bus'ında `AudioEffectHardLimiter` (−0.5 dB). Yardımcılar
  `play_drop/play_landing(tier, hız)/play_merge(tier)/play_combo/play_reward`.
- **Olaylar (36):** UI (tap/tab/modal open-close/toggle/select/purchase/
  invalid/equip), gameplay (drop, land hız+tier'a göre, merge + tier'a göre
  pesleşen gövde katmanı + tier ≥ 6 parıltı + tier 8 CRITICAL kutlama,
  annihilation, combo, danger, fail, round_win/lose, revive), güçler
  (power_arm, bomb_whoosh → bomb_impact, upgrade, shake, clear_puff), ödül
  (star_reveal, chest_open → reward_common/rare/epic/legendary,
  daily_reward, level_unlock). Evrensel buton sesi `UiMotion.attach_press`
  / `attach_tap` (`button_down`); sekme ve anahtar kendi sesini kullanır.
- **Sentez (geçici):** `tools/make_sfx.gd` → 22 `sfx_*.wav` (sinüs/gürültü,
  deterministik, tepe −3…−9 dBFS, kırpma 0, PCM 16-bit mono). Kulakla
  DOĞRULANMADI; final değil. Aynı adla üzerine yazılınca kod değişmez.
- **Titreşim:** `scripts/haptics.gd` (`class_name Haptics`, statik; autoload
  eklenmedi). LIGHT 18 / MEDIUM 32 / STRONG 55 ms, SPECIAL 35+60+60 ms,
  amplitude 0.35/0.65/1.0, `MIN_GAP_MS` 70 (yalnız daha güçlü darbe geçer).
  Editor/masaüstü: `is_supported()` false, platform çağrısı yok. Politika:
  buton/bırakma/iniş/combo/tehlike YOK; merge LIGHT, tier 6–7 / güç
  aktivasyon / satın alma / devam / taşma MEDIUM; bomba STRONG; tier 8 ve
  Legendary SPECIAL; temizleyici tek LIGHT. Ayarlar → Titreşim (`vibration`
  ikonu paketin `icon_bell`'inden türetildi). Android VIBRATE izni M9
  preset'inde açılmalı. **Cihazda doğrulanmadı.**
- **QA / test:** `tools/audio_test.gd` 45/45 (yükleme, olay eşlemesi, eksik
  akış çökmez, RNG izolasyonu, iniş spam 10→≤2, soğuma, merge steal_self,
  CRITICAL korunması, SFX/haptics kalıcılık, haptics kapalı → çağrı yok,
  editor güvenli, spam penceresi, SPECIAL, ≤60 ms, gameplay durumu sabit).
  `tools/audio_qa.tscn` (48 düğme: her olay, rarity, titreşim seviyesi,
  spam/stres senaryoları, kanal/atılan sayaçları). Mevcut testler: ui_smoke
  72/72, economy 100/100, refill 119/119, revive 103/103, skin 26/26, bot L3
  2/2. Pencereli gerçek sürücüde `ui_shots` hatasız.
- **Doğrulanmayan:** hiçbir ses kulakla dinlenmedi; Android titreşimi
  fiziksel olarak doğrulanmadı.

### 4.19 Skin render'ında tier kimliği + ilk gerçek cihaz kapısı (M8.5-17)

- **Kök sebep:** `skin_body.gdshader` gövde rengini
  `mix(shade, body, luminans)` ile TAMAMEN skin profilinden alıyordu; tier
  sprite'ından yalnız gölge/ışık dağılımı (luminans) geliyordu. Skin
  takılıyken 8 tier aynı gövde rengine dönüyordu (Havuçlu = turuncu kap);
  siluet/aksesuar farklı kalsa da renk okunurluğu ve ilerleme hissi
  gidiyordu. Sade de gereksiz yere krem recolor uyguluyordu.
- **Model:** `final = tier_blend(tier_rgb, skin_rgb, tint_strength)`:
  RGB karışım → HSV'de ton kayması tier tonundan en fazla ~32° (sabit,
  rarity'den bağımsız), skin tonu tier tonundan ≥ ~72° uzaksa ton çekimi
  sönüyor (162°+ → sıfır; mavi tier altında altın = "sırlanmış" mavi, yeşil
  tier değil), doygunluğun %60'ı tier'dan geri alınıyor (tamamlayıcı
  karışım griye düşmesin); değer karışımdan. Desen/gloss/pearl/sparkle/
  aura katmanları aynen; Gökkuşağı IRIDESCENT deseni tier tonu etrafında
  ±36° ince-film salınımı + %30 pastel gökkuşağı, kısmi kapsama (eski: %85
  tam gökkuşağı gradyanı → 8 tier aynı).
- **Veri:** `SkinData.tint_strength` (yeni alan; `make_skin_resources.py`
  `TINT_BY_RARITY` 0.30/0.35/0.40/0.50, Gökkuşağı 0.40, Sade 0.0). Kakao
  MARBLE 0.85→0.6, Safran SWIRL 0.85→0.7 (pastel gövdede aşırı baskındı).
  `SkinData.is_baseline()` → `SkinVisual.apply` materyal takmaz (Sade =
  varsayılan; test "Sade: materyal yok"). 152 materyal (19×8).
- **QA:** `skin_gallery.gd` iki yeni sayfa (varsayılan + 9 temsilci skin,
  8 tier yan yana, gameplay ×0.6), hücre yerleşimi JSON;
  `skin_tier_contrast.py` yüz/aksesuar dışı üç yamadan CIE Lab ΔE76:
  komşu tier min ΔE — varsayılan 25.5, Havuçlu 21.9, Ispanak 24.1,
  K.Biber 29.0, D.Tuzu 20.2, Kakao 15.9, Safran 19.7, Altın 22.9,
  Gökkuşağı 18.3 (eşik 12; aynı aile 1/6, 2/7, 4/8 tasarım gereği aynı
  renk, sayılmıyor). Gameplay kareleri artık ≥12 parçalı yığında.
- **Android (ilk kez):** `import_etc2_astc=true` (Godot 4.6.3
  `has_valid_project_configuration` bu kapalıyken export'u BOŞ hata
  mesajıyla reddediyor — not düşüldü), yerel `export_presets.cfg`
  (prebuilt template, arm64-v8a, VIBRATE, adaptive ikonlar, exclude
  `tools/* _visual_source/* docs/* *.md *.py`, paket
  `com.example.squishymerge` GEÇİCİ). Debug APK 44.7 MB, Samsung SM-A366B
  (Android 16, Adreno 710, Vulkan Forward Mobile): kurulum/başlatma temiz,
  logcat'te Godot hatası yok. Cihazda 5 skin ile 60 parçalık sonsuz mod
  yığını: tier'lar ayrışıyor, yüz/aksesuar korunuyor, merge/squash normal.
  Kareler `build/qa_m8.5-17/` (gitignore'lu). Gözlenen ama bu işin dışı:
  9:19.5 ekranda güç butonları "Sıradaki: …" satırını örtüyor (§7 #9),
  sonsuz mod kabı ekran kenarını aşıyor.
- **Değişmeyen:** fizik, collider, CONTACT_FIT, bag, merge, skor, revive,
  güçler, ekonomi, kayıt formatı, önizleme sanatı, maskeler.

### 4.20 Player Meta V1 — gameplay skinleri emekli, Koleksiyon V1, Profil (TASK/044)

> **main'de** — `task/044-player-meta-v1` (başlangıç main `327dd60`) owner onayıyla
> ff-only alındı (`327dd60 → 239f2e7`, 2026-09-28); **Samsung A36 yerel kapısı GEÇTİ
> (2026-09-28)**. Kural metni: GAME_DESIGN §5.3 / §5.8; UI: UI_VISUAL_SYSTEM §17 / §22.

- **Owner kararı:** skin sistemi gameplay özelleştirmesi olarak EMEKLİ. Gerekçe:
  koleksiyon sanatı değerli ama tier kimliğiyle çatışan bir render katmanı
  (§4.17 / §4.19'daki gövde maskesi + shader + tavanlı tint) taşımaya değmiyor;
  koleksiyon bir tamamlama / statü hedefi olarak daha net. Oyundaki parça artık
  HER ZAMAN kanonik tier sprite'ı.
- **Denetim (brief §17) — referans kategorileri:** **A sil:** `SkinVisual` +
  `.uid`, `skin_body` / `skin_aura` shader'ları, 8 gövde maskesi (+ `.import`),
  `make_skin_masks.py`, `skin_tier_contrast.py`, `skin_gallery.*`,
  `screenshot_runner` skin çekimi, `DumplingVisual` skin katmanı
  (`override_skin` / `use_equipped_skin`), equip API'leri (`equip_skin`,
  `clear_equipped_skin`, `equipped_skin_id`, `equipped_skin`, `skin_equipped`
  sinyali, `SkinEntry.equipped` / `equipped_entry`), Koleksiyon vitrini / TAK /
  TAKILI, Mağaza TAKILI durumu, "Varsayılan" kartı, harness'lardaki etkisiz
  `equipped_skin` satırları. **B göç / tarih için kalır:** `unlocked_skins` (sahiplik),
  `SkinData` / `SkinEntry` / `SkinLibrary` sınıf adları, `SkinData` render alanları
  (inert — okunmaz), `grant_skin` / `owns_skin` / `skin_granted`, `ui_equip` ses id'si,
  `EquippedBadge` tema varyasyonu (sonuç ekranının kilit-açıldı rozeti),
  `focus_skin` / `shop_skin_requested` / `ShopSkinCard` / `CollectionSkinCard` adları,
  `equipped_skin` yalnız `_migrate_legacy_equip` içinde. **C vitrine dönüştü:** takma
  eylemi → VİTRİNE EKLE; eski `equipped_skin` → vitrinin ilk yuvası. **D yalnız
  tarih:** DEVLOG, bu dosyanın §4.16–§4.19'u, `SKIN_ART_AUDIT.md`, CREDITS notu.
- **Kayıt:** yeni alanlar `profile_showcase` (≤ 3, sahip + katalog, tekrarsız,
  ilk = avatar; okuma her zaman doğrulanır), `total_rounds_played`,
  `highest_tier_created`, `profile_counters_partial`. Göç yalnız bellekte (yüklemede
  disk yazması yok; sonraki doğal kayıt kalıcılaştırır): `equipped_skin` → vitrin
  (yalnız kayıtta vitrin yoksa + sahip olunan katalog parçasıysa) ve anahtar silinir;
  sayaçlar eski kayıtta 0'dan başlar, oynanmışlık kanıtı varsa partial = true
  (uydurma yok). Onboarding göçü ve başlangıç güç hediyesi aynen.
- **Sayaç semantiği (brief §12):** tur = round KESİN bitince tam +1
  (`Main._on_round_finished` → `SaveManager.record_round_finished`, `_finish`
  korumalı); terk / yeniden başlatma sayılmaz. En yüksek tier = bitmiş round'da
  merge (sonsuzda tier 8 yok oluşu dahil) ya da Büyütücü ile OLUŞTURULAN
  (`GameState.note_tier_created`; düşen parça değil). Profil gösterimi tamamlanan
  level'ların hedef tier'ını kanıtlanmış alt sınır olarak kullanır.
- **Profil:** Ana Sayfa üst-sol `AvatarButton` (eski ayarlar butonunun yeri);
  "Oyuncu" adı (takma ad / XP / seviye / başarım / unvan TASK/045); 3 yuva vitrin;
  6 istatistik (`PlayerProfile` — kanonik alanlardan türetilir); salt okunur güç
  stoğu; koleksiyon kartı + KOLEKSİYONA GİT; dişli → Main'in tek `SettingsPanel`'i
  (oyun içi HUD ayarları + mola aynen). `Surface.NONE`: banner yüzeyi değil.
- **Dil:** oyuncuya "skin / tak / TAKILI" yok — KOLEKSİYON, SQUISHY, KOLEKSİYON
  PARÇASI; sandık / günlük: rozet "YENİ SQUISHY" + "keşfedildi!" (sonuç kartı ve
  günlük reveal aynı — A36 kapısı: günlük başlık rozeti artık tekrarlamaz);
  Mağaza bölümü "KOLEKSİYON", onay "Nadir Squishy · koleksiyonuna kalıcı eklenir",
  satın alma bildirimi "… alındı · koleksiyonuna eklendi".
- **Değişmeyen (dondurulmuş):** fizik, merge kuralları, level balansı, sandık
  oranları 60/25/12/3 + %30 parça / %70 Hamur, fiyatlar 50/150/400/900, güç
  fiyatları, günlük ödül ekonomisi, ödüllü kotalar, geçiş reklamı zamanlaması,
  reklam yüzeyleri, TEEN / ADULT yönlendirmesi (TASK/043), GMA / UMP sürümleri,
  paket kimlikleri.
- **8 mercekli salt-okunur çekişmeli inceleme (brief §22):** kayıt göçü · skin gerçekten
  kalktı · ekonomi · profil istatistikleri · vitrin sahiplik doğrulaması · responsive UI ·
  TASK/043 yaş/ayarlar · gezinme. Blokaj yok. Giderilen: `shell_shots` gerçek Main
  kurarken daraltılmış sahipliği kayda yazabiliyordu (araç; bayt geri yazma eklendi) ·
  detayda hızlı çift dokunuş ikinci eyleme düşüyordu (350 ms eylem kilidi) · Profil →
  detay rotası aynı sekme tazelemesinde (günlük pencere) kayboluyordu (tazeleme detayı
  korur, sekmeden çıkınca kapanır) · bayat değiştirme durumu · ham vitrin listesine
  tavan (32) · türetilmiş tier "en az" notu · Profil dişlisinden TASK/043 yaş yeniden
  giriş testi · Profil kartlarında içerik `card_bevel_soft`'un pişmiş alt dudağına
  biniyordu (gövde iç payı gerçekten uygulanır, alt pay 24, kart içeriğe göre uzar;
  piksel ölçümüyle test edildi) · rarity çipleri sekme gibi çiziliyordu (`badge_round`,
  34 px) · haze boşluğu · kaydırmada CTA basılı kalıyordu · çift `ui_tap` · çift halka
  tonu · albüm başlığı dikey ortalı · ekran görüntüleri gerçek pencere boyutunda
  (`--resolution`; ilk tur hep 720×1280'di) · araç / yorum / belge ufaklıkları.
  Bilinçli olarak bırakılan (owner
  kararı): Koleksiyon / Mağaza geri → Ana Sayfa (hub-and-spoke; Profil'e dönmez),
  `_finish_upgrade`'in round bitişiyle çakışan Büyütücü tier'ı (gameplay değişikliği
  owner onayı ister). *(A36 kapısında KAPANDI: avatar ↔ Profil geri çift dokunuşu ve
  günlük reveal'deki "Yeni Squishy" tekrarı — aşağıda.)*
- **Samsung A36 yerel kapısı (2026-09-28, yalnız QA paketi `…squishymerge.qa`, Google
  TEST reklamları; `com.example` / üretim paketi hiç açılmadı):** masaüstü 25 suite +
  bot L3 2/2 = 3673 kontrol (bulutla birebir) → düzeltmelerden sonra 3692, 0 hata.
  Cihazda: Ana Sayfa avatarı (seri pill'iyle 12 px boşluk, çakışma yok), Profil (boş /
  1 / 3 yuva, istatistikler kanonik alanlarla birebir, güçler, kaydırma, dudak / kırpma
  yok, banner YOK), Koleksiyon (20 parça 8/6/4/2, N/20 · VİTRİN N/3, TAK / TAKILI /
  Varsayılan yok, sahip / kilitli detay, VİTRİNE EKLE / ÇIKAR / AVATAR YAP, dolu vitrinde
  açık değiştirme adımı — VAZGEÇ ve Android geri yazmaz, yuva seçimi TEK yazma, 350 ms
  kilit ikinci dokunuşu yuttu), göç (eski `equipped_skin` → yuva 1; sahip olunmayan /
  katalogda olmayan / sayı / sözlük değer → boş vitrin; bozuk vitrin listesi doğrulanır;
  owner'ın masaüstü kaydı salt okunur: `rare_02` → yuva 1, dosya bayt-aynı), gameplay
  kanonik (Tier 1–8 + birleşme hayaletleri + Büyütücü sonucu; Legendary avatar / eski Epik
  takılı kayıtla ~315 bin parça-kare taraması 0 ihlal), sayaçlar (bitmiş round +1 tek
  sefer; terk / yeniden başlat sayılmaz; Büyütücü tier'ı sayılır), Profil dişlisi →
  aynı Ayarlar (ses / titreşim anahtarı cihazda etkili, gizlilik seçenekleri EEA formu),
  TASK/043 Profil yolundan (TEEN ↔ ADULT oturum kilidi, SDK değişmedi, soğuk açılışta
  yeni bant; UNKNOWN / UNDER_13 SDK yok), reklam yüzeyleri aynen. **Giderilen iki bulgu:**
  (1) hızlı çift dokunuş ekran geçişinden sıçrıyordu — avatar → Profil → aynı noktadaki
  geri → Ana Sayfa (ikinci dokunuş ~130 ms), KOLEKSİYONA GİT → altındaki kartın detayı,
  kart / Profil dişlisi → pencere karartmadan hemen kapanıyordu: Main geçişten
  (`_show_tab`, `open_settings`, detay açılışı) sonra 300 ms PARMAK basışlarını yutar
  (`_input`; kod yolu / masaüstü fare etkilenmez; `profile_test` 135 → 153, negatif
  kontrolde 6 kontrol düşüyor); (2) günlük reveal "YENİ SQUISHY" rozetinin altında
  "Yeni Squishy keşfedildi!" yazıyordu → başlık kartın kendi notu "keşfedildi!"
  (`collection_rework_test` 64 → 65). **Gözlem (TASK/044 öncesi, kapsam dışı):** Büyütücü
  hedefini seçen dokunuşun BIRAKIŞI bekleyen parçayı düşürüyor (`_handle_targeting_input`
  yalnız basışı tüketiyor). Kanıt: `build/qa_044/`.
- **Testler:** yeni `profile_test` (135; A36 kapısından sonra 153) +
  `collection_rework_test` (64; A36 kapısından sonra 65); yeniden
  yazılan `collection_ui_test` (164 → 205), `skin_test` (30 → 19: render hattı
  testleri emekli, kanonik görünüm kontrolleri eklendi), `ui_smoke_test` (74 → 57:
  equip akışı → vitrin akışı); güncellenen `home_ui_test` (208 → 216),
  `shop_ui_test` (213 → 215), `result_ui_test` / `economy_test` (metin). Tam
  regresyon 25 suite yeşil.

### 4.21 Player Progression V1 — oyuncu seviyesi / XP / başarımlar / unvanlar (TASK/045)

> **main'de** — `task/045-player-level-achievements` (başlangıç main `115252c`) owner
> onayıyla ff-only alındı (`115252c → d4c8548`, 2026-09-28); bulut kapısı + **Samsung A36
> yerel kapısı GEÇTİ (2026-09-28, yalnız QA paketi, bulgu yok)**. Kural metni: GAME_DESIGN
> §5.9; UI: UI_VISUAL_SYSTEM §23.

- **Owner kararı:** yerel bir ilerleme katmanı — kimlik "Oyuncu" kalır; hesap / takma ad /
  giriş / backend / bulut / sosyal / skor tablosu YOK; ekonomiye hiçbir etkisi YOK (başarım
  ve seviye Hamur / güç / sandık / reklam ödülü vermez; XP reklamla ya da satın almayla
  kazanılmaz).
- **Seviye / XP:** tek gerçek `player_xp` (kümülatif), seviye SAKLANMAZ — her okumada
  türetilir. Gereksinim `min(400, 60 + 20·(L−1))` (L18'den sonra hep 400; kümülatif eşik
  kapalı formla — 2,5 milyonluk seviye döngüsüz); seviye tavanı yok; bozukluk sınırı
  `MAX_XP` = 1 milyar. Saf servis `PlayerProgression` (eğri, ödül, göç, round özeti).
- **Kaynaklar (kilitli):** +1 / gerçek merge · +20 sabit level başarıyla bitince (tekrar da)
  · +10 / önceki en iyiye göre YENİ kalıcı yıldız. Başka hiçbir şey. Round kesinleştirmesi
  korumalı (`Main._round_finalized`, `_start_level` sıfırlar); XP TASK/044'ün
  `record_round_finished` yazmasında — inceleme sonrası level açılışı / yıldız / sonsuz rekor
  da `save=false` ile AYNI yazmaya katlanır (arada çökme XP'yi yıldızdan ayıramaz) ve giden
  board'un geç `round_finished`'i bağlantısı kesilerek yok sayılır.
- **Göç:** TASK/045 öncesi kayıtta bootstrap = merge + 10·yıldız + 20·tamamlanan level
  (örn. 812 + 60 + 60 = 932); bellekte, bir kez, idempotent, kutlamasız (sonuç şeridine
  girmez); bozuk XP aynı formülle kurtarılır. Okuyucular (`_safe_int` / `_as_int`) int64
  dışı / NaN float'ı ve 18 basamaktan uzun metni BOZUK sayar — `int()`'in platforma bağlı
  çevirisi (x86 INT64_MIN, ARM doygun) göçe / başarıma sızmaz (inceleme).
- **Başarımlar (12) + unvanlar (varsayılan + 8):** `AchievementCatalog` (saf). Kanonik
  istatistikten (toplam merge, kalıcı yıldız, tamamlanan level, sahip olunan katalog
  Squishy'si), monoton, geriye dönük SESSİZ; açılış istatistiği değiştiren işlemin kendi
  yazmasında (add_merges / record_stars / complete_level / grant_skin / Mağaza / günlük
  sandıklar). Bilinmeyen id yok sayılır ve sonraki kayıtta düşer. Unvan seçimi Profil'in
  TEK yazması (açık + farklı); yeni unvan otomatik seçilmez; geçersiz seçim varsayılana
  düşer, geri yazılmaz. Kayıt alanları: `player_xp`, `unlocked_achievements`,
  `selected_title_id`, `player_meta_version` (DATA_SAFETY_INVENTORY §2).
- **UI:** Profil kimliği (unvan hapı + LV rozeti + XP rayı "84 / 180 XP"), BAŞARIMLAR kartı
  ("N / 12" + 3 sıradaki hedef + TÜM BAŞARIMLAR), Profil'e ait Başarımlar / Unvanlar
  pencereleri (banner yok, geri kapatır, açmak / kapatmak yazmaz); sonuç ekranında kompakt
  bloklamayan şerit ("+42 XP", "SEVİYE ATLADIN! · LV. 8", "Başarım açıldı: X"); TASK/044'ün
  300 ms parmak yatışması pencerelere genişletildi. Tutorial: tamamlanma XP vermez;
  tutorial'ın Level 1 round'u normal XP alır, geri bildirim yalnız sonuç ekranında.
- **Değişmeyen (dondurulmuş):** sandık 60/25/12/3 + %30 parça, fiyatlar 50/150/400/900, güç
  fiyatları 100/120/160/180, Hamur ödülleri, reklam yüzeyleri ve geçiş kadansı, TASK/043
  yaş yönlendirmesi, fizik / merge / skor / yıldız / level kuralları. Bilinen Büyütücü
  bırakış-düşürme sorunu (TASK/044 gözlemi) DOKUNULMADI.
- **8 mercekli çekişmeli inceleme (kayıt / XP / başarım / unvan / UI / dokunma / ekonomi /
  araç):** BLOCKER 0 · HIGH 0 · MEDIUM 2 → ikisi de giderildi: başarım rozetinin hedef
  çipi kartın pişmiş dudağına biniyordu (çip rozet kutusuna dahil) · `progression_ui_test`'in
  "açılışın hemen ardından ikinci dokunuş yutuldu" kontrolü düşemiyordu (ikinci dokunuş
  artık eylemli hedefe). LOW 10 → hepsi giderildi: platforma bağlı int çevirisi + metin
  merge tutarlılığı · round kesinleştirmesi tek yazma · round sonunda `progression_stats`
  her çağrıda 11 .tres'i yeniden okuyordu (~2,5 ms × 5–7; level numarası önbelleği) · A36
  benzeri üst payda tam boy pencerenin kurdele / X'i durum çubuğuna giriyordu
  (`UiKit.seat_modal_below_safe_top`) · otomatik günlük pencere Profil penceresinin üstüne
  açılabiliyordu · seçim pop'u gerçek dokunuşta görünmüyordu (ertelendi) · HAPTIC / AUDIO
  belgeleri · `progression_shots` anormal çıkışta kaydı geri koymuyordu (bekçi + `_exit_tree`
  + `--headless` reddi) · yük altında oynayan zamanlama kontrolleri · yanlış sebeple
  geçebilen kontroller (işlem sonucu doğrulanmıyordu; tohumsuz günlük kura). NIT 8 → 6
  giderildi; bilerek bırakılan 2: unvan seçiminde üç kez tazeleme (önbellekten sonra
  ihmal edilebilir; seçici tek başına da doğru kalsın) · seviye + adlı başarım hapı dar
  ekranda iki satıra sarar (akış kabı; kırpma yok). **Kapsam dışı kayıt (düzeltilmedi):**
  `save_game()` dosyayı kesip yazıyor (atomik değil) — yazma sırasında öldürülen süreç
  okunamayan kayıt bırakır ve yükleme varsayılanlara döner (TASK/045 öncesi; ayrı bir görev
  olarak önerilir: geçici dosyaya yaz + yedekten kurtar). Koleksiyon detayı da otomatik
  günlük pencere kapısında yok (TASK/044).
- **Testler / kanıt:** yeni `player_progression_test` (83), `achievement_test` (61),
  `progression_ui_test` (187); güncellenen `profile_test` (153 → 154), `tutorial_test`
  (200 → 205: tutorial tamamlanması 0 XP, tutorial round'u = merge XP'si, özet sonuç
  ekranında). Tam regresyon 28 suite + bot L3 2/2 = 4067 kontrol, 0 hata, 0 SCRIPT ERROR
  (`revive_test` kontrol sayısı fizik zamanlamasıyla değişir — grant başına 18 kontrol; önceden
  de öyle). Not: `economy_test` (tasarımı gereği), `gameplay_shell_test` ve bot kaydı yeniden
  yazar — owner'ın yerel tam koşusu kaydı DIŞARIDAN yedeklemeli (TASK/045 suitleri kendileri
  bayt-aynı geri koyar). Mutasyon testleri (XP sınırı,
  yinelenen kesinleştirme koruması, başarım eşiği, kilitli unvan seçimi, seçili unvan
  doğrulaması, parmak yatışması + inceleme düzeltmeleri) hepsi ÖLDÜ, kaynak bayt-aynı geri
  kondu. Ekran görüntüleri 320×568 / 360×640 / 390×844 / 360×800 / 1080×2340 / 1080×2340
  güvenli pay 61 (`tools/progression_shots.tscn`, boyut doğrulamalı). Bulutta
  doğrulanamayan: fiziksel A36, owner masaüstü kaydı, owner-local `export_presets.cfg`,
  telefon paketi.

### 4.22 Kalıcılık ve girdi sağlamlaştırması (TASK/045.1)

> **main'de** — `task/045-1-persistence-input-hardening` (başlangıç main `017f2dc`) owner
> onayıyla ff-only alındı (`017f2dc → 5b1f952`, 2026-09-29); **Samsung A36 yerel kapısı GEÇTİ
> (2026-09-29)** — iki kurtarma bulgusu dalda giderildi (aşağıda). TASK/045'in üç kararlılık
> takibi; kapsam bunlarla sınırlı (TASK/046 BAŞLAMADI — o an; sonra main'de, §4.24).

- **(A) Çökmeye dayanıklı kayıt.** Eski `save_game()` kanonik dosyayı `FileAccess.WRITE` ile
  yerinde kesip yazıyordu: yazma sırasında çökme / öldürme / disk hatası okunamayan bir kayıt
  bırakıyor, açılış varsayılanlara dönüp ilerlemeyi siliyordu. Yeni `SaveFile`
  (`scripts/autoload/save_file.gd`, autoload değil) işlemi: yük bellekte geri okunabilir bir
  sözlük olarak doğrulanır → kanonik yok / bozukken kurtarılacak tek kopya olan bir `.tmp`
  önce kanonik ada taşınır (olmazsa kayıt yapılmaz) → aynı klasörde `.tmp`'ye yazılır,
  kapatılır, bayt bayt geri okunur (FileAccess `close` hatası bildirmiyor) → eski kanonik
  `.bak`'a TAŞINIR ve **bir önceki kayıt olarak kalır** (duran `.bak`'ın üzerine yalnız geçerli
  bir kanonik) → `.tmp` artık boş olan kanonik ada TAŞINIR. Godot 4.6.3 kaynağı:
  `DirAccess.rename` Windows'ta hedefi önce siler sonra taşır (atomik değil), Android / Linux'ta
  `rename(2)` atomik — bu sıra hiçbir platformda üzerine-atomik-yeniden-adlandırmaya güvenmez.
  Hata: `false` + push_error (dosya adı + aşama + hata kodu; içerik yok), taahhüt başarısızsa
  eski kayıt geri taşınır, fazla `.tmp` yalnız kanonik ad doluyken silinir (boşsa doğrulanmış
  yeni kaydın tek kopyasıdır), bellek değişmez (sonraki kayıt yeniden dener).
- **Kurtarma (deterministik):** geçerli kanonik HER ZAMAN kazanır (bayat `.tmp` silinir —
  taahhüt edilmemiş yeni kayıt da; `.bak` kalır); kanonik yok / bozuksa geçerli `.tmp` (yer
  değiştirme anında kesilen işlemin doğrulanmış yeni kaydı) kanonik ada taşınır, yoksa geçerli
  `.bak` — yalnız kanonik ad doluyken (bozuk / okunamıyor; ona dokunulmaz, sonraki kayıt
  onun yerine geçer) ya da `.tmp` izi varken (kanonik ad boşsa `.bak`'tan kopyalanarak geri
  kurulur, iz ancak ondan sonra atılır). Kanonik ad boş ve `.tmp` yoksa kayıt bilerek
  silinmiştir → temiz başlangıç (artık `.bak` silinir; mevcut "kaydı sil" test akışları aynen);
  kendi yazma / kurtarma yollarımız kanonik adı `.tmp` olmadan boş bırakmaz. Hiçbiri yoksa eski davranış (dosya yok → yeni oyuncu + başlangıç hediyesi; bozuk →
  varsayılanlar, yazma yok). Yol, JSON şeması, biçim aynı; göç yok; geçerli kayıtla yükleme
  kanonik dosyaya yazmaz. **Sınır:** Godot fsync sunmuyor — ani güç kaybı / zorla yeniden
  başlatmada yeni kaydın verisi diske inmeden yeniden adlandırmalar inebilir; o zaman bir önceki
  kayıt (`.bak`) kurtarılır (en kötü bir kayıt geri; saniyeler içinde art arda kayıtlarda o da
  henüz diskte olmayabilir — o zaman eski yerinde yazıcıyla aynı en kötü durum). Açılamayan dosya
  kısa aralıklarla yeniden denenir (geçici kilit); hâlâ açılamıyorsa bozuk sayılır.
- **(B) Güç hedefleme bırakışı.** Kök neden: `_handle_targeting_input` yalnız basışı
  işliyordu; güç basışta çözülüp silah indiği için aynı parmağın bırakışı normal yola düşüp
  `_drop()` çağırıyordu (Büyütücü ve Bomba; boşluğa dokunup iptal de). Düzeltme:
  hedefleme modunda basılan dokunuş parmak indeksine göre "tüketilmiş dizi"; sürüklemesi ve
  bırakışı yutulur, bırakış diziyi kapatır; aynı parmağın yeni basışı da kapatır (kayıp
  bırakışta takılı bastırma yok), diğer parmaklar bağımsız, duraklamada gelen bırakış da
  kapatır. Zamanlayıcı YOK; Main'in 300 ms parmak yatışması ayrı ve aynen. Güç kuralları,
  stok, efektler, T7→T8 kutlaması, anında güçler DEĞİŞMEDİ.
- **(C) Koleksiyon detayı günlük pencere kapısında.** `Main._maybe_auto_open_daily_rewards`
  detay açıkken (`CollectionScreen.is_detail_open`) "görüldü" işaretinden ÖNCE döner: pencere
  tüketilmez, sonraki `_show_tab` / öne dönüşte açılır. Profil vitrini → parça detayı geçişi
  pencereyi artık detay açıldıktan SONRA dener (eskiden pencere önce açılıp detay altında
  kalıyordu); detaydaki MAĞAZAYA GİT (hedef karta kaydıran Mağaza geçişi) ertelenen pencereyi
  hiç denemez. Günlük kadans / ödül / uygunluk DEĞİŞMEDİ.
- **Yaş bandı + gizlilik (TASK/043 sözleşmesi korunur):** `.bak`'tan (bir önceki kuşak)
  kurtarılan kayıtta yaş bandı bellekte `UNKNOWN`'a düşer — reklam SDK'sı / UMP başlamaz, yaş
  yeniden sorulur (bozuk kayıtla aynı fail-closed sonuç); geçiş günü (doğum gününe eşdeğer)
  silinince (ADULT) `.bak` da atılır ("ADULT olunca silinir" sözü o kopya için de geçerli).
  *(A36 kapısı düzeltmesi: kanonik ad `.bak`'tan kopyayla geri kurulduysa `UNKNOWN` yüklemede
  hemen kalıcılaşır; `.bak`'tan kurtarılan oturumdaki ADULT girişi de `.bak`'ı atar.)*
- **Çekişmeli inceleme (6 mercek + ikinci tur; salt okuma):** BLOCKER 0 · HIGH 0. MEDIUM 5 → 4
  giderildi, 1 hafifletildi. Giderilen: kurtarılacak tek kopya `.tmp`'nin üzerine yazılıyordu
  (önce terfi) · `.bak` taahhütten hemen sonra siliniyordu, yeniden adlandırma boş ada olduğu için
  ext4'ün "üzerine yeniden adlandırma" yıkama sezgisi yoktu → zorla yeniden başlatmada
  kurtarılacak kayıt kalmayabiliyordu (`.bak` artık bir önceki kuşak) · `.bak` kurtarması kanonik
  ad boşken kendi `.tmp` izini silip bir sonraki açılışta "bilerek silinmiş kayıt" sanılıyordu
  (kanonik önce `.bak`'tan geri kurulur; hata yolları `.tmp`'yi yalnız kanonik ad doluyken atar) ·
  iki güç kontrolü bekleme süresi yüzünden düzeltmesiz de geçiyordu (güçlendirildi). Hafifletilen
  (kod değişmedi): gerçek kaydı yazan eski suite'ler sahibin `.bak`'ına test verisi bırakıyor /
  taze kurulum benzetiminde siliyor → aileyi geri koyan koşucu + belge (aşağıda "Masaüstü test
  notu"); eski harness'lerin geri koyma yardımcılarına ortak bir aile koruyucusu eklemek ayrı bir
  izleme işi olabilir. LOW → giderilen: MAĞAZAYA GİT hedef kartı kaybediyordu · `.bak`
  kurtarmasında bayat yaş bandı · ADULT sonrası `.bak`'ta geçiş günü · geçici kilitli dosya (kısa
  yeniden deneme) · günlük "yazılmadı" kontrolü yazmayı göremiyordu (bellek işareti) · şema kendi
  kendisiyle karşılaştırılıyordu (sabit anahtar listesi) · eksik ön koşullar · Windows
  `rename` biçimli hata enjeksiyonları. **Bilerek bırakılan / kapsam dışı (owner kararı ya da TASK/045.1 öncesi):** iki
  parmakta, hedefleme parmağı basılıyken İKİNCİ parmağın bağımsız dokunuşu düşürür (ayrı dizi —
  tasarım gereği, testli); `canceled` normal dokunuş düşürür (öncesi; *TASK/046.2'de dalda giderildi, §4.26*); Android'de Ayarlar dişlisi
  sonrası 300 ms yatışma dokunuş odağını dişlide bırakabilir (TASK/044 — A36 kapısında
  doğrulanmalı); güç silahlıyken round donunca önizleme görünür (kozmetik, öncesi); öne dönüşte
  günlük GİRİŞ ödülü pencereyle çözülür — pencere ertelenip kabuğa hiç dönülmeden ertesi güne
  kalınırsa o gün sayılmaz (öncesi; DAILY_REWARDS §7); kalıcı okuma hatası (açılamayan dosya)
  bozuk sayılır (öncesiyle aynı).
- **Testler / kanıt:** yeni `save_persistence_test` (108), `power_input_test` (58),
  `daily_popup_gate_test` (29) — üçü de YALNIZ test yolu kullanır (`SaveManager.save_path`
  yönlendirmesi), sahibin kaydına dokunmaz. Mutasyonlar 20/20 ÖLDÜ (atomik olmayan
  geri dönüş, başarısız yazmada kanonik yıkımı, tüketim koruması, detay kapısı + inceleme
  kuralları), kaynak her seferinde HEAD blob'una bayt-aynı geri kondu. Gerçek süreç öldürme
  dayanıklılık testi (yalıtılmış ayrı proje + ayrı userdata, `build/qa_045-1/soak/`): 360 sert
  öldürme (TerminateProcess; son commit'in `SaveFile`'ı ile 80), hepsi geçerli kayıt, sayaç
  gerilemesi 0 (öldürme pencereleri `.tmp` yazımı / taahhüt / yer değiştirme arası — yer
  değiştirme arasında kalanlar `.tmp`'den kurtarıldı). Tam regresyon: 29 kanonik suite + bot
  L3 2/2 = 4029 kontrol (başlangıçla aynı) + 3 yeni suite 195 = 4224, 0 hata, 0 SCRIPT ERROR;
  sahibin masaüstü kaydı bayt-aynı. **Masaüstü test notu:** gerçek kaydı yazan eski
  suite'ler yalnız kanonik baytları geri koyar; artık kaydın `.bak`'ı (bir önceki kuşak) test
  verisiyle kalabilir ya da taze kurulum benzetiminde silinebilir — koşucu kayıt AİLESİNİ
  (kanonik + `.tmp` + `.bak`) yedekleyip her suite'ten sonra geri koymalı
  (`build/qa_045-1/tests/run_suites.sh`).
- **Samsung A36 yerel kapısı (2026-09-29, yalnız QA paketi `…squishymerge.qa`, Google TEST
  reklamları; kanıt `build/qa_045-1-gate/`): GEÇTİ — iki bulgu giderildi.** Masaüstü: 32/32 suite
  4224 kontrol (bulutla aynı), düzeltmeden sonra 4227 (`save_persistence_test` 111), 0 hata, 0
  SCRIPT ERROR; sahibin kayıt ailesi bayt-aynı. Cihaz: gerçek dokunuşla güç / Squishy satın alma,
  unvan, vitrin, günlük sandık, round → her kayıtta kanonik = en yeni, `.bak` = bir önceki kuşak,
  `.tmp` yok; soğuk açılış en yeni ilerleme; kayıt süresi medyan ~2,2 ms (en çok ~7 ms), eylem
  karelerinde görünür takılma yok. Kurtarma A–E + kanonik yok / bozuk varyantları; kayıt
  aşamasında gerçek süreç ölümü (SIGKILL) ve dışarıdan sert öldürme sınaması (25 + 13 öldürme,
  hepsi geçerli, gerileme yok). Bomba / Büyütücü: dokun, hızlı ikinci dokunuş, uzun basış, kısa
  sürükleme, iptal, geçersiz hedef, T7→T8, iki parmak (A gerçek, B Godot girdi katmanında —
  cihazda adb çoklu dokunuş SELinux'ta kapalı) — hedef bir kez, stok −1, bırakış düşürmez, sonraki
  bağımsız dokunuş hemen düşürür. Günlük pencere: Koleksiyon detayı / değiştirme adımı / sekme
  tazeleme / arka plan-öne dönüş / gün değişimi / MAĞAZAYA GİT / Başarımlar / Unvanlar → pencere
  açılmaz, "due" kalır, sonraki güvenli geçişte açılır. **Giderilen bulgular** (`[M10] Fix
  persistence and input A36 gate findings`): (1) kanonik ad boşken `.bak` kanonik ada KOPYALANIP
  bellekteki `UNKNOWN` diske yazılmadığından, yaş sorusunda çıkılıp yeniden açılışta eski bant
  (A36'da ADULT) okunup reklam SDK'sı açılıyordu → `UNKNOWN` yüklemede kalıcılaşır; (2) bozuk
  kanonik + tarihli `.bak`'tan kurtarma sonrası ADULT girişinde `.bak` eski geçiş gününü
  taşıyordu → o oturumda `.bak` da atılır. **Önceden var olan, kapsam dışı (düzeltilmedi):**
  oyun içi Ayarlar dişlisiyle açılıp Android geri tuşuyla kapatılınca ilk tahta dokunuşunun
  bırakışı kayboluyor (düşürmüyor; ikinci dokunuş normal) — 300 ms yatışma dişlinin kendi
  dokunuş bırakışını yutuyor, GUI dokunuş odağı dişlide kalıyor (TASK/044; KAPAT / karartma
  dokunuşuyla kapatınca yok). *(→ TASK/045.2 ile düzeltildi, main'de `a32ee2d`, §4.23.)*

### 4.23 Ayarlar geri girdi odağı (TASK/045.2)

> **main'de** — `task/045-2-settings-back-input-focus` (başlangıç main `e474fb3`); bulut kapısı
> geçti; **Samsung A36 yerel kapısı GEÇTİ (2026-09-29)** — yalnız QA paketi, bulgu yok, düzeltme
> commit'i yok; owner onayıyla ff-only main'e alındı `e474fb3 → a32ee2d` (merge commit yok, ağaç
> eşit). Kapsam yalnız bu hata (TASK/046 BAŞLAMADI — o an; sonra main'de, §4.24).

- **Hata (A36, 3/3):** oyun içi dişli → Ayarlar → Android geri → 300 ms'den sonra ilk tahta
  dokunuşunun bırakışı kayboluyor (parça düşmez; ikinci dokunuş normal); KAPAT / karartma
  dokunuşuyla kapatınca yok.
- **Yeniden üretim (bulut, düzeltmeden ÖNCE):** gerçek Main + Level 8; parmak olayları
  `Input.parse_input_event` ile (cihaz sırası: öykünen fare önce, ScreenTouch sonra), geri =
  pencerenin GO_BACK bildirimi yayılımı. Olay kaydı: dişli basışı (fare + ScreenTouch) dişliye;
  fare bırakışı dişliye → Ayarlar + yatışma; aynı dokunuşun ScreenTouch bırakışı `Main._input`'ta
  yutuldu, dişliye ULAŞMADI. Geri → ilk tahta dokunuşu: basış tahtaya (nişan 640 → 760),
  sürükleme ve bırakış DİŞLİNİN `gui_input`'una (nişan 760'ta kaldı, drop 0); ikinci dokunuş
  drop 1. KAPAT / karartma: kapanış dokunuşu odağı ezdi, ilk dokunuş drop 1 (nişan sürüklemeyi
  izledi).
- **Kök neden (Godot 4.6.3 kaynağıyla doğrulandı):** `Input::_parse_input_event_impl`
  dokunuştan öykünen fare olayını aynı ScreenTouch'tan ÖNCE dağıtır. Dişlinin `pressed`'i
  (öykünen bırakışta) yatışmayı başlatınca eski `_input` pencerede HER parmak olayını (bırakış
  dahil) yuttuğu için aynı dokunuşun ScreenTouch bırakışı GUI'ye hiç ulaşmadı. `Viewport`
  ScreenTouch basışında `gui.touch_focus[index]` kaydeder, yalnız o indeksin bırakışı GUI'ye
  ulaşınca siler; sürükleme ve bırakış bu kayda yönlendirilir. Odak dişlide asılı kaldı;
  dokunuşsuz geri kapanışından sonra ilk tahta basışı kontrole değmediği için odağı ezmedi,
  sürükleme + bırakış MOUSE_FILTER_STOP dişliye gidip tüketildi (GameBoard bırakışı hiç
  görmedi). Profil yolunda belirti yoktu: sonraki basış her zaman bir kontrole değip odağı ezer,
  Profil butonları öykünen fareyle çalışır.
- **Düzeltme (yalnız `scripts/main.gd` `_input`):** yatışma DİZİ bazında. Anahtar: gerçek
  ScreenTouch / ScreenDrag'de parmak indeksi, dokunuştan öykünen farede tek anahtar. Pencerede
  BAŞLAYAN dizi (basış) yutulur ve kaydedilir; sürüklemesi / öykünen hareketi ve bırakışı (iptal
  dahil, pencere bitmiş olsa da) yutulur, bırakış kaydı kapatır; aynı anahtarın yeni basışı eski
  kaydı kapatır (kaybolan bırakışta takılı bastırma yok). Pencereden önce başlamış dizi hiç
  bölünmez → dişlinin kendi bırakışı GUI'ye ulaşır, odak kapanır; bırakış basışın kontrolüne
  gittiği için yeni açılan pencerenin karartmasına / tahtaya düşmez. 300 ms, masaüstü fare / kod
  yolu muafiyeti aynen; yeni zamanlayıcı / bekleme yok.
- **Korunan:** TASK/044 çift dokunuş (avatar ↔ Profil geri, Profil dişlisi → Ayarlar
  karartması, parça detayı karartması, KOLEKSİYONA GİT → kart) ve TASK/045 Başarımlar /
  Unvanlar korumaları (profile_test, progression_ui_test, collection_ui_test aynen geçiyor;
  yatışmayı kapatan mutasyonu yakalıyorlar); TASK/045.1 hedefli güç tüketimi; Sarsıntı /
  Temizleyici; gameplay, ekonomi, ilerleme, kayıt işlemi, günlük pencere, reklam sözleşmesi,
  TASK/043 DEĞİŞMEDİ.
- **Testler:** yeni `settings_input_test` (160 kontrol, yalnız test yolu; sahibin kayıt ailesine
  dokunmaz): oyun içi dişli → GERİ / KAPAT / karartma (tek kapanış, dişli kendi bırakışını alır,
  yatışma biter, İLK bağımsız dokunuş: basış + sürükleme nişanı taşır, bırakış tam bir drop;
  hızlı ikinci dokunuş tahtaya ulaşır ama cooldown aynen, güç yok), parmak 1 + indeks 0 yeniden
  kullanımı, masaüstü fare, yatışma içinde geri + pencerede başlayan tahta dizisi (tamamı Main'de
  yutulur — pencere sonrası sürükleme / bırakış dahil, dişliye de gitmez), kaybolan ve iptal
  edilen bırakış, iki parmak (pencereden önce basan bölünmez, pencerede basan tamamen yutulur),
  çift dokunuş, Bomba / Büyütücü silahlıyken GERİ → ilk dokunuş hedef (bırakış tüketilir, dizi
  kapanır), Profil dişlisi üç yol + çift dokunuş, Mola / Refill / Devam, Koleksiyon detayı (basılı
  kart + GERİ dahil) / Başarımlar / Unvanlar / Günlük / Sandık (GERİ → ilk dokunuş). Arka arkaya
  koşularda kararlı. Negatif kontrol: düzeltmesiz (`e474fb3`) Main ile 26 FAIL (21 davranış + 5
  yapısal: yeni alan / kaynak sözleşmesi), 0 SCRIPT ERROR. Mutasyonlar 5/5 öldü (düzeltme atlama,
  yatışma kapalı → profile / progression_ui de düşer, yalnız-bırakış koruması, hedefleme tüketimi
  kapalı → power_input de düşer, tüm parmakları tek anahtara indirme); kaynak her seferinde
  bayt-aynı geri kondu. Tam regresyon: 31 kanonik suite + yeni suite + bot L3 2/2, 0 hata, 0
  SCRIPT ERROR (motorun çıkıştaki "resources still in use" satırları koşudan koşuya değişen
  gürültü; düzeltmesiz Main ile de aynı).
- **Çekişmeli inceleme (4 mercek, salt okuma):** BLOCKER 0 · HIGH 0. Tüm TASK/044 / TASK/045
  korumaları olay sırasıyla yürütülüp korunmuş bulundu; kök neden motor kaynağıyla teyit edildi
  (ayrıca eski davranışın pencereye taşan bir basışta butonun `pressed_down_with_focus`
  durumunu asılı bırakması da kalktı). MEDIUM 1 (tüm parmakları tek anahtara indiren mutasyon
  hayatta kalıyordu → iki parmak testi) + LOW 6 (yanlış nedenle geçen kontroller, hızlı dokunuş
  kanıtı, iptal testi, cooldown ön koşulu, bekçi yolu, basılı kart + GERİ boşluğu) + NIT 5
  giderildi. Bilerek bırakılan: pencere sınırında (milisaniye altı) bir dokunuşun iki yarısının
  ayrı karar alması (temelle aynı, iki akış da dengeli) · Ayarlar kapanınca pencereyi sıfırlamak
  (yatışmayı zayıflatır) · tipli sözlük (kod tabanı idiomu değil) · power_input_test etiketi
  (TASK/045.1 dondurulmuş). Pencereden önce ikinci parmakla tahtaya basılıp hızlı GERİ'den sonra
  kaldırılırsa parça düşer — o parmağın kendi dizisi, bilerek (testli).
- **Önceden var olan, kapsam dışı (düzeltilmedi):** (1) *(→ TASK/046.2'de dalda giderildi, §4.26)* iptal edilen dokunuş (Android
  ACTION_CANCEL — hareketle gezinmede kenardan geri kaydırma) GameBoard'da normal bırakış gibi
  parça düşürür ve karartma pencereyi kapatır (TASK/045.1'de de not edildi); hareketle gezinmede
  cihazda henüz doğrulanmadı. Düzeltmesi gameplay girdisini değiştirir → owner onaylı ayrı görev; Main'de
  yutmak DEĞİL (asılı odak hatası geri gelir), GameBoard'da `canceled` bırakışı düşürmeden
  kapatmak. (2) Godot, basılı butonu gizlerken ona sentetik bırakış gönderir
  (`_drop_mouse_focus`): kart basılıyken GERİ ile Koleksiyon'dan çıkılırsa detay bazen gizli
  albümde açılır — 25 turluk ölçüm temel 11 / düzeltme 10, fiziksel bırakışla 0 / 0; `Main._input`
  ile ilgisiz. (3) Yatışma olayın dağıtım anına göre ölçülür; geçişten sonra 300 ms'yi aşan ilk
  çizim takılması gerçek bir çift dokunuşu geçirebilir (temelle aynı; sertleştirme owner kararı).
- **Samsung A36 yerel kapısı (GEÇTİ 2026-09-29, yalnız QA paketi, 3 tuşlu gezinme):** oyun içi
  dişli → GERİ → ilk tahta dokunuşu 5/5 (+0,4 sn beklemeyle 2/2): basış + bırakış tahtaya,
  nişan dokunulan x'e, bırakışta tam bir drop, ikinci dokunuş gerekmedi (dişlinin kendi
  bırakışı dişliye ulaştı); düzeltmesiz temel APK (`e474fb3` main.gd) aynı sürücüyle 2/2 eski
  hatayı gösterdi. KAPAT 2/2, karartma 2/2, Profil dişlisi üç yol; hızlı GERİ + pencerede
  başlayan tahta dizisi 4/4 tamamen yutuldu (pencere sonrası bırakış dahil); TASK/044 / 045 çift
  dokunuşları; basılı sürükleme ve hızlı ikinci dokunuş (cooldown aynen); Bomba / Büyütücü;
  Mola / Günlük / Detay / Sandık / Refill / Devam; kayıt kurtarma, TASK/043 yönlendirmesi,
  ilerleme aynen. Önceden var olanlar yeniden üretildi, düzeltilmedi: gerçek ACTION_CANCEL *(→ TASK/046.2, §4.26)* 2/2
  parça düşürdü (yukarıda (1); hareketle gezinme denenmedi — telefon ayarı değiştirilmedi);
  basılı kart + GERİ detayı 5/5 gizleme anında açtı, fiziksel bırakışta 0/5 (yukarıda (2)).

### 4.24 Günlük / Haftalık Görevler V1 (TASK/046)

> **main'de** — `task/046-daily-weekly-missions` (başlangıç main `56106ef`): `efb9763` çekirdek ·
> `6543492` arayüz + sonuç rozeti · `137c219` inceleme düzeltmeleri · `5092dad` regresyon /
> görsel kapı araçları + dokümanlar. Masaüstü doğrulama (2026-09-29) + **Samsung A36 yerel kapısı
> GEÇTİ (2026-09-30)** — yalnız QA paketi, TASK/046 bulgusu yok, düzeltme commit'i yok; TASK/046.1
> ile birlikte owner onayıyla ff-only main'e alındı `56106ef → b90bc3c` (merge commit yok).
> TASK/047 BAŞLAMADI. Kurallar ve sayılar GAME_DESIGN §5.10'da kilitli,
> görünüm UI_VISUAL_SYSTEM §24.

- **Katalog (kilitli, ayar yok):** günlük `daily_merges` "15 birleşme yap" · `daily_rounds` "2 tur
  tamamla" · `daily_clear` "1 level tamamla" (+10'ar); haftalık `weekly_merges` 120 ·
  `weekly_rounds` 12 · `weekly_clears` 5 (+40'ar). Günde ≤ 30, haftalıklardan ≤ 120, haftada ≤ 330
  Hamur; tek round'da en fazla +150.
- **Model:** `scripts/game/missions.gd` (`Missions`, saf `RefCounted` — yeni autoload YOK): katalog
  + metin tablosu, katı gün anahtarı (`YYYY-MM-DD`, gerçek tarih, yıl ≥ 2000), pazartesi haftası
  (`week_start`), `sanitize` (sözlük değil / bilinmeyen sürüm / bozuk gün → dönem yok; bilinmeyen /
  öteki dönemin id'si düşer; tekrar işaret tekilleşir; ödüllü = hedef, ödülsüz ≤ hedef − 1; NaN /
  negatif / dev değer kırpılır; ham dizi 32 ile sınırlı; deterministik, idempotent), `for_day`
  (dönem kayıttakinin GERİSİNE düşmez; yeni gün günlükleri sıfırlar, aynı pazartesi haftasında
  haftalık aynen), `advance` (saf; hedefte kırpar, ödüllü görevi atlar, ilk ulaşmada ödül; katalog
  sırası), `rows`. **SaveManager:** `DEFAULT_DATA.missions` (sürüm 1), `_migrate_missions`
  (yüklemede yalnız bellekte: geçerli durum doğrulanır, yoksa kabul edilen günün taze dönemi —
  geriye dönük ilerleme / Hamur / kutlama YOK; ikinci yükleme aynı), `missions_state()` (salt
  okuma), `record_mission_round(merges, fixed_level_cleared, save)` (tek mutasyon: ilerleme + ödül
  işareti + Hamur). **Main:** `_on_round_finished`'da kesinleştirme korumasından SONRA, round
  kaydından ÖNCE `record_mission_round(merges, fixed_cleared, false)` → `record_round_finished`
  TEK yazma (XP / yıldız / level / görev / görev Hamur'u aynı işlemde); `merges` = TASK/045 XP'siyle
  aynı `GameState.merge_count`, `fixed_cleared` = sabit level başarıyla (sonsuz / kayıp değil).
  Terk / yeniden başlatma / `_clear_board` / süreç ölümü görev çağırmaz; giden board'un geç
  sinyali, bağlantısı kesildiği için ulaşmaz. SaveFile (TASK/045.1) DEĞİŞMEDİ.
- **Saat:** kabul edilen gün = `DailyRewards.day_key()` (geri alınan saatte görülen en yeni gün —
  ayrı saat YOK); o bozuksa cihaz günü; o da geçersizse yeni dönem açılmaz (kayıtlı dönem varsa
  round ona işlenir, ödül işaretleri geçerli). Görevler `last_seen_day_key` YAZMAZ (DailyRewards
  davranışı donmuş — aşağıda kabul edilen LOW).
- **Arayüz:** Ana Sayfa'da tek GÖREVLER girişi (`ButtonHomePill` 206..260×56, nane kuyu + hedef
  picto + "GÖREVLER" + "N/6" rozeti — 6/6'da nane; üst madalyon sırasında Günlük ile Mağaza
  arasında; 2+2 madalyon, maskot, OYNA, beş ekran aynen). `MissionsOverlay` (katman 12,
  `modal_shell` "GÖREVLER" 600; hero "N / 6" + ray + otomatik ödül notu; GÜNLÜK / HAFTALIK
  bölümleri + sabit "Yarın yenilenir" / "Pazartesi yenilenir"; 3'er `MissionCard`; tek buton X;
  kayda yazmaz). `ResultProgressStrip`'e nane görev hapı ("GÖREV TAMAMLANDI · +10 HAMUR" / "2 GÖREV
  TAMAMLANDI · +50 HAMUR"; bloklamaz, dokunma almaz). Açılış / kapanış 300 ms parmak yatışmasını
  başlatır (TASK/045.2 dizi kuralı aynen); geri tuşu Günlük'ten sonra kapatır; tutorial / round /
  başka ekran / yaş–kısıt ekranı / başka ikincil pencere varken açılmaz; açıkken otomatik günlük
  pencere "due" kalır; ekran değişimi / round başlangıcı / yaş sorusu kapatır; öne dönüşte ve
  açılışta rozet + pencere aynı döneme tazelenir.
- **Reklam / yaş:** görev kodu reklam / rıza / yaş / Age Signals okumaz; yeni banner yüzeyi yok
  (pencere Ana Sayfa yuvasının üstüne oturur), tamamlanma reklam çağırmaz, sonuç ekranı banner'sız
  aynen; interstitial kadansı aynen.
- **Ekonomi (eklemeli analiz, ayar YOK):** `python tools/missions_economy.py` — görev Hamur'unun
  mevcut haftalık gelire eki: koleksiyon eksik reklamsız +%7 (yoğun, yalnız sonsuz) … +%46
  (kasual L4–L7), günlük ödüllü reklamlarla +%5 … +%17; koleksiyon tamam +%5 … +%34 / +%4 … +%14.
  Yalnız sonsuz oynayan haftada en fazla 220 alır. Fiyat / sandık / günlük ödül / kota DEĞİŞMEDİ.
- **Testler (yalnız test kayıt yolu; sahibin ailesine dokunmaz):** yeni `missions_test`
  (136 kontrol: katalog, gün / hafta — 1200 ardışık gün kaba kuvvet, doğrulama, dönem, ilerleme,
  göç / kurtarma — CRASH_AFTER_BACKUP `.tmp` kurtarması + yırtık kanonik `.bak`, saat — geri alma /
  bozuk saat, gerçek Main round akışı a–m, tutorial round'u, sahte arka uçla reklam yok + sonuç
  banner'sız, kaynak sözleşmesi) · yeni `missions_ui_test` (139: giriş + N/6, pencere içeriği,
  TAMAMLANDI çipi + durum halkası, girdi — geri / X / karartma / gerçek parmakla hızlı çift dokunuş,
  kapılar + kendiliğinden kapanış, 5 görünüm + A36 üst payı — kırpma / çakışma / maskot pikseli /
  halka kırpılması, uzun metin, dil, banner yuvası, yazma girişimi dedektörü, öne dönüşte gün
  dönümü) · `result_ui_test` 226 → 265 (görev hapı + TASK/045 hapları birlikte, en uzun şerit
  her boyutta + A36, gerçek round TEST yolunda + gerçek kayıt bayt-aynı) · `revive_refill_ui_test`
  ve `result_ui_test`'in kesin "+teselli" kontrolleri bugünün görevleri ödüllü sabitlenerek sahibin
  kayıt durumundan bağımsız · `save_persistence_test` şema anahtarı. **Tam regresyon (`137c219`
  ağacı, `--import` sonrası):** 35 koşu (34 test suite'i — 32 mevcut + 2 yeni — ve bot L3 2/2):
  **4744 kontrol, 0 hata, 0 SCRIPT ERROR**; sahibin kayıt ailesi her suite'ten sonra bayt-aynı
  (motorun çıkıştaki "resources still in use" satırları bilinen gürültü). Taban (main `56106ef`,
  dal açılmadan önce): 33 koşu (32 suite + bot), 4387 kontrol, 0 hata.
- **Mutasyonlar (16/16 öldü — hepsi davranış kontrolüyle, 0 SCRIPT ERROR; kaynak her seferinde
  bayt-aynı geri kondu, HEAD blob'u):** A tamamlanan görev ikinci ödül · B yinelenen kesinleştirme · C saat geri alınınca eski dönem ·
  D pazar haftası · E sonsuz round level sayar · F terk ilerletir · G ödül XP verir · H / H2 açılış /
  kapanış yatışması yok · I tamamlanma reklam çağırır · (inceleme sonrası, Main yolları) J öne
  dönüş tazelemez · K ekran değişimi kapatmaz · L günlük / sandık / ayarlar üstüne açılır · M yaş /
  kısıt ekranı üstüne açılır · N round başlangıcı kapatmaz · O pencereleri kapatma atlar.
- **Görsel kanıt (pencereli, `tools/missions_shots.tscn`):** `137c219` ağacında 6 boyut × 14 kare =
  **84 PNG** (320×568, 360×640, 390×844, 360×800, 1080×2340, 1080×2340 + A36 üst payı 61): Ana Sayfa 0/6 · 3/6 · 6/6, pencere 0 /
  kısmi / bir görev / günlükler / altısı / uzun metin / kaydırma sonu, 4 gerçek round sonucu (tek
  günlük, tek haftalık, günlük + haftalık, görev + seviye atlama + başarım); her karenin piksel
  boyutu doğrulandı, 0 betik / harness hatası, sahibin kayıt ailesi dokunulmadı. Gözle: açık
  kartlarda lavanta, tamamlananlarda nane halka görünür; üç hap 320×568'de de sığar.
- **Çekişmeli inceleme (6 mercek, salt okuma):** BLOCKER 0 · HIGH 1 · MEDIUM 5 · LOW 15 · NIT 15.
  HIGH: doküman, son koşulardan önce "masaüstü doğrulama tamam" diyordu → iddia yalnız bu son
  koşulardan sonra yazıldı. MEDIUM: `revive_refill_ui_test` kesin +5 sahibin kaydına bağlıydı →
  görevler sabitlendi; `result_ui_test` görev round'u sahibin kaydına yazıyordu → TEST yolu +
  gerçek kayıt bayt kontrolü (suite'in TASK/046 öncesi gerçek kayıt yazmaları miras — koşucu
  aileyi geri koyar); Main tarafı görev yolları testsizdi → kapı / kendiliğinden kapanış / öne
  dönüş testleri + J–O mutasyonları; doküman eksikti → tamamlandı; önceden var olan RESULT_DELAY
  penceresi (aşağıda). Düzeltilen LOW / NIT: kart halkası opak gövdenin altında görünmüyordu
  (kök `Control` + kardeş halka, kart dikdörtgeninde — kaydırma alanı kırpmaz), Ana Sayfa N/6 gün
  dönümünde pencereden farklı kalabiliyordu (açılışta tazelenir), sandık / günlük kod yolu
  korumaları, ipucu kontrastı, bozuk saat yorumları + round testi, ekonomi varsayımı (koleksiyon
  tamam tablosu), "iki Nadir parça", gelecekteki sürüm göçü notu, UTF-8 çıktı, test
  totolojileri, yazma girişimi dedektörü, tam renk rozet, TAMAMLANDI metni, kırpma kapsamı, üç
  hap sığması, sonuç banner'ı, bekçi süreleri / Main önce serbest. **Bilerek bırakılan (owner
  kararı):** görev tabanı ile DailyRewards tabanı gece yarısı + saat geri alma kombinasyonunda
  ayrışabilir (ödül tekrarı yok; düzeltmesi DailyRewards'ı değiştirir) · elle bozulmuş kayıt ödül
  işaretlerini silebilir (yalnız kayıt düzenlemeyle) · round'un `add_merges` yazması ayrı (TASK/045
  mirası; görevler XP ile tutarlı) · Hamur çipi görev tutarını ayrıca saymaz (son değer doğru) ·
  `dough()` ham `int` (önceden var olan, yalnız bozuk kayıt) · sessiz kapanış da yatışma başlatır
  (erişilemez) · "birleşme / BİRLEŞTİRME / merge" üç kelime (katalog metni kilitli) ·
  `progression_shots` / `result_shots` referans kareleri kayıttaki görev durumuna göre rozet
  gösterebilir.
- **Önceden var olan, kapsam dışı (düzeltilmedi):** (1) *(→ TASK/048 ile kapatıldı — main'de `b9ae345`, §4.28)*
  **RESULT_DELAY penceresi bitiren board'a
  bağlı değil** (inceleme MEDIUM, TASK/046'dan eski): Mola açıkken Büyütücü dönüşümü round'u
  bitirebilir; 0,8 sn içinde "Yeniden Başlat" → eski round'un geçiş reklamı / sonucu (görev hapı
  dahil) yeni round'un üstüne açılabilir. Görev sayımı DOĞRU (eski round bir kez, yeni 0) — zarar
  arayüz / reklam zamanlaması. Öneri (owner onayı): beklemeden önce bitiren board'u yakala, `_board`
  değiştiyse reklam + sonuç atla; kesinleşmede Mola / Refill'i kapat. (2) §4.23'ün önceden var olan
  iki girdi sorunu (ACTION_CANCEL parça düşürür; basılı Koleksiyon kartı + GERİ) aynen — dokunulmadı.
- **Donmuş sözleşmeler aynen:** TASK/043 yaş yönlendirmesi / rıza (görev kodunda reklam–yaş
  jetonu yok, `release_config_test` taramaları aynen) · TASK/045 XP eğrisi / başarımlar / unvanlar
  / şerit (görev hapı gizliyken düzen aynı) · TASK/045.1 SaveFile işlemi, kurtarma önceliği, yaş
  fail-closed · TASK/045.2 `_input` ve 300 ms · günlük ödüller, onboarding, fiyatlar, sandık
  oranları, monetizasyon yöneticisi.
- **Samsung A36 yerel kapısı (GEÇTİ 2026-09-30 — yalnız QA paketi, TASK/046 bulgusu yok; kanıt
  yerel `build/qa_046-gate/`; kapsam):** gerçek round'larla günlük / haftalık ilerleme ve otomatik Hamur (tek + çok görev hapı), GÖREVLER girişi
  güvenli alanda / çakışmasız, pencere geri / X / karartma, girişe ve X'e hızlı çift dokunuş, 300 ms
  sonrası ilk dokunuş, banner yuvası, kayıt kurtarma, TASK/043–045.2 korumaları aynen. Gün / hafta
  dönümü ve saat geri alma masaüstünde saat kancasıyla doğrulandı; cihazda tarih değiştirmek
  telefon ayarıdır → yalnız owner isterse. *(Kapıda gün / hafta dönümü QA saat kancasıyla
  doğrulandı — telefon saati değişmedi; önceden var olan RESULT_DELAY yarışı cihazda 1/1 yeniden
  üretildi, görev sayımı doğru — düzeltilmedi, owner kararı.)*

### 4.25 Yaş ekranı 13+ UX yeniden tasarımı (TASK/046.1)

> **main'de** — `task/046-1-age-gate-13plus-redesign`, TASK/046'nın `5092dad`'i üstüne yığılı
> (`bc40da1` · `ed08b07` · `1ff0ba1` · `98d209e` · `b90bc3c`). **Masaüstü doğrulama tamam
> (2026-09-30); Samsung A36 yerel kapısı GEÇTİ (2026-09-30)** — bir cihaz bulgusu düzeltildi
> (`98d209e`, aşağıda); TASK/046 ile birlikte owner onayıyla ff-only main'e alındı `56106ef →
> b90bc3c` (merge commit yok). TASK/047 BAŞLAMADI. Güncel sözleşme
> [AGE_BAND_ROUTING §0.1 / §3.1](docs/monetization/AGE_BAND_ROUTING.md), görünüm UI_VISUAL_SYSTEM
> §25. TASK/043 tarihçesi (§4.x, AGE_BAND_ROUTING §2–§11) yeniden yazılmadı.

- **Owner kararı (2026-09-30):** yaş ekranı yalnız kendi beyanı **13+** doğum tarihi seçtirir; normal
  girişten "yaşın uygun değil" / kısıt ekranı / zorla çıkış YOK. **Uyum riski AÇIK:** yalnız 13+
  seçilebilen tarih Play'in nötr yaş ekranı rehberiyle (serbest tarih girişi örneği; gereken yaşı
  hissettirmemek) çelişebilir — görev başında owner'a söylendi, owner "Build as specified" seçti;
  hukuk incelemesi owner'da (AGE_BAND_ROUTING §9.10). Uyduğu iddia EDİLMEZ.
- **Model (`AgeGate`, tek kaynak):** `MIN_SELECTABLE_AGE = TEEN_AGE`; `youngest_allowed_birth_date`
  (bugünden 13 yıl önce; yıl dönümü kuralıyla doğrulanır — 29 Şubat "bugün"de 28 Şubat),
  `oldest_allowed_birth_date` (120 yıl), `is_selectable_birth_date`, `selectable_year / month /
  day_range`, `clamp_selection` (takvim kırpılır; aralıkla çelişen alan SIFIRLANIR — en genç izinli
  güne kaydırılmaz), `classify_selected_birth_date` (aralık dışı → hata, bant UNKNOWN; **UNDER_13
  üretmez**). DOB tabanlı sınıflandırma ve 18. yaş günü geçişi AYNEN. `routing_contract_problems`
  13+ sözleşmesini de denetler (release kapısı: fark → CODE).
- **UI (`age_gate_panel`):** tuş takımı emekli; "YAŞINI DOĞRULA", küçük nötr Squishy, "Devam etmek
  için doğum tarihini seç.", GÜN / AY / YIL seçicileri → pencere içi seçim ızgarası (yıl en genç
  ilk), DEVAM ET, onay ("30 Eylül 2008 — Doğru mu?" DÜZELT / ONAYLA, tek gönderim), tek nötr hata
  "Tarihi kontrol edip tekrar dene.", gizlilik notu "Doğum tarihin cihazından çıkmaz.", opak kabuk
  zemini (arkadaki kontroller görünmez). Zorunlu: X yok, karartma kapatmaz, Android geri ÇIKMAZ.
  Yeniden giriş: X / Vazgeç / karartma / geri; seçiciler boş açılır.
- **Emekli:** `age_restricted_screen.gd` / `.tscn` / `.uid` silindi; Main'den kısıt yolu, zorunlu
  sorudaki "geri = çık" kaldırıldı (tek çıkış: Ana Sayfa'da geri, `_quit_app`). Test: üretim
  `scripts/` + `scenes/` içinde "Üzgünüz" / "yaş grubun için" / "ÇIKIŞ" / kısıt rotası YOK.
- **Eski UNDER_13 kaydı:** açılışta UNKNOWN (reklam / UMP / SDK yok, zorunlu panel); TEK yazmayla
  "UNKNOWN" + boş tarih, `.bak` atılır (doğum gününe eşdeğer 13. yaş günü kalmaz); TEEN / ADULT'a
  çevrilmez; ilerleme aynen.
- **Main:** panel `opened` / `settle_requested` → TASK/045.2 300 ms dizi yatışması (global girdi
  anlamı aynen); panel açıkken reklam yüzeyi NONE (banner yok), kapanınca bırakılan yüzey (oyun içi
  Ayarlar'dan açıldıysa GAMEPLAY) geri gelir, arada gelen yüzey değişimi yalnız hatırlanır.
- **Gizlilik:** seçim yalnız panel belleğinde; onay / vazgeç / kapanışta ve ızgara kapanınca silinir;
  log / analitik / ağ yok (statik tarama); kayıt yalnız `age_ad_band` + `next_age_transition_date`
  (TEEN: 18. yaş günü; ADULT / UNKNOWN boş). QA harness'ı (`tools/ads_device.gd`) seçilen değeri
  yazmaz, yalnız görünür ızgara seçeneklerinin konumunu.
- **Testler:** `age_gate_test` 137 → 207 (13+ aralık: 1600 günlük kaba kuvvet, 29 Şubat, uyarlama
  değişmezi; panel: ızgaralar 13 altını hiç göstermez, en genç tarih, uyarlama, onay / DÜZELT / tek
  ONAYLA, bozuk / geri saat → nötr hata, kipler, nötr metin / sanat, 5 boyut + A36 61 her adımda,
  emekli akış); `age_ad_routing_test` 112 → 122 (eski UNDER_13 yeniden sorma, geri çıkmaz, seçimden
  önce UMP / init / banner / ödüllü / geçiş 0, yeniden girişte banner gizli + geri gelir);
  **yeni `age_gate_ui_test`** 26 (gerçek parmak olayları: arkaya sızma yok, seçiciye / DEVAM ET'e /
  ONAYLA'ya çift dokunuş, yeniden girişte X / Vazgeç / karartma / geri + kapanış sonrası ilk
  dokunuş); `release_config_test` 202 (13+ sözleşmesi kapıda); `profile_test`, `tutorial_test`,
  `missions_ui_test` yeni seçicilere uyarlandı. Tam regresyon 36 koşu 4808 kontrol, 0 hata,
  0 SCRIPT ERROR. Mutasyon 14: 13 öldü (ilk turda sağ kalan tek gönderim mutasyonu testi
  güçlendirilince öldü), 1 eşdeğer (en genç tarih döngüsü 13 yıllık aralıkta hiç dönmez — koruyucu).
  Görsel kanıt `tools/age_gate_shots.tscn`: 6 boyut × 11 kare (boş, kısmi, ızgaralar, en genç 13,
  genç, yetişkin, onay, nötr hata, Ayarlar yeniden giriş + kaydedildi).
- **İnceleme (6 mercek, 2 okuyucu):** BLOCKER 0 · HIGH 0. Giderilen: M1 uyarlama en genç izinli
  güne kaydırıyordu (eşiği ima ediyor, seçilmemiş tarih üretiyordu) → çelişen alan sıfırlanır; M2
  eski UNDER_13'ün 13. yaş günü kayıtta süresiz kalıyordu → açılışta temizlenir; LOW: `.bak`'tan
  kurtarılmış oturumda eski kuşak, kapalı ızgarada kalan seçenekler (harness), panel açıkken gelen
  NONE yüzeyi, ızgara açılırken yeniden uyarlama; NIT: seçici satırı içerik genişliğini 6 px
  aşıyordu, reddedilen gönderimde DÜZELT kilidi. Bilinçli bırakılan: yeniden girişte ızgara açıkken
  karartma pencereyi kapatır (geri yalnız ızgarayı) — brif "karartma kapatır".
- **Samsung A36 yerel kapısı — GEÇTİ (2026-09-30):** yalnız QA paketi `com.obappstudio.squishymerge.qa`
  (debug, Google TEST reklamları; üretim paketi hiç kurulmadı, `com.example.squishymerge` meta verisi
  önce / sonra birebir). Yerel sürücüler `build/qa_0461-gate/device/` (gitignore'lu): gerçek dokunuşla
  seçici / ızgara (`picker.sh` / `dob.sh`), `age4.sh`, `verify_apk.py`; TASK/046 kapısının tuş takımı /
  kısıt ekranı betikleri koruma altına alındı (emekli).
  - **Bulgu (düzeltildi):** dışa aktarılmış Android derlemesinde yaş panelinin opak zemini (karartmanın
    çocuğu `shell_backdrop` örneği) çapa 0 / boyut 0 geliyordu → arkadaki Ana Sayfa kontrolleri karartma
    altından görünüyordu (dokunulamıyordu); editör ikilisinde görülmüyor. Düzeltme `98d209e`: sahne örneği
    tam ekran çapaları kendisi bildirir + `_ready` `PRESET_FULL_RECT` kurar; `age_gate_test` çapaları
    sıfırlanmış zemini taklit eder (düzeltme olmadan kırmızı). Tam masaüstü regresyonu 36 koşu 4810
    kontrol 0 hata; cihazda zemin 720×1560 tam kaplıyor.
  - **Cihazda doğrulanan:** zorunlu kip güvenli alanın altında, tuş takımı yok, arkadaki OYNA / avatar
    dokunuşları geçmiyor, Android geri ×2 çıkmıyor; YIL seçicisine çift dokunuş ızgarayı bir kez açar,
    seçim yok; gerçek kaydırma seçim yapmaz; ızgara 2013 → 1906, 2013'te Ocak–Eylül, Eylül 2013'te 1–30
    (13 altı tarih YOK); en genç 30 Eylül 2013 onayda, DÜZELT seçimi korur, ONAYLA'ya çift dokunuş TEK
    TEEN; TEEN + T ve UNSPECIFIED + MA `initialize()`'dan ÖNCE (native geri okuma + logcat sırası);
    UNKNOWN'da eklenti / UMP / SDK çağrısı yok; eski UNDER_13 denetimli kaydı → UNKNOWN + zorunlu panel,
    kısıt ekranı yok, eski tarih kayıttan ve `.bak`'tan silindi, ilerleme birebir, yeni seçimle TEEN + T;
    Ayarlar → Yaş bilgisi boş açılır, X / Vazgeç / karartma / geri kapatır, 120 ms sonraki dokunuş
    yutulur, sonraki ilk normal dokunuş bir kez çalışır; oyun içinden açıldığında banner panel açıkken
    gizli, kapanınca geri; aynı bant → reklam sürer, ADULT → TEEN → oturum reklamsız + sonraki açılış
    TEEN + T; 18. yaş günü geçişi (QA yaş saati) ADULT / MA SDK'dan önce; dört bant soğuk açılış doğru,
    Play Age Signals 0. TASK/046 ve öncesi: GÖREVLER geri / X / karartma / çift dokunuş, görev ödülü
    (+10 bir kez), Ayarlar geri → ilk tahta dokunuşu 3/3, Bomba / Büyütücü hedef bırakışı, günlük
    pencere ↔ Koleksiyon detayı kapısı, Profil / Başarımlar, banner yüzeyleri (Profil'de yok). Logcat
    (tutulan tüm QA süreçleri): SCRIPT ERROR 0, çökme / ANR 0, sentetik doğum tarihi biçimleri 0.
  - Kapı sırasında telefon iki kez duraklatıldı (kendiliğinden kilit, gelen çağrı): girdi durdu,
    yalnız salt okunur bekleme; çağrı süresince QA uygulamasına 0 dokunuş.

### 4.26 ACTION_CANCEL bırakma koruması (TASK/046.2)

> **main'de** — `task/046-2-action-cancel-drop-guard`, main `afc10be`'den (`471a2ab` düzeltme ·
> `2149fc3` test · `b364a0c` test sıkılaştırma · `6d3dbca` doküman / kapı kaydı). **Masaüstü doğrulama
> tamam; Samsung A36 yerel kapısı GEÇTİ (2026-10-01)**; owner onayıyla ff-only main'e alındı `afc10be →
> 6d3dbca` (merge commit yok, dal duruyor). TASK/047'nin önkoşulu olan küçük bir stabilizasyon işi
> (TASK/047 o sırada BAŞLAMAMIŞTI — §4.27).

- **Önceki davranış:** Android ACTION_CANCEL (ör. bir sistem hareketi dokunuşu devralınca) Godot
  4.6.3'e `pressed == false` + `canceled == true` olan bir `InputEventScreenTouch` olarak gelir
  (motor: `AndroidInputHandler::_cancel_all_touch` → `_parse_all_touch(false, true)`; normal
  ACTION_UP → `canceled == false`). `GameBoard._unhandled_input`'un normal dokunuş yolu HER
  `pressed == false` bırakışında `_drop()` çağırıyordu → iptal edilen dokunuş bekleyen parçayı geçerli
  bir parmak bırakışı gibi düşürüyordu (TASK/045.2 A36 kapısında gerçek ACTION_CANCEL ile 2/2, §4.23).
- **Düzeltme (dar):** yalnız `GameBoard._unhandled_input`'un bırakış dalı — `else: _drop()` →
  `elif not touch.canceled: _drop()`. İptal edilen dizi parça düşürmeden biter: bekleyen / sıradaki
  tier, torba, drop sesi, bekleme süresi, merge / skor / kayıt etkisi YOK; nişan parmağın son konumunda
  kalabilir (geri alma yok); sonraki bağımsız geçerli dokunuş hemen düşürür. Yeni durum, zamanlayıcı ya
  da ek yatışma YOK. `_drop()` (araç / bot çağıranları), `DROP_COOLDOWN` 0,4, `Main._input`'un 300 ms
  yatışması (TASK/045.2 dizi modeli — iptal bırakışı yutulan diziyi zaten kapatıyordu) ve hedefli güç
  dokunuş tüketimi (TASK/045.1 `_targeting_touches`) DEĞİŞMEDİ; fizik, ekonomi, görevler, yaş, reklam,
  tutorial, GUI dokunulmadı.
- **Regresyon kapsamı:** yeni `tools/gameplay_input_cancel_test` (53 kontrol; kayıt
  `user://qa_input_cancel/` altına yönlendirilir, sahibin kayıt ailesi bayt bayt karşılaştırılır) —
  doğrudan GameBoard yolu (bas + bırak / bas + sürükle + bırak → 1 drop, önizleme ilerler; bas + iptal,
  bas + sürükle + iptal, basışsız iptal → 0 ve tier / torba / ses / bekleme / skor / kayıt aynı; iptalden
  sonra bekleme 0 ve sonraki dokunuş hemen kendi x'inde; bekleme süresinde iptal önceki gibi etkisiz),
  gerçek `Input.parse_input_event` → Main → GameBoard dağıtımı, Main yatışması, Bomba / Büyütücü hedef
  basışı + iptal bırakışı, iki parmak (parmak 0 iptal + parmak 1 geçerli; ikisi birden iptal), tutorial
  FIRST_DROP yardımlı girdisi, masaüstü fare + doğrudan `_drop()`, kaynak sözleşmesi. Değiştirilmemiş
  temelde (afc10be GameBoard) ilk sürüm 51'de 14, sıkılaştırılmış sürüm 53'te 18 kontrol düştü (hepsi
  iptal kontrolleri); düzeltmeyle 53/53. Mutasyon: koruma kaldırıldı 14 / 18, tersine çevrildi 23, yanlış
  özellik (`not is_pressed()`) 14 hata — hepsi yakalandı, kaynak bayt-aynı geri kondu. Bağımsız salt
  okunur inceleme BLOCKER / HIGH / MEDIUM 0; LOW test bulguları (birikimli sayaçlı takip kontrolleri,
  eksik pozitif sürükle-bırak) `b364a0c` ile giderildi. Tam masaüstü kapısı (kanonik, aday ağaç
  `b364a0c`, Godot 4.6.3): 37 koşu, 4863 kontrol, 0 hata, 0 SCRIPT ERROR (taban 36 koşu 4810 + yeni
  53); sahibin kayıt ailesi bayt-aynı, userdata listesi değişmedi.
- **Samsung A36 yerel kapısı (GEÇTİ 2026-10-01; yalnız QA paketi `com.obappstudio.squishymerge.qa`,
  Google TEST reklamları; APK `2149fc3`'ten — sonraki commit'ler yalnız test / doküman):** telefon 3
  tuşlu gezinmede (`navigation_mode` 0) → kenardan geri hareketi bu yapılandırmada yok, ayar
  DEĞİŞTİRİLMEDİ; gerçek Android ACTION_CANCEL (`input motionevent DOWN … CANCEL`, aynı işaretçi): 0
  drop (zaman çizelgesi `T0 CANCEL -> UNH`), bekleyen / sıradaki aynı, sonraki gerçek dokunuş tam bir
  drop — seviye 2/2, sonsuz 1/1, tutorial FIRST_DROP 1/1 (adım aynen, sonraki dokunuş DROP#1 →
  match_drop); sentetik Godot `canceled = true` dokunuşu Main / GameBoard yolundan 2/2; sürükle + iptal
  gerçek 1/1 + sentetik 1/1 (nişan sürüklenen yerde, 0 drop); Bomba / Büyütücü hedef basışı + gerçek
  iptal: stok bir kez, 0 drop, sonraki dokunuş düşürür (2/2); normal bas → sürükle → bırak 4/4 (tam bir
  drop, bırakış x'inde); Ayarlar dişlisi → GERİ → ilk tahta dokunuşu 3/3 tam bir drop (TASK/045.2
  aynen); duman: sonsuz, Mola → Yeniden Başlat, görev ilerlemesi (Level 1 kazanma → günlük 1/1/1 +
  ödül), Ayarlar → Yaş bilgisi yeniden giriş, sonrasında dokunuş normal. Logcat (tüm QA süreçleri):
  SCRIPT ERROR 0, çökme / ANR 0. Kapı sonunda QA paketi kaldırıldı; üretim paketi kurulmadı;
  `com.example.squishymerge` dokunulmadı. (İlk normal dokunuş denemesi geçersiz sayıldı: harness'in
  `level` komutu Ana Sayfa'yı atladığı için otomatik GÜNLÜK ÖDÜLLER penceresi tahtanın üstünde kaldı —
  kurulum hatası, ürün bulgusu değil; pencere gerçek KAPAT ile kapatılıp tekrarlandı.)
- **Ayrı kalan, düzeltilmedi (owner kararı):** RESULT_DELAY yarışı (§4.24 — *TASK/048 ile kapatıldı — main'de `b9ae345`,
  §4.28*); basılı Koleksiyon kartı + GERİ sentetik bırakışı (§4.23 — *TASK/054 ile kapatıldı — main'de `88c8570`,
  §4.34*); genel modal / karartma iptal davranışı (`UiKit.attach_dim_close`, `ShopScreen._on_dim_input` iptal
  bırakışında da kapatır) ve **kapıdaki yeni gözlem:** güç düğmesi üzerinde gerçek ACTION_CANCEL gücü çalıştırır (A36:
  Sarsıntı stoğu 1 → 0; GUI düğmesi iptal edilmiş öykünen bırakışı bırakış sayıyor; parça düşmez) — aynı sınıf, GUI
  tarafı, ayrı görev adayı *(→ TASK/055 ile kapatıldı — main'de `e0c1a71`, §4.35)*.

### 4.27 Günlük Merge Challenge V1 — MEYDAN OKUMA (TASK/047)

> **TAMAM, main'de** — owner onayıyla ff-only main'e alındı (`6d3dbca → aa6f867`, 2026-10-02; merge
> commit / rebase / squash / cherry-pick / force push yok). Dal `task/047-daily-merge-challenge` duruyor
> (son incelenen HEAD `aa6f867`; main `6d3dbca`'dan: `befbbbd` model + kayıt · `bf553e0` board ·
> `201764d` akış + yalıtım · `e805736` arayüz + sonuçlar · `54e8411` + `e002dff` çekişmeli inceleme
> düzeltmeleri · `743e5d7` regresyon / görsel kapı + doküman · `7395280` A36 kapısı kaydı · `f8c8ffb`
> monoton gün · `aa6f867` monoton gün doküman / hedefli A36 kaydı). **Masaüstü doğrulama + 5 mercekli
> çekişmeli inceleme + mutasyon + 6 boyut görsel kapı + tam masaüstü kapısı tamam; Samsung A36 yerel
> kapısı GEÇTİ (2026-10-02)** — yalnız QA paketi, cihaz bulgusu yok, düzeltme commit'i yok. **Son engel
> "monoton kabul edilen gün" KAPATILDI (`f8c8ffb`, main'de); tam masaüstü kapısı (42 koşu, 5261 kontrol,
> 0 hata, 0 SCRIPT ERROR, bot 2/2) + hedefli Samsung A36 kapısı (13/13) GEÇTİ (2026-10-02)** — aşağıda;
> hepsi entegrasyondan ÖNCE. Kurallar ve sayılar GAME_DESIGN §5.11'de kilitli (owner onaylı brif),
> görünüm UI_VISUAL_SYSTEM §26.

- **Ürün:** isteğe bağlı günlük mod — hedef tier'ı sınırlı GERÇEK bırakışla, günün deterministik parça
  dizisiyle oluştur; süre yok. Kilitli haftalık preset (Pzt T5·600·18 · Sal T5·480·16 · Çar T6·600·38 ·
  Per T5·420·15 · Cum T6·540·36 · Cmt T6·480·32 · Paz T6·420·30; yükseklik 400), dizi SHA-256 `sm-dc-v1`
  torbası (global RNG'ye dokunmaz; 2026-10-01 vektörü kilitli), bütçe yalnız gerçek bırakış (iptal 0),
  son bırakıştan sonra yatışma (son parça indikten 1,5 sn merge'siz / bırakıştan 5,0 sn tavan), güç ve
  devam tamamen kapalı, P1 ilerleme yalıtımı (ayrı round-sonu işleyicisi), ilk başarı +20 Hamur günde
  bir kez tek kayıt yazmasında (`daily_challenge {version, completed_day_key}`), tekrar oynanmaz.
- **Mimari:** `DailyChallenge` (saf model: preset, dizi, görünüm, `sanitize`, `can_complete`) →
  `SaveManager.complete_daily_challenge` (tek yazan, idempotent) · GameBoard'a varsayılan KAPALI dikiş
  (`setup_challenge`: bütçe, yatışma, güç kilidi, devam 0, HUD sunumu) · Main'de açık `RoundKind`, ayrı
  `_on_challenge_round_finished`, deneme kimliği + board kimliği jetonu (gecikmeli sonuç yalnız kendi
  denemesine) · `DailyChallengeOverlay` + Ana Sayfa pill'i + HUD + `RoundResult` meydan okuma kipleri.
- **Brifin açık bıraktığı yerlerde verilen kararlar:** (1) efektif gün = `Missions.accepted_day()`,
  kayıttaki tamamlanma günü taban (geri alınan saat tamamlanmış günü açmaz); (2) açık pencerenin BAŞLA'sı
  gün değiştiyse / bugün tamamlandıysa pencereyi tazeler, ikinci basış başlatır (+300 ms yatışma yeniden
  kurulur); (3) gece yarısını geçen kazanmanın dipnotu "Gün değişti · yeni meydan okuma hazır."; kayıp
  sonucu günü gösterimde okur, açık kayıp sonucu gece yarısını geçerse TEKRAR DENE / öne dönüş önce onu
  "Gün değişti"ye yeniler; (4) sonuç çip sırası HAMUR → HAMLE; (5) yatışma penceresi son parçanın ilk
  temasından (`has_landed`) sayılır — sabitler aynen (inceleme MEDIUM'u, aşağıda); (6) meydan okuma
  sonucunun açılışı mevcut 300 ms yatışmayı kurar (normal sonuç aynen).
- **Testler (yeni):** `daily_challenge_test` 72 (model + kayıt + saat), `daily_challenge_board_test` 57
  (dikiş, bütçe, iptal, yatışma yarışları, taşma, güç / devam), `daily_challenge_flow_test` 76 (Main
  yönlendirme, P1 yalıtım bellek + disk, gece yarısı, jeton, geç sinyal, global RNG yeniden tohumlama
  kanıtı, reklam, tutorial), `daily_challenge_ui_test` 149 (gerçek parmak: giriş, pencere, gece yarısı,
  HUD, sonuçlar, 5 görünüm + A36 üst payı yerleşimi); `save_persistence_test` şema sabiti 30 anahtar
  (`daily_challenge` eklendi). Hepsi kaydı test yoluna yönlendirir; sahibin kayıt ailesi her koşuda
  bayt-aynı.
- **Çekişmeli inceleme (5 mercek: oyun + RNG · kalıcılık + yalıtım + gece yarısı · girdi + akış + jeton
  + tutorial · reklam / yaş + arayüz + doküman · test yeterliliği; salt okunur, sabit anlık görüntü):**
  BLOCKER 0, HIGH 0. MEDIUM: yatışma penceresi son parça daha düşerken başlıyordu (geç sekme / yuvarlanma
  merge'ü kesilebilirdi) → düzeltildi; A36 üst payı oyun / sonuç karelerine uygulanmıyordu (çekim aracı)
  → düzeltildi; doküman eksik / erken iddia → tamamlandı; üç test boşluğu (değiştirilen board'un geç
  sinyali, Main yollarında global RNG, eşik karesinde merge yarışı) → testler eklendi. LOW: gece yarısı
  sonuç kopyası ve tazelenen pencere / sonuç yatışması → düzeltildi; zayıf / eksik kontroller (ödüllü
  yükleme, iptal öncesi bekleme süresi, tutorial görünürlüğü, çift sinyal, user:// kökü, bellek farkı,
  Ana Sayfa D+1, 16. bırakış, gerçek parmakla TEKRAR DENE) → eklendi. Düzeltme diff'i ayrıca bir kez daha
  salt okunur incelendi (BLOCKER / HIGH / MEDIUM 0; LOW 1 — gece yarısında yenilenen kayıp sonucu 300 ms
  yatışmayı yeniden kurmuyordu → `e002dff`; NIT'ler: "indi" = ilk temas (sıyırma dahil) belgelendi, açık
  kalan BAŞARI sonucunun dipnotu gece yarısında tazelenmez — tek eylem ANA SAYFA, zararsız). Kayda geçen,
  düzeltilmeyen: aşağıda.
- **Mutasyon kanıtı (son aday `e002dff`):** 35 mutant (brifin zorunlu 10'u + 25 ek: ödül, yinelenen tamamlanma, önek / gün,
  global `seed()` model / Main / Ana Sayfa, `randomize()` sonuçta, ilerlemeye merge, geçiş reklamı,
  yatışma hemen kayıp / bırakıştan sayım / hiç inmeme / ertelemesiz / yeniden kontrolsüz / bayrak
  sıfırlanmaz, iptal hamle yer, normal `_start_level` ile tekrar, jeton kapalı, işleyici ayrılmıyor /
  yanlış bağlı, kesinleştirme kapısı yok, güç / devam açık, bütçe ±1, gece yarısı güncel güne yazar /
  gecikmeden önce okunur / açık sonuç yenilenmez, onboarding'de pill, eski pencere başlatır / yatışma
  kurmaz, sonuç yatışması / yenilenen sonuç yatışması yok, geri alınan saat tamamlanmışı açar) — 35/35
  öldü; her mutasyondan sonra kaynak sha256 ile bayt-aynı geri kondu, sahibin kaydı her koşuda bayt-aynı.
- **Görsel kapı (`e002dff`):** `tools/daily_challenge_shots` 6 boyut (320×568, 360×640, 390×844, 360×800,
  1080×2340, 1080×2340 + A36 üst payı 61 — kabuk, pencere VE board) × 15 kare = 90 kare, 0 betik / araç
  hatası; incelendi: çakışma / kırpma / üst pay ihlali / banner ya da maskot çakışması yok, GÖREVLER 0/6
  aynen, pill GÖREVLER ailesinde ama ayırt edilir.
- **Tam masaüstü kapısı (aday ağaç `e002dff`, sonraki commit yalnız doküman + çekim aracı; Godot 4.6.3,
  sıralı):** 41 koşu (40 suite + bot L3 2/2 KAZANDI), 5262 kontrol, 0 hata, 0 SCRIPT ERROR; içe aktarma
  rc 0, hata satırı 0; sahibin kayıt ailesi görev başındaki yedekle bayt-aynı, userdata listesi
  değişmedi, Godot süreci kalmadı. (TASK/046.2 tabanı 37 koşu 4863; fark = 4 yeni suite 356 kontrol +
  `revive_test`'in fizik yoluna göre değişen `[OK]` satır sayısı — kendi özeti iki koşuda da 120 geçti /
  0 kaldı.) Sahibin dosyalarında içerik değişmedi; yalnız zaman damgaları: içe aktarma
  `default_bus_layout.tres`'i aynı baytlarla yeniden yazar, eski bir suite sahibin kaydına aynı baytları
  yeniden yazar (koşucu bayt karşılaştırır — önceki kapılarla aynı davranış).
- **Samsung A36 yerel kapısı — GEÇTİ (2026-10-02, cihaz saati 08:30–09:10; telefon önceki akşam bağlı
  değildi):** yalnız QA paketi `com.obappstudio.squishymerge.qa` (Google TEST reklamları; APK `743e5d7`'den
  — kod `e002dff`, 104,253,700 B; `verify_apk.py` PASS: QA kimliği, debuggable, yalnız Google örnek
  kimlikleri, TASK/047 kodu + iki inceleme düzeltmesi paketlenmiş jeton tablolarında). Kabul edilen gün
  yalnız QA kancasıyla sabitlendi (`dcclock=` açılış sözcüğü / `t47_clock`) — telefon saati DEĞİŞMEDİ;
  gezinme kipi 0 (3 tuş) DEĞİŞMEDİ; her girdi öncesi güvenlik kontrolü (uyanık, kilitsiz, arama / VoIP yok,
  bildirim perdesi / heads-up yok, QA ya da başlatıcı önde) ve parti başına dokunuş sayımı (yabancı dokunuş
  0). Sonuçlar: **giriş / pencere** — tutorial'da giriş yok + başlatma reddi, gerçek ATLA → ilk normal Ana
  Sayfa'da "+20" pill GÖREVLER 0/6'nın hemen altında, otomatik açılmaz; gerçek dokunuşla pencere (T5 / T6
  kopyası + portre), Android GERİ / X / karartma kapatır, çift dokunuş ve açılıştan ~150 ms sonraki
  karartma dokunuşu yutulur, Ana Sayfa'ya sızma yok; **dizi** — 2026-10-01'de 15 gerçek bırakış =
  kilitli vektörün öneki, tekrar aynı önek, Pazartesi 2026-10-05'te 18 gerçek bırakış = bağımsız Python
  SHA-256 hesabı; aynı günün iki başlangıcından sonra global `randi()` örnekleri FARKLI, normal Level 2
  iki kez farklı torba dizisi; **bütçe** — her gerçek bırakış tam −1, gerçek ACTION_CANCEL ve sürükle +
  CANCEL 0, son bırakış kabul, 16. / 19. dokunuş RED; **yatışma** — son bırakış → ilk temas +1175 / +1042 ms
  → bitiş inişten +1508 / +1515 ms (5 sn tavanın altında), MOVES_EXHAUSTED; **başarı** — gerçek bırakış +
  QA destekli dikili (hedef − 1) çifti → GERÇEK merge ile hedef: "MEYDAN OKUMA TAMAM!" / "+20 HAMUR" /
  HAMLE / "Yarın yenilenir" / yalnız ANA SAYFA, Hamur tam +20 (0 → 20, 20 → 40, 40 → 60, TEEN ve UNKNOWN'da
  da +20), bellek + disk farkı YALNIZ `daily_challenge` + `dough`; soğuk açılışta ✓ korunur, pencere ✓
  TAMAMLANDI, başlatma RED, ikinci ödül yok; **kayıp / tekrar** — hamle bitti ve taşma kopyaları, gerçek
  TEKRAR DENE aynı dizi tam bütçe, terk yazmaz; taşmada devam / refill penceresi / ödüllü istek YOK;
  **gece yarısı** — Cuma denemesi Cumartesiye geçince kazanıldı → Cuma ödüllendi, dipnot "Gün değişti …",
  Ana Sayfa Cumartesiyi ayrı gösterdi; açık Cumartesi penceresinde gün Pazara dönünce BAŞLA'ya çift dokunuş
  → pencere Pazara tazelendi, ikinci dokunuş yutuldu; Pazar kaybı Pazartesiye geçince "Gün değişti" + YENİ
  MEYDAN OKUMA → Pazartesi başladı; Pazartesi tamamlandıktan sonra gün Pazara geri alındı (gerçek öne
  dönüşle) → hiçbir şey yeniden açılmadı; **eski sonuç jetonu** — bitişten 0,2 sn sonra yeniden başlatma /
  çıkış: eski sonuç açılmadı; **reklam / yaş** — ADULT ve TEEN (TFAT TEEN + T aynen) meydan okuma
  bitişlerinde geçiş reklamı / ödüllü olayı 0 (normal round bitişi mevcut yolu çağırdı:
  `interstitial_skipped_not_ready`); UNKNOWN: SDK bağlanmadı, rıza başlamadı, banner yuvası 0, zorunlu yaş
  ekranı açıkken pill pencereyi açmadı, QA kancasıyla gizlenince meydan okuma oynandı (+20), olay 0;
  **preset'ler** — yedi gün cihazda tablo ile birebir; **normal regresyon** — sabit level kazanma / kayıp,
  Sonsuz, gerçek Sarsıntı (stok 1 → 0), gerçek devam teklifi "2 / 2", görevler (normal Level 2 kazanımı
  daily_clear, ikinci round daily_rounds; meydan okuma görevlere değmedi), GÜNLÜK penceresi, Ayarlar → Yaş
  bilgisi yeniden giriş + GERİ, Ayarlar dişlisi → GERİ → ilk dokunuş tam 1 bırakış, normal tahtada gerçek
  ACTION_CANCEL 0, Harita ↔ Ana Sayfa, mola → gerçek "Yeniden Başlat". Logcat (4 QA süreci): SCRIPT ERROR
  0, çökme / ANR 0, godot E 0, Play Age Signals 0. Bir güvenlik kontrolü S14'te anlık başarısız oldu: o an
  dokunuş gönderilmedi, ≥ 60 sn salt okunur yoklamadan sonra devam edildi (yabancı dokunuş 0). Kapı sonunda
  QA paketi kaldırıldı; üretim paketi hiç kurulmadı; `com.example.squishymerge` dokunulmadı (0.8.5, kurulum
  / güncelleme zamanları aynı); masaüstü kayıt ailesi ve sahibin dosyaları içerik olarak aynı.
- **Monoton gün — son engel, KAPATILDI (2026-10-02, owner brifi "FINAL BLOCKER: MONOTONIC ACCEPTED DAY"):**
  önce yeniden üretildi — yeni `tools/daily_challenge_day_test` düzeltmesiz `7395280`'de 35 kontrolün
  10'unda düştü (açık oturum: Ana Sayfa D+1'i gösterdi ama `last_seen` D kaldı, saat geri → meydan okuma /
  `day_key` / `accepted_day` D, preset ve Ana Sayfa D; BAŞLA başlatmadı, pencereyi D'ye tazeledi; kayıp
  "Gün değişti" dedi, TEKRAR DENE D'yi başlattı; soğuk açılış: diskteki `last_seen` D → yeni süreç D;
  kontrol: öne dönüşün kaydettiği D+1 soğuk açılışta korunuyordu). Düzeltme (`f8c8ffb`, en küçük güvenli
  değişiklik): meydan okumanın tek gün okuması `DailyChallenge.current_day()` kabul ettiği günü mevcut
  `DailyRewards.observe_day()` ile kayda işler (yalnız ileri, yalnız `last_seen_day_key`; geçersiz saat
  yazılmaz) — yeni alan / ikinci saat / şema değişikliği YOK. Eşdeğerlik kanıtı: meydan okumanın kabulü
  öne dönüş gözlemiyle BAYT-AYNI kayıt yazar ve ortak okumalar (gün, ilk gün kilidi, pencere "due", görev
  dönemi, giriş / seri / Hamur) saat ileri ve geri iki yolda aynı → yeni ödül / ilerleme kuralı yok; giriş
  ödülü sistem tarihiyle çalışır (dokunulmaz). Testler: `daily_challenge_day_test` 38 (açık oturum, BAŞLA,
  tekrar, Ana Sayfa, tamamlanma, soğuk açılış + kontrol, ileri / bozuk saat, ortak sistem, eşdeğerlik),
  model testi tek yazma yolunu sabitler; mutasyon: düzeltme kaldırıldı 16 hata, bozuk saat koruması
  kaldırıldı 2 hata — ikisi de öldü, kaynak bayt-aynı. Test fikstürü düzeltmesi: TASK/047 suite'leri
  `last_login_date`'i gerçek sistem tarihine kurar (açılıştaki giriş ödülü sistem tarihini kullanır;
  2026-10-01'e sabit fikstür sonraki her günde +15 veriyordu — saatli bomba, ürün hatası değil).
- **Monoton gün — tam masaüstü kapısı + hedefli Samsung A36 kapısı — GEÇTİ (2026-10-02):** masaüstü
  (`f8c8ffb`): 42 koşu, 5261 kontrol, 0 hata, 0 SCRIPT ERROR, bot 2/2; sahibin kayıt ailesi bayt-aynı,
  Godot süreci kalmadı. A36 (cihaz saati 10:37–10:53): yalnız QA paketi (APK `f8c8ffb`'den, 104,273,864 B;
  `verify_apk.py` PASS — paketlenmiş `daily_challenge` jeton tablosunda `observe_day` var, `743e5d7` APK'sı
  bu denetimde düşer); telefon saati DEĞİŞMEDİ, gün yalnız QA kancasıyla; gerçek dokunuşlar, parti başına
  dokunuş sayımı. (1) D = 2026-10-01 gözlendi, başlatıldı, kazanıldı (+20); (2) QA günü → D+1; (3) Ana
  Sayfa / pencere / BAŞLA D+1'i kabul etti (D+1 günlük penceresi mevcut kuralla açıldı, gerçek dokunuşla
  kapatıldı); (4) QA günü geri D; (5) Ana Sayfa D+1'de kaldı; (6) pencere D+1; (7) BAŞLA D+1, taşma
  kaybı "Kap taştı. Sıra aynı, tekrar dene!" ("Gün değişti" değil), gerçek TEKRAR DENE D+1; (8) D+1
  kazanıldı, tamamlanma günü kabul edilen gün (2026-10-02); tamamlanmış D bir daha hiç gösterilmedi;
  (9) başlatma RED, pencere D+1 ✓ TAMAMLANDI, Hamur toplamı tam +40 (D bir kez + D+1 bir kez); (10) zorla
  durdurma + soğuk açılış, QA günü D'de: kabul edilen gün D+1, ✓, başlatma RED, günlük pencere açılmadı;
  (11) yan etki yok — Günlük Ödüller kotaları / giriş tarihi / seri aynı (yeni giriş ödülü yok), görevler
  ileri döneme 0 ilerlemeyle damgalandı (mevcut kural), XP / başarım / istatistik / stok / onboarding /
  yaş bandı aynı; (12) logcat (2 QA süreci): SCRIPT ERROR 0, çökme / ANR 0, godot E 0, yalnız Google
  test reklam kimlikleri; (13) QA paketi kaldırıldı, üretim paketi hiç kurulmadı, `com.example.squishymerge`
  dokunulmadı (0.8.5, kurulum / güncelleme zamanları aynı), gezinme kipi 0. Not: QA kancasının durum
  satırları günü üretimdeki `DailyChallenge.current_day()` ile okur — saat ilerletildikten sonraki ilk
  okuma kabulün kendisidir; her arayüz yolunun kancasız yazdığını masaüstü gün suite'i kanıtlar. İki
  güvenlik durdurması (gelen arama, ardından sahibin 2 dokunuşu; Samsung kenar ışığı bildirimi): o an
  dokunuş gönderilmedi, ≥ 60 sn salt okunur yoklamadan sonra durum yeniden okunup devam edildi. Cihaz
  bulgusu yok, düzeltme commit'i yok.
- **Kayda geçen, DÜZELTİLMEYEN (owner kararı / kapsam dışı):** (a) ~~kalıtılan gün uç durumu~~ → 2026-10-02 kapatıldı
  (yukarıda "Monoton gün"); (b) *(→ TASK/048 ile kapatıldı — main'de `b9ae345`, §4.28)* **normal RESULT_DELAY yarışı**
  (§4.24) ve çapraz örneği: gecikmedeki normal sonuç → Mola / Ana Menüye Dön → Android GERİ (yatışmasız) → pill → BAŞLA
  ≈ 600 ms + tepki — eski normal sonucu / geçiş reklamı denemesi canlı meydan okuma tahtasının üstüne açılabilir
  (düğmeleri meydan okumaya gider, ekonomi çift sayımı yok); normal yol bu görevde DEĞİŞTİRİLMEDİ (brif §26 / §31); (c)
  basılı Koleksiyon kartı + GERİ *(→ TASK/054 ile kapatıldı — main'de `88c8570`, §4.34)* ve genel GUI ACTION_CANCEL
  (meydan okumanın yeni düğmeleri de iptalde öteki düğmeler gibi davranır; güç düğmeleri gizli + kilitli olduğundan
  Sarsıntı varyantı meydan okumada oluşamaz) *(→ TASK/055 ile kapatıldı — main'de `e0c1a71`, §4.35)* — o tarihte açık;
  (d) HUD hedef kartı T5 adını "Büyük Dumpl…" diye kırpar (önceden var olan kart, normal Level 3'te de; brif "hedef
  kartını koru") *(→ TASK/056 ile kapatıldı — main'de `ee2778a`, §4.36)*; (e) HAMLE plakası mevcut yıldız süslü
  skor plakasını kullanır, HUD kalan / sonuç kullanılan / bütçe
  gösterir (brif kilitli); (f) mola "Yeniden Başlat" gece yarısından sonra kopya taşımadan güncel günü başlatır (brif
  §20 ile uyumlu); (g) bilinmeyen sürüm bloğu varsayılana iner (görevlerle aynı kural), uzak gelecek tamamlanma günü o
  güne kadar ✓ gösterir (günlük ödüllerin taban kuralıyla aynı), başarısız kayıt yazmasında bellek ödüllü kalır (mevcut
  işlem sözleşmesi) — NIT, belgelendi.

### 4.28 Normal RESULT_DELAY eski sonuç yarışı koruması (TASK/048)

> **✅ TAMAM, main'de** — owner onayıyla ff-only `848797a → b9ae345` (2026-10-02; merge commit / rebase / squash /
> cherry-pick / force push yok; dal `task/048-result-delay-race-guard` duruyor, son incelenen HEAD `b9ae345`). Zincir
> (main `848797a`'dan, 11 commit): `c58c88d` düzeltme · `9ab9917` test · `83dc208` nesil sırası (inceleme) ·
> `2592a1b` test sağlamlaştırma · `0f6996d` doküman / A36 kaydı · `3633d6a` son engel düzeltmesi · `8157b56` +
> `f5d005a` + `1b5b300` test · `441a114` yorum · `b9ae345` doküman / hedefli A36 kaydı. Entegrasyondan ÖNCE: önce
> yeniden üretim, mutasyon 9/9, 5 mercekli inceleme, tam masaüstü kapısı ve Samsung A36 yerel kapısı GEÇTİ (yalnız
> QA paketi, cihaz bulgusu yok); **son engel — geçiş reklamı fırlatma aralığı — KAPATILDI** (aşağıda "Son engel"):
> odak suite 196/196, mutasyon 17/17, çekişmeli inceleme, tam masaüstü kapısı (43 / 43 suite, 5457 kontrol, 0 hata,
> 0 SCRIPT ERROR, bot 2/2), hedefli A36 kapısı GEÇTİ. Entegrasyon ve doküman eşitlemesi sırasında hiçbir kapı yeniden
> koşulmadı.

- **Eski yarış (§4.24'te kayıtlı, TASK/046 A36 kapısında cihazda 1/1 üretilmişti):** normal round kesinleşince
  (`Main._on_round_finished`) ilerleme hemen yazılır, sonuç ve doğal mola geçiş reklamı RESULT_DELAY (0,8 sn) SONRA
  açılır. Büyütücü dönüşümü board'a bağlı bir tween'dir (0,15 sn anticipation) ve mola dondurmasında da tamamlanır:
  dönüşüm başlar, mola açılır, hedefe ulaşan dönüşüm round'u açık molanın ALTINDA bitirir; 0,8 sn içinde molanın
  "Yeniden Başlat"ı ya da "Ana Menüye Dön"ü (→ Harita'dan başka level / Sonsuz, Ana Sayfa → MEYDAN OKUMA) round'u
  değiştirince eski sonuç (yeni level'ın başlığıyla, eski round'un verisiyle) ve eski geçiş reklamı yeni round'un,
  Ana Sayfa / Harita'nın ya da meydan okumanın üstüne açılıyordu. Kayıp / Sonsuz bitişi molada OLUŞAMAZ (taşma sayacı
  donukken ilerlemez; bitişten sonra mola açılmaz) — o yollar aynı üretim işleyicisiyle sınandı.
- **Kök neden:** gecikmeden sonra round sahipliği hiç denetlenmiyordu. `_present_result` yalnız `seq` ve "herhangi bir
  board var mı"ya bakıyordu (yeni board geçerli → eski sonuç açılır); `try_show_interstitial` ondan da önce
  çağrılıyordu (board yokken bile — Ana Sayfa'da eski reklam). `_result_seq` round değişiminde ilerlemiyordu.
- **Düzeltme (`scripts/main.gd`, en küçük sahiplik mekanizması):** yalnız bellekte `_round_generation` (kayıt şeması
  aynı). Board'un her değişimi tek noktadan geçer — `_clear_board` (yeni round `_begin_round`'da önce onu çağırır;
  terk / sonuç çıkışı / meydan okumadan çıkış da onu çağırır) — nesil orada, board bağları koptuktan SONRA +1.
  `_on_round_finished` nesli gecikmeden ÖNCE yakalar; gecikmeden sonra `_round_still_owned(generation)` değilse
  geçiş reklamı DENEMEDEN ve sonucu SUNMADAN döner; `_present_result` (reklam kapanış geri çağrısı dahil) nesli
  yeniden doğrular. Eski devamlar sessizce düşer: mola yeniden açılmaz, gezinme yönlendirilmez, yeni round'un
  dokunuşu / ilerlemesi / yüzeyi değişmez. Mola / Ayarlar / öne dönüş / sekme / sonuç sunumu nesli DEĞİŞTİRMEZ.
  TASK/047 meydan okumanın kendi deneme kimliği (`_challenge_attempt` + `_challenge_result_current`) aynen.
- **İlerleme:** XP, görev ilerlemesi / Hamur'u, yıldız / level kilidi, tur sayısı, sandık (beceri ve bonus), teselli,
  Sonsuz rekoru kesinleşmede (gecikmeden ÖNCE) TEK yazmada diske iner — sonuç ekranı kayda yazmaz (inceleme
  doğruladı). Bastırılan sonuç yalnız SUNUMU düşürür: ilerleme geri alınmaz, yinelenmez; yeni round güncel
  ilerlemeden başlar ve kendi kesinleşmesini bir kez yazar. (Değiştirilen round'un sandık ödülü sonuç ekranı
  görünmeden yazılmış olur — "Ana Menüye Dön"de önceden de böyleydi; yeniden başlatmada önceden eski sonuç yanlışlıkla
  yeni round'un üstünde gösteriyordu.)
- **Reklam:** geçerli (sahipliği süren) normal sonuçta politika birebir (uygunluk / hazırlık / 60 sn bekleme / aktif
  saat / yaş yönlendirmesi; tek çağrı noktası). Eski round reklam DENEMEZ (olay bile yok, uygunluk ve hazır reklam
  korunur); meydan okuma bitişi hiç denemez (TASK/047 aynen).
- **Testler:** yeni `tools/result_delay_race_test` (gerçek Main + board, kayıt `user://qa_result_delay_race/`'e
  yönlendirilir, sahibin kayıt ailesi bayt bayt karşılaştırılır; "gecikmeden sonra" denetimleri Main'in kendi
  zamanlayıcısıyla aynı saatte): A geçerli kazanma / kayıp + gecikmede arka plan / öne dönüş · B GERÇEK dokunuş
  (Büyütücü düğmesi + hedef + HUD geri + "Yeniden Başlat"; dokunuş yeni board'a sızmaz) · C Ana Sayfa · D başka
  level · E Sonsuz · F meydan okuma (reklamsız + reklam uygun) · G yeni sonuç eskisini yener (B'nin sonucu kilit
  rozetsiz — ayırt edilebilir) · H iki eski devam · I ilerleme bir kez · J kayıp · K Sonsuz · L tutorial · M nesil
  değişmezleri · N reklam (geçerli aynen; eski denemez; reklam açıkken değiştirilen round kapanışta / gösterim
  hatasında sonuç açmaz, yönetici temiz) · O kaynak sözleşmesi. **Düzeltmesiz `848797a`'da 105 kontrolün 29'u
  DÜŞTÜ** (eski sonuç / reklam her değiştirme yolunda); düzeltmeyle **127/127**. Etkilenen mevcut suite'ler
  (interstitial, result_ui, missions, player_progression, daily_challenge_flow / _ui, gameplay_shell, tutorial)
  değişmeden geçti.
- **Mutasyon 9/9 öldü** (her biri bayt-aynı geri kondu): gecikme sonrası denetim kaldırıldı · yeniden başlatmada /
  terkte nesil ilerlemez · denetim reklam denemesinden SONRA · sonuç aşaması denetimi kaldırıldı · sahiplik level
  numarasından · eski nesil kabul · nesil artışı kaldırıldı · nesil gecikmeden SONRA yakalanır.
- **5 mercekli çekişmeli inceleme** (sahiplik / ilerleme / reklam / girdi-gezinme / yaşam döngüsü + test kalitesi):
  düzeltmede BLOCKER / HIGH / MEDIUM 0. Uygulanan: nesil artışı bağlar koptuktan sonraya (`83dc208`); testte saat
  birliği, gerçek güç düğmesi, sızıntı denetimi, reklamsız çapraz kip, yaşam döngüsü, yönetici durumu, ayırt edilebilir
  sonuç (`2592a1b`).
- **Tam masaüstü kapısı (`2592a1b`):** 43 koşu, 5431 kontrol, 0 hata, 0 SCRIPT ERROR, bot 2/2; sahibin kayıt ailesi
  görev öncesi yedekle bayt-aynı; Godot süreci kalmadı.
- **Samsung A36 yerel kapısı — GEÇTİ (2026-10-02, cihaz saati 15:42–15:51):** yalnız QA paketi (APK `2592a1b`'den,
  104,325,632 B; `verify_apk.py` PASS — paketlenmiş Main jeton tablosunda `_round_generation` + `_round_still_owned`);
  Google TEST reklamları; telefon saati ve gezinme kipi DEĞİŞMEDİ; her girdi öncesi güvenlik kontrolü, parti başına
  dokunuş sayımı (yabancı dokunuş 0, güvenlik durdurması gerekmedi). Büyütücü + mola, 0,15 sn penceresi adb
  gecikmesinin altında olduğundan QA kancasıyla (üretim mola işleyicisi); DEĞİŞTİRME gerçek dokunuşla. Sonuçlar:
  **kazanma yarışı** — round molada bitti, gerçek "Yeniden Başlat" 206 / 263 / 265 ms sonra yeni board kurdu; gecikme
  doldu: eski sonuç YOK, eski geçiş reklamı denemesi YOK (reklam uygun + hazırken), yeni board etkin ve gerçek dokunuşta
  tam 1 bırakış; **geçerli sonuç** — değiştirilmeyen round'da gerçek Google TEST geçiş reklamı gecikmeden sonra açıldı,
  gerçek GERİ ile kapandı, sonuç TAM bir kez (eski round'unki hiç); **ilerleme** — Level 4 ilk kazanma (XP +30, tur
  +1, yıldız, sandık) bellek + diskte bir kez, 3 sn sonra değişmedi; **kayıp** — gerçek VAZGEÇ → üretim yeniden başlatma
  işleyicisi 212 ms sonra: eski kayıp sonucu yok, teselli +5 bir kez; **çapraz kip** — gerçek "Ana Menüye Dön" 310 ms
  sonra, meydan okuma 346 ms'de başladı: eski normal sonuç / reklam yok, meydan okuma gerçek dokunuşta 1 hamle, kazanma
  sonucu aynen (+20, geçiş reklamı denemesi yok); **girdi** — Ayarlar → GERİ → ilk dokunuş 1 bırakış, gerçek
  ACTION_CANCEL 0 / sonraki 1, canlı round'da mola → Yeniden Başlat çalışır (dokunuş sızmadı). Logcat: SCRIPT ERROR 0,
  çökme / ANR 0, godot E 0, Play Age Signals 0, yalnız Google örnek reklam kimlikleri. Kapı sonunda QA paketi
  kaldırıldı; üretim paketi hiç kurulmadı; `com.example.squishymerge` dokunulmadı (0.8.5, zamanlar aynı); masaüstü
  korunan dosyalar + kayıt ailesi içerik olarak aynı. UNKNOWN / TEEN yaş bandı: reklam / yaş kodu değişmedi →
  masaüstü regresyonu (age_ad_routing, interstitial, monetization) kapsar.
- **Son engel — geçiş reklamı fırlatma aralığı (2026-10-02, `3633d6a` düzeltme · `8157b56` + `f5d005a` + `1b5b300`
  test · `441a114` yorum · doküman / hedefli A36 kaydı):** önceki düzeltme sahipliği `try_show_interstitial`'dan ÖNCE yalnız bir kez
  doğruluyordu. Reklam SDK'ya verildikten sonra geri alınamaz — zincir `MonetizationManager.try_show_interstitial`
  → `_backend.show_interstitial` → `Admob.show_interstitial_ad` → JNI `AdmobPlugin.show_interstitial_ad` →
  `Interstitial.show()` (`runOnUiThread` + ana Looper'a `interstitialAd.show(activity)`); Google Mobile Ads'te
  iptal / kapatma API'si YOK → **geri dönülmez nokta = arka uç gösterim çağrısı** (Main'in denetiminden hemen sonra,
  aynı karede). Bu çağrı ile reklamın ekranı örtmesi arasındaki kısa aralıkta (A36'da ölçülen: istekten reklamın
  ekranı örtmesine 55–65 ms, SDK "gösterildi" bildirimine 91–149 ms) açık molanın "Yeniden Başlat" / "Ana Menüye Dön"ü
  round'u HEMEN değiştiriyordu; açılan eski reklam yeni round'un / Harita'nın üstünde kalıyordu (eski sonuç zaten
  açılmıyordu). **Önce yeniden üretildi:** düzeltmesiz `0f6996d`'de yeni P bölümü 188 kontrolün 8'ini DÜŞÜRDÜ — gerçek
  mola dokunuşundan sonra tam ekran reklam açıldığı anda "board YENİ, nesil 1 → 2" (yeniden başlatma) / "board YOK,
  Harita" (çıkış).
- **Sözleşme:** normal round'un geçiş reklamı yalnız onu isteyen round nesli sonuç akışının sahibiyken görünür —
  sahiplik denetimden → istekten → tam ekran açılıp kapanana (ya da gösterim hatası / onay zaman aşımı / öne dönüş
  payı) kadar SÜRER. **Düzeltme (`scripts/main.gd`):** `_round_break_generation` reklam isteğinden hemen önce o
  round'un nesline kurulur; mola sürerken (nesil hâlâ aynı) molanın "Yeniden Başlat" / "Ana Menüye Dön"ü
  `_defer_round_change` ile ertelenir (mola kapanır, round DEĞİŞMEZ); mola bitince yöneticinin tek geri çağrısı
  (`_present_result`) sahipliği bırakır, nesli yeniden doğrular ve ertelenen değişimi eski sonucun YERİNE
  çalıştırır; `_clear_board` ertelenmiş değişimi düşürür. "Devam Et", GERİ, mola kilidi, RESULT_DELAY, reklam
  politikası (uygunluk / 60 sn / 900 sn / onay zaman aşımı / yerleşim), yaş / rıza, TASK/047, kayıt şeması AYNEN.
  Meydan okuma round'u reklam istemediği için ertelemeye hiç girmez.
- **Testler (`result_delay_race_test` P bölümü, 8 değişke, gerçek mola dokunuşu):** [A] dokunuşsuz / Devam Et →
  kendi reklamı + sonucu bir kez; [B] istekten önce → reklam istenmez; [C] istekten sonra → reklam açıldığı anda
  board + nesil aynı; [D] gösterim hatası → ertelenen değişim, eski sonuç yok; [E] reklam kapanırken (öne dönüş
  payı) ve onay zaman aşımı → aynı; [F] yeni round'un geçerli reklamı + sonucu aynen; [G] meydan okuma denemesi
  SIFIR; [H] ilerleme bir kez. N4 / N5 ertelenmeyen yoldan (Harita kartı — QA) geri çağrı nesil denetimini korur;
  N4 eski ertelemenin sonraki sonucu çalamadığını kanıtlar; O sırayı sabitler. 196/196.
- **Mutasyon 17/17 öldü** (her biri bayt-aynı geri kondu; eski 9 yeniden bağlandı + fırlatma: geç sahiplik denetimi
  kaldırıldı · yalnız istekten önce doğrulama · geri çağrıda eski nesil kabulü (= M05) · eski kapanış / hata geri
  çağrısı eski sonucu açar · yeniden başlatma / çıkış ertelenmez · ertelenen değişim düşer · board değişiminde
  erteleme kalır · sahiplik bırakılmaz).
- **Çekişmeli inceleme (salt okunur):** BLOCKER / HIGH 0; MEDIUM 1 = değişmezin sınırının dürüst yazımı (aşağıda
  "Kalan sınır" — kod / yorum / doküman buna göre; `441a114` yalnız yorum, kod satırı değişmedi); LOW / NIT aşağıda.
- **Tam masaüstü kapısı (`441a114`):** 43 koşu / 5457 kontrol / 0 hata / 0 SCRIPT ERROR / bot 2/2.
- **Hedefli Samsung A36 kapısı:** GEÇTİ (2026-10-02, cihaz saati 17:26–17:35; yalnız QA paketi — APK `441a114`'ten,
  `verify_apk.py` PASS, paketlenmiş Main jeton tablosunda `_round_break_generation` + `_defer_round_change` +
  `_deferred_round_change`; Google TEST reklamları). Açılış aralığı adb dokunuşuyla vurulamadığından (istekten örtmeye
  55–65 ms) QA kancası isteğin beklemeye geçtiği İLK karede açık molanın düğmesine uygulama içi dokunuş verdi (GUI →
  düğme → mola → Main'in üretim işleyicisi). **R (Yeniden Başlat):** round molada bitti (nesil 1), istek 791 ms sonra
  gitti, aynı karede dokunuş: mola kapandı, board + nesil AYNI (ertelendi); gerçek Google TEST geçiş reklamı kendi
  round'unun üstünde açıldı (ekran görüntüsü), reklam açıkken de round değişmedi, sonuç yok; gerçek GERİ ile kapandı →
  ertelenen yeniden başlatma kapanıştan 71 ms SONRA yeni board kurdu; eski sonuç hiç açılmadı; ilerleme kesinleşmede
  bir kez (XP +20, tur +1, görev); yeni board gerçek dokunuşta tam 1 bırakış. **V:** yeni round'un geçerli bitişi
  gerçek TEST reklamını gösterdi, kapanınca KENDİ sonucu tam bir kez. **X (Ana Menüye Dön):** reklam yine kendi
  round'unun üstünde; ertelenen çıkış kapanıştan SONRA → Harita (tam ekran reklam / sonuç yok). **G:** gerçek
  dokunuşla meydan okuma (Cum T6·540·36), reklam UYGUN + HAZIRken bitiş: geçiş reklamı denemesi SIFIR, MEYDAN OKUMA
  TAMAM +20. Bir güvenlik durdurması (telefon araması algılandı → hiçbir şey gönderilmedi, 65 sn güvenli sürene dek
  salt okunur bekleme, yabancı dokunuş 0). Logcat: SCRIPT ERROR 0, çökme / ANR 0, Play Age Signals 0, yalnız Google
  örnek reklam kimlikleri (godot E 2 = QA kancası sahnesinin UID uyarısı; üretim kodu 0). Sonunda QA kaldırıldı;
  üretim paketi hiç kurulmadı; `com.example` dokunulmadı; gezinme kipi ve telefon saati değişmedi; masaüstü korunan
  dosyalar + kayıt ailesi görev öncesiyle içerik olarak aynı.
- **Kalan sınır (SDK, owner bilgisi — iptal API'si yok):** sahiplik yöneticinin molayı bitirmesine dek sürer. SDK
  hiçbir şey bildirmezse yönetici mevcut politikayla vazgeçer — onay zaman aşımı (5 sn "gösterildi" gelmezse) ya da
  öne dönüş payı (öne dönüşten 3 sn sonra kapanış gelmezse) — ve ertelenen değişim çalışır; SDK reklamı bundan SONRA
  yine açarsa (geri çağrı sözleşmesi dışı) geç reklam o anki durumun üstünde görünebilir. Önceden de sonuç ekranı için
  kabul edilen M8.9-02 davranışı; oyun tarafında önlenemez (en olası onay zaman aşımı nedeni — eklenti önbelleğinde
  olmayan kimliğin sessizce atlanması — hiç reklam göstermez).
- **Aynen kalanlar:** RESULT_DELAY = 0,8 sn; mola kilidi (bitişten sonra mola açılmaz); Android GERİ; TASK/045.2
  `TOUCH_SETTLE_MSEC = 300`; TASK/046.2 `elif not touch.canceled:`; tutorial; reklam / yaş / rıza; kayıt şeması;
  TASK/047 meydan okuma (7 preset, dizi, +20, tekrar yok, güç / devam yok, yalıtım, monoton gün, geçiş reklamı yok,
  kendi eski sonuç koruması). Görsel değişiklik YOK (yalnız davranış).
- **Kayda geçen, DÜZELTİLMEYEN (inceleme LOW — mola davranışı kilitli, owner kararı):** ~~(1) mola açıkken bitip
  DEĞİŞTİRİLMEYEN round'un geçerli sonucu açık molanın (katman 12) ALTINDA (katman 10) açılır; o durumda Android GERİ
  `_result.visible` dalında yutulur — DEVAM ET / X / karartma çözer (önceden var olan)~~ → **TASK/049 ile kapatıldı —
  main'de `f6cd072`, §4.29**; ~~(2) geçiş reklamı açılış aralığında molanın "Yeniden Başlat" / "Ana Menüye Dön"ü reklamı
  yeni durumun üstünde bırakabilir~~ → **son engelde KAPATILDI** (yukarıda); (3) `_start_level` 300 ms parmak yatışması
  kurmaz: "Yeniden Başlat" / TEKRAR / Harita kartına hızlı çift dokunuşun ikincisi yeni round'a parça düşürebilir
  (önceden var olan; ertelenen yeniden başlatmada da — mola bittiği anda bitmiş board'da basılı kalan parmağın bırakışı
  yeni round'a düşebilir). Son engel incelemesinin kaydettiği (LOW / NIT, düzeltilmedi): mola HİÇ bitmezse ("gösterildi"
  gelip ne kapanış ne öne dönüş gelirse — çift SDK / yaşam döngüsü arızası; molasız aynı durum önceden de kilitlenirdi)
  açık molanın Yeniden Başlat / Ana Menüye Dön'ü ertelemede kalır; ertelenen değişim sürerken HUD Ayarlar açılırsa yeni
  round Ayarlar'ın altında başlar (görsel); QA komutları `abandon` / `leave` da mola sürerken ertelenir (cihaz harness'i
  notu). Öneri: kesinleşmede mola / refill'i kapatmak (§4.24 önerisinin ikinci yarısı — yarışı kaynağında da kapatır) +
  `_start_level`'da yatışma — ayrı görev. *(İlk yarısı → TASK/049 ile yapıldı — main'de `f6cd072`, §4.29; `_start_level`
  yatışması açık.)* *(`_start_level` yatışması → TASK/051 ile düzeltildi — main'de `4bae821`, §4.31.)* *(Hiç bitmeyen
  mola → TASK/052 ile düzeltildi — main'de `c7e3ccc`, §4.32.)* *(Ertelemede / beklemede Ayarlar → TASK/053 ile
  düzeltildi — main'de `275c537`, §4.33.)* *(Basılı Koleksiyon kartı + GERİ → TASK/054 ile düzeltildi — main'de
  `88c8570`, §4.34.)* *(Genel GUI ACTION_CANCEL (modal / karartma, Sarsıntı düğmesi) → TASK/055 ile düzeltildi — main'de
  `e0c1a71`, §4.35.)* Ayrı kalan, açık: T5 hedef kartı kırpması "Büyük Dumpl…" *(→ TASK/056 ile kapatıldı —
  main'de `ee2778a`, §4.36)*.

### 4.29 Round bitişi pencere sahipliği (TASK/049)

> **✅ TAMAM, main'de** — owner onayıyla ff-only `25860df → f6cd072` (2026-10-03; merge commit / rebase / squash /
> cherry-pick / force push yok; dal `task/049-round-finish-modal-ownership` duruyor, son incelenen HEAD `f6cd072`).
> Zincir (main `25860df`'den, 8 commit): `8a204bd` düzeltme · `acfb28e` yeni suite · `6a17162` TASK/048 suite
> uyarlaması · `7f46272` inceleme sağlamlaştırması (kapalı mola eylem yaymaz; kapanış ilerleme yazıldıktan sonra) ·
> `4649ae7` test sağlamlaştırması · `6d247c7` test sağlamlığı · `db4564f` doküman / A36 kaydı (kapılardan geçen üretim
> adayı) · `f6cd072` final kabul kaydı (yalnız doküman; aşağıda "Final kabul kapısı"). Entegrasyondan ÖNCE tamamlanan
> doğrulama: odak 164 / 164 (TASK/049) + 197 / 197 (TASK/048), mutasyon 37 / 37 (20 TASK/049 + 17 TASK/048), fark
> testi settings_input / gameplay_shell / progression_ui aday 5 / 5 = taban 5 / 5 temiz, kontrollü kanonik tam
> masaüstü kapısı (`db4564f`) 44 / 44 temiz — 5622 kontrol, 0 hata, 0 SCRIPT ERROR, bot 2/2 — ve Samsung A36 kapısı
> GEÇTİ (aşağıda). Entegrasyon ve doküman eşitlemesi sırasında hiçbir kapı yeniden koşulmadı. Aşağıdaki maddeler dal
> aşamasında yazıldı (tarihsel); güncel açık maddeler PROJECT_CONTEXT → Next action'da.

- **Eski hata (§4.28'in "Kayda geçen" (1)'i):** Büyütücü dönüşümü board'a bağlı bir tween'dir (0,15 sn anticipation);
  mola ve stok 0 refill dondurması ağaç duraklatması DEĞİL, özel board dondurmasıdır — tween sürer. Dönüşüm başlar,
  mola açılır (ya da stok 0 bir güce basılır → refill penceresi), dönüşüm hedefe ulaşıp round'u o pencerenin ALTINDA
  meşru biçimde bitirir; ilerleme yazılır, RESULT_DELAY (0,8 sn) sonra sonuç (katman 10) açık molanın (12) / refill'in
  (11) ALTINA açılırdı: Android GERİ sonuç dalında yutulur, sonuç düğmelerine gerçek dokunuş eski molaya / refill'e
  gider, mola geçerli geçiş reklamının ardından da sonucun üstünde kalır, board bitişten sonra menü duraklamasında
  kalırdı (`set_menu_paused` bitmiş board'da çalışmaz).
- **Kök neden:** `GameBoard._finish` bitişte devam / refill / tutorial dondurmalarını bırakıp `round_finished`
  yayıyordu ama menü duraklamasını değil; `Main._on_round_finished` bitişi kabul edip yalnız devam teklifini (ve
  tutorial yüzeyini) kapatıyordu — mola ve refill penceresi kesinleşmeden sağ çıkıyordu.
- **Değişmez:** round'un bitişi kabul edildiği anda o round'un oyun içi engelleyici pencereleri sonuç / geçiş reklamı
  akışının üstünde kalmaz ve girdi tutmaz — z-sırasıyla değil, pencere kapanarak.
- **Düzeltme (3 dosya):** (1) `Main._dismiss_terminal_gameplay_overlays()` — `_on_round_finished`'da kesinleştirme
  korumasından sonra, round'un ilerlemesi yazıldıktan SONRA, RESULT_DELAY beklemesinden ÖNCE tek kez (eşzamanlı, bitiş
  karesinde): açıksa mola `close_menu()` (gizle + kapanış sesi, sinyal YOK), açıksa refill `hide_refill()` (gizle,
  sinyal YOK; açık bir ödüllü refill talebine dokunulmaz — iptal edilmez, ödül verilmez, kendi token yolu sürer).
  Ayarlar'a, ikincil pencerelere, gezinmeye, round değişimine, kayda dokunmaz; pencere yoksa / tekrar çağrılırsa hiçbir
  şey yapmaz. (2) `GameBoard._finish` menü duraklamasını da bırakır (diğer pencere dondurmalarıyla birlikte, sinyalden
  önce). (3) `PauseMenu`: KAPALI pencere eylem yaymaz — üç düğme, X ve karartma tek görünürlük kapısından
  (`_emit_if_open`) geçer.
- **İnceleme + sonda (`7f46272`):** Godot, odaklı kontrolü gizlerken ona sentetik bırakış yollar; son girdi olayı
  "işlendi" değilse (ör. GERİ tuşu, başka bir parmak / aygıt) BaseButton bunu tıklama sayar — masaüstü 4.6.3 sondasında
  basılı Yeniden Başlat / Ana Menüye Dön / Devam Et gizlemede tetiklendi (A36'daki basılı Koleksiyon kartı + GERİ ile
  aynı motor yolu); gizlenen karartma ise parmak odağını düşürmez (basılı parmağın bırakışı sonradan ona gelir). İlk
  düzeltmede (`8a204bd`) yalnız karartma korunuyordu ve temizlik ilerleme okunmadan önce çalışıyordu: bitişte basılı
  Yeniden Başlat'ın sentetik tıklaması `_on_round_finished` içinde yeni board kurup round'un ilerlemesini sıfırlanmış
  GameState'ten hesaplatabilirdi. Kapı + sıralama bu yolu kapattı; testte (E "+ olay" değişkeleri) ve mutasyonla
  (N16–N20) kilitli.
- **Dahil edilen pencereler:** mola (onaylı hedef) ve stok 0 refill penceresi (aynı kök neden; masaüstünde gerçek
  dokunuşla yeniden üretildi, düzeltmeden önce sonucun üstünde kalıyordu). Zaten kapananlar: devam teklifi
  (`_revive.hide_offer()`), tutorial yüzeyi (`finish_for_round_end`). **Hariç:** Ayarlar (kapsam dışı açık madde —
  bilinçli olarak kapatılmaz, regresyonla kilitli); meydan okuma (TASK/047 donuk işleyici — aşağıda); kayıp / Sonsuz
  (taşma sayacı dondurmada ilerlemez, devam teklifi molayı / refill'i dışlar — mola altında bitiş yolu yok,
  uydurulmadı).
- **İkinci bitiş yolu (inceleme + sonda):** fizik adımı teması kaydeder, raporu bir sonraki adımın başında gelir — o
  arada girdi molayı açmışsa ertelenmiş `_resolve_merge` (molayı denetlemez) hedef merge'i molada bitirebilir (~1
  kare). Normal round'da aynı temizlik kapsar (suite R bölümü). **Gözlem — meydan okuma (ÖNCEDEN VAR OLAN / AYRI,
  DÜZELTİLMEDİ, owner kararı):** aynı yol meydan okumayı da molada bitirebilir; kendi işleyicisinde temizlik olmadığı
  için mola meydan okuma sonucunun üstünde kalır (sondada doğrulandı; final kabulde düzeltmesiz `25860df` dosyalarıyla
  da yeniden üretildi — aşağıda; TASK/047 donuk olduğundan dokunulmadı; düzeltme aynı tek satırlık çağrı olur).
  *(→ TASK/050 ile düzeltildi — main'de `8f9e259`, §4.30.)*
- **TASK/048 ile ilişki:** TASK/048 kodu davranış olarak AYNEN (nesil, fırlatma sahipliği, erteleme, eski geri çağrı
  bastırması; yalnız iki yorum satırı). Değişen tek şey: mola artık kesinleşmeden sağ çıkmadığından üretimde gecikme /
  fırlatma aralığında round'u değiştiren dokunuş yolu kalmadı — erteleme savunma olarak duruyor. `result_delay_race_test`
  molanın AYNI üretim işleyicilerini (`_on_pause_restart` / `abandon_run` / `resume_game`) molanın kendi sinyaliyle
  çağıracak şekilde uyarlandı (dar dikiş); her sahiplik denetimi korundu (197 kontrol; fırlatma aralığında her
  işleyiciden sonra reklam sahipliğinin bırakılmadığı da denetleniyor), 17 TASK/048 mutantı uyarlanmış suite'te öldü.
  Garanti sınırı aynen: SDK tam ekranı geri dönülmez biçimde kabul ettikten sonra iptal API'si yok.
- **Testler:** yeni `tools/round_finish_modal_test` (A–R, 18 bölüm, 164 kontrol; gerçek Büyütücü düğmesi + hedef + HUD
  geri / Android geri yolu, bitiş anı eşzamanlı ölçülür, geçerli geçiş reklamı, eylemsiz kapanış ve basılı parmak,
  girdi sahipliği, gerçek merge + 75'lik bonus sandıkla ilerleme bir kez / bellek = disk, TASK/048 savunması, Ayarlar,
  refill (+ bekleyen ödüllü talep kazanılır / kazanılmaz), kayıp / Sonsuz / meydan okuma / tutorial, ACTION_CANCEL,
  canlı round'da gerçek mola düğmeleri, aynı karede merge yolu, kaynak sözleşmesi). **Düzeltmesiz `25860df`'de 121
  kontrolün 48'i DÜŞTÜ** (mola katman 12 sonucun katman 10 üstünde, board menü duraklamasında, GERİ yutuldu, sonucun
  HARİTA'sına gerçek dokunuş eski molaya gitti; mola reklamdan sonra da kaldı; refill sonucun üstünde kaldı).
- **Mutasyon 37/37 öldü** (her biri bayt-aynı geri kondu, HEAD-blob denetimi): N01–N20 TASK/049 (temizlik kaldırıldı ·
  yalnız mola dalı · menü duraklaması kaldı · çerçeve gizli katman açık · Devam / Yeniden / Ana Menü ile kapatma ·
  temizlik sonuçtan sonra · mola reklamdan sonra geri gelir · Ayarlar da kapanır · refill dalı yok · refill KAPAT ile
  (talebi iptal eder) · refill satın almayla · karartma kapısı yok · meydan okuma da temizlenir · temizlik ilerlemeden
  önce · kapı kaldırıldı · Yeniden / Ana Menü / Devam kapıyı atlar) + M01–M09 / L1, L2, L4–L9 TASK/048 kataloğu.
- **Çekişmeli inceleme (5 mercek, salt okunur):** BLOCKER / HIGH / MEDIUM 0. LOW'lar giderildi: mola düğmeleri kapısız
  (sondayla doğrulandı → `7f46272`), canlı round'da gerçek mola düğmesi kapsamı, ilerleme bölümünde merge / bonus sandık,
  başarısız kurulumda betik hatası yerine FAIL, TASK/048 suite'inde boşa geçebilen denetimler; NIT'ler giderildi ya da
  kayda geçti (iki parmakla karartma kenar durumu zararsız; fazladan kapanış sesi kozmetik).
- **Tam masaüstü kapısı (aday `6d247c7`, üç koşu, her biri korumalı import sonrası 44 koşu):** OK 5617 · 5620 · 5664,
  FAIL 5 · 2 · 1 (3. koşuda revive_test'in botlu senaryo 1 tekrarı fazladan OK satırı sayar; suite'in kendisi 120/120);
  42 · 43 · 43 suite temiz; hiçbir koşu 44/44 temiz DEĞİL — hatalar YALNIZ önceden var olan zamanlama hassas
  denetimlerde: settings_input 4 + gameplay_shell 1 (koşu 1), progression_ui 2 (koşu 2), settings_input 1 (koşu 3).
  settings_input = Profil dişlisi yatışması (DÜZELTMESİZ `25860df` üretim dosyalarıyla da aynı 4 denetim düştü),
  gameplay_shell = çift GERİ debounce, progression_ui = unvan seçici yatışması: SceneTreeTimer ile ölçülen duvar saati
  paylarıdır, TASK/049'un dokunmadığı yollar; her biri hemen yeniden koşuda geçti. TASK/049 ile ilgili suite'ler (yeni
  suite, TASK/048, meydan okuma, girdi iptali, görevler, devam) her koşuda temiz. SCRIPT ERROR 0, bot 2/2, sahibin kayıt
  ailesi her koşuda bayt-aynı.
- **Final kabul kapısı — GEÇTİ (2026-10-03, aday `db4564f` = `6d247c7` + yalnız doküman; üretim kodu / testler
  değişmedi):** (1) **Fark testi** — yukarıdaki üç zamanlama hassas suite (settings_input, gameplay_shell,
  progression_ui), aynı korumalı koşucuyla, sırayla, ABBA düzeninde (c1 b1 b2 c2 c3 b3 b4 c4 c5 b5): 5 kez aday, 5 kez
  düzeltmesiz `25860df` üretim dosyalarıyla (yalnız TASK/049'un değiştirdiği üç dosya `25860df` blob'larından yazıldı;
  üç suite iki commit'te aynı; aday dosyalar her taban koşusundan sonra HEAD blob'larından geri yazılıp sha256 ile
  doğrulandı). Sonuç: **aday 5 / 5, taban 5 / 5 temiz** (her koşu 160 + 147 + 187 = 494 kontrol), 0 hata, 0 SCRIPT
  ERROR, kayıt her koşuda bayt-aynı; aday tabandan kötü değil, yeni hata imzası yok. Sakin makinede (CPU %2–16) hiçbiri
  düşmedi — yukarıdaki hatalar makine yükü altında ortaya çıkan zamanlama payı sınıfıdır (settings_input'un aynı 4
  denetimi daha önce `25860df` dosyalarıyla da düşmüştü). (2) **Odak** — round_finish_modal_test 164 / 164,
  result_delay_race_test 197 / 197. (3) **Meydan okuma gözlemi** — aynı geçici sonda (mola açıkken aynı karede merge):
  `25860df` dosyalarıyla normal round da meydan okuma da molada biter, mola iki sonucun da üstünde kalır (katman 12 /
  10, board menü duraklamasında); adayla normal round'da mola kapanır, meydan okumada aynen kalır (tek fark: bitmiş
  board'un menü duraklaması bayrağı adayda iner — görünür davranış aynı). Meydan okuma
  işleyicisi, mola açma / işleyici yolları ve board merge yolu iki commit'te bayt-aynı → **ÖNCEDEN VAR OLAN / AYRI**,
  TASK/049 getirmedi, düzeltilmedi. (4) **Kontrollü kanonik tam masaüstü kapısı (TEK koşu)** — mutasyon / inceleme /
  derleme / dışa aktarma / telefon aracı / arka plan Godot yok (adb sunucusu durduruldu), 3 dk yatışma, korumalı
  import temiz: **44 / 44 koşu temiz, 5622 kontrol, 0 hata, 0 SCRIPT ERROR, bot 2/2; sahibin kaydı bayt-aynı, korunan
  dosyalar değişmedi** → tam masaüstü kapısı TEMİZ.
- **Samsung A36 kapısı — GEÇTİ (2026-10-03, cihaz saati 06:47–06:59; yalnız QA paketi, Google TEST reklamları; APK
  `6d247c7`'den, `verify_apk.py` PASS):** 0,15 sn penceresi adb gecikmesinin altında olduğundan mola QA kancasıyla
  açıldı — HUD geri düğmesine uygulama içi gerçek dokunuş (A1) ve Android GERİ yönlendirmesi (A2), ikisi de üretim
  `open_pause_menu` yoluna varır. **A1/A2:** mola açıktı (dönüşüm sürüyordu), bitiş anında mola kapandı / menü
  duraklaması bırakıldı / eylem 0, sonuç 863 / 803 ms sonra tek başına açıldı; sonuçta gerçek GERİ yok sayıldı, gerçek
  HARİTA dokunuşu sonuca gitti. **B:** mola bitişte kapandı; reklam molası bitişten 790 ms sonra (mola zaten kapalı)
  başladı, geçerli Google TEST geçiş reklamı 883 ms'de göründü, gerçek GERİ ile kapandı → sonuç TAM bir kez, mola geri
  gelmedi; ilerleme bir kez; sonucun TEKRAR'ı → yeni round'da ilk dokunuş tam 1 bırakış. **C (TASK/048 savunması,
  üretim işleyicisi QA dikişiyle — mola artık oraya varamaz):** gecikme içinde (bitişten 275 ms sonra) yeniden başlatma
  → eski sonuç yok, geçiş reklamı olayı sıfır (reklam hazır + uygunken); fırlatma aralığında yeniden başlatma ertelendi,
  reklam kendi round'unun üstünde açıldı, kapanıştan 47 ms sonra yeni board, eski sonuç yok; yeni board'lar gerçek
  dokunuşta 1 bırakış. **D:** canlı round'da gerçek GERİ → mola → DEVAM ET / Yeniden Başlat çalışır (dokunuş sızmaz),
  Ayarlar → GERİ → ilk dokunuş 1, gerçek ACTION_CANCEL 0 / sonraki 1. **Refill:** dönüşüm sırasında açılan refill bitişte
  kapandı; stok / kota / Hamur satın alması yok, sonuç tek başına. Logcat: SCRIPT ERROR 0, çökme / ANR 0, godot E 0,
  Play Age Signals 0, yalnız Google örnek reklam kimlikleri. Güvenlik durdurması gerekmedi (dokunuş sayıları tuttu).
  Sonunda QA kaldırıldı; üretim paketi hiç kurulmadı; `com.example.squishymerge` dokunulmadı (0.8.5, zamanlar aynı);
  gezinme kipi ve telefon saati değişmedi; masaüstü korunan dosyalar + kayıt ailesi görev öncesiyle içerik olarak aynı.
- **Aynen kalanlar:** RESULT_DELAY 0,8 sn; ilerleme (bir kez, kesinleşmede) / kayıt şeması (yeni alan yok); reklam
  politikası (uygunluk / 60 sn / 900 sn / yerleşim / yaş / rıza); TASK/047 meydan okuma; tutorial; Sonsuz;
  TOUCH_SETTLE_MSEC 300; `elif not touch.canceled:`; görsel değişiklik yok.
- **Açık (owner kararı, bu görevde düzeltilmedi):** (1) `_start_level` 300 ms yatışma kurmaz — yeniden başlatmada hızlı
  çift dokunuş / basılı parmak yeni board'a düşebilir *(→ TASK/051 ile düzeltildi — main'de `4bae821`, §4.31)*; (2) hiç
  bitmeyen tam ekran molada molanın çıkış kapısı yok (yönetici zaman aşımı / öne dönüş payına dek) *(→ TASK/052 ile
  düzeltildi — main'de `c7e3ccc`, §4.32)*; (3) RESULT_DELAY / reklam beklemesinde açılan (ya da bitişte açık) Ayarlar
  sonucun üstünde kalır (görsel) *(→ TASK/053 ile düzeltildi — main'de `275c537`, §4.33)*; (4) basılı Koleksiyon kartı +
  Android GERİ sentetik bırakışı *(→ TASK/054 ile düzeltildi — main'de `88c8570`, §4.34)*; (5) genel GUI ACTION_CANCEL
  (modal / karartma iptali, Sarsıntı düğmesi) *(→ TASK/055 ile düzeltildi — main'de `e0c1a71`, §4.35)*; (6) T5 hedef
  kartı kırpması "Büyük Dumpl…" *(→ TASK/056 ile kapatıldı — main'de `ee2778a`, §4.36)*; + ayrı, önceden var olan
  gözlem: meydan okumanın aynı karede merge ile molada bitmesi
  (yukarıda; `25860df`'de de var) *(→ TASK/050 ile düzeltildi — main'de `8f9e259`, §4.30)*. Masaüstü zamanlama hassas üç
  suite denetimi (yukarıda) test sağlamlığı notu olarak kayda geçti (fark testinde aday = taban; kontrollü kanonik
  koşuda düşmedi).

### 4.30 Meydan okuma bitişi pencere sahipliği (TASK/050)

> **✅ TAMAM, main'de** — owner onayıyla ff-only `c543cd1 → 8f9e259` (2026-10-03; merge commit / rebase / squash /
> cherry-pick / force push yok; dal `task/050-daily-challenge-terminal-modal-ownership` duruyor, son incelenen HEAD
> `8f9e259`). Zincir (main `c543cd1`'den, 4 commit): `43a528d` düzeltme · `9a02bd7` yeni suite · `537e8d8` inceleme
> sağlamlaştırması (yalnız test; kapılardan geçen üretim adayı) · `8f9e259` doküman / A36 kaydı (yalnız doküman).
> Entegrasyondan ÖNCE tamamlanan doğrulama: odak — TASK/050 suite'i 178 / 178, TASK/048 suite'i 197 / 197, TASK/049
> suite'i 164 / 164, etkilenen suite'ler 1082 kontrol / 0 hata; mutasyon 16 / 16 (betik hatasıyla öldürme yok, her geri
> koyma bayt-aynı); 6 mercekli inceleme BLOCKER / HIGH 0 (tek MEDIUM test boşluğu son kapılardan önce giderildi);
> kontrollü kanonik tam masaüstü kapısı (üretim adayı `537e8d8`) 45 / 45 temiz — 5800 kontrol, 0 hata, 0 SCRIPT ERROR,
> bot 2/2, sahibin kaydı bayt-aynı — ve Samsung A36 kapısı GEÇTİ (aşağıda; `537e8d8`'den dışa aktarılmış, doğrulanmış
> QA APK'sıyla). Entegrasyon ve doküman eşitlemesi sırasında hiçbir kapı yeniden koşulmadı. Aşağıdaki maddeler dal
> aşamasında yazıldı (tarihsel); güncel açık maddeler PROJECT_CONTEXT → Next action'da.

- **Hata (§4.29'un "meydan okuma molada biter" gözlemi — ÖNCEDEN VAR OLAN, TASK/049 getirmedi):** fizik adımı iki aynı
  tier parçanın temasını kaydeder, raporu bir sonraki adımın başında gelir; arada girdi molayı açarsa (özel board
  dondurması) rapor DONMUŞ parçalara yine ulaşır → `Dumpling.merge_requested` → ertelenmiş `_resolve_merge` (molayı
  denetlemez) → hedef tier → `_finish(true)` → meydan okumanın KENDİ işleyicisi. İşleyici molayı hiç kapatmıyordu: mola
  (katman 12) meydan okuma sonucunun (10) üstünde kalıyor, Android GERİ sonuç dalında yutuluyor, sonucun ANA SAYFA
  dokunuşu eski molaya gidiyordu. **Gerçek fizikle** (dikiş yok) düzeltmesiz `c543cd1`'de yeniden üretildi (sonda 6/6:
  temas fizik adımında, mola aynı karenin boşta evresinde gerçek HUD geri dokunuşuyla, sonraki adımın temas raporu →
  merge → molada meydan okuma başarısı → RESULT_DELAY sonra mola sonucun üstünde).
- **Kök neden:** TASK/049'un `_dismiss_terminal_gameplay_overlays()` temizliği yalnız normal `_on_round_finished`'daydı;
  `_on_challenge_round_finished` (TASK/047) yalnız devam teklifini kapatıyordu. Kayıp yolları açık molada
  kesinleşemez: taşma sayacı `_physics_process`'te (duraklatılmışken çalışmaz), hamle bitti kararı `_is_paused()`
  denetler — uydurulmadı, korunması sınandı.
- **Düzeltme (tek çağrı + yorum, `43a528d`):** `_on_challenge_round_finished` paylaşılan TASK/049 temizliğini çağırır —
  `_round_finalized` korumasından ve ödül / tamamlanma işleminden (`complete_daily_challenge`) SONRA, RESULT_DELAY
  beklemesinden ÖNCE, işleyici düzeyinde tek kez. Ortak pencere temizliği, AYRI iş mantığı: meydan okuma normal yola /
  reklama / ilerlemeye girmez; deneme kimliği (`_challenge_result_current`) aynen; temizlik gövdesi değişmedi (mola
  `close_menu`, refill `hide_refill`; refill meydan okumada zaten açılamaz — güçler kapalı). Ayarlar kapsam dışı (açık
  madde (3) *(→ TASK/053 ile düzeltildi — main'de `275c537`, §4.33)*); regresyonla kilitli.
- **Kabul edilen davranış (TASK/050 sözleşmesi — genel bir pencere sistemi DEĞİL):** o anki meydan okuma denemesinin
  kimliği belirleyici kalır (TASK/047 deneme jetonu korunur); kabul edilen meydan okuma bitişi oyunun engelleyici
  pencerelerini kapatır — mola kapanır, menü duraklaması sahipliği bırakılır; temizlik Devam / Yeniden Başlat / Ana
  Sayfa tetiklemez, basılı / sentetik mola bırakışı eylem üretmez, bırakış sızdırmaz; sonuç zamanlaması aynen
  (RESULT_DELAY 0,8 sn); ilk başarı tam +20 Hamur, tamamlanan gün tam bir kez, başarıdan sonra yeniden oynama yok;
  deterministik parça dizisi, tekrar deneme kuralları, monoton kabul edilen gün ve bozuk saat davranışı aynen; meydan
  okuma XP / görev / başarım / yıldız / normal istatistik / bonus sandık merge payı / Sonsuz'dan yalıtık; meydan okuma
  round bitişi geçiş reklamı SIFIR; TASK/048 savunması ve TASK/049 normal bitiş sahipliği aynen.
- **TASK/049 suite'i:** kaynak sözleşmesindeki "meydan okuma işleyicisi temizliği çağırmaz / tek çağrı yeri" sınırı
  "tam iki round bitiş işleyicisi (normal + meydan okuma), başka yer yok" olarak güncellendi (normal yol denetimleri
  aynen).
- **Testler:** yeni `tools/daily_challenge_terminal_modal_test` (A–Q, T, S; 19 bölüm, 178 kontrol): aynı kare penceresi
  GERÇEK fizikle — iki (hedef − 1) parça fizik karesinin içinde temasta doğar, aynı karenin boşta evresinde mola gerçek
  HUD geri dokunuşu / Android geri / mola işleyicisiyle açılır, sonraki karenin gerçek temas raporu meydan okumayı
  bitirir; eylem sayaçları, +20 / tamamlanma tek kez (kayıt hatası enjeksiyonuyla "yazma girişimi yok" kanıtı),
  yalıtım, reklamsızlık, gece yarısı / bozuk saat, aynı oturumda normal round, Ayarlar regresyonu, kaynak sözleşmesi.
  Düzeltmesiz `c543cd1`'de ilk sürüm 134 kontrolün 39'u, sağlamlaştırılmış sürüm 178'in 53'ü DÜŞTÜ (hepsi
  mola-üstünde-sonuç imzası + kaynak sözleşmesi; ödül / yalıtım / reklamsızlık bölümleri tabanda da geçti — işlem
  zaten doğruydu); düzeltmeyle 178/178; odak küme (10 suite) 1082 kontrol, 0 hata, 0 SCRIPT ERROR.
- **Mutasyon 16/16 öldü** (FAIL ile, betik hatası 0; her geri koyma HEAD-blob bayt-aynı).
- **Çekişmeli inceleme (6 mercek):** BLOCKER / HIGH 0; tek MEDIUM (Ayarlar regresyon testi eksik) giderildi; LOW / NIT
  test boşlukları giderildi (`537e8d8`). Kapsam dışı üretim notları (önceden var olan, owner kararı): normal round devam
  teklifinin düğmelerinde kapalı-pencere kapısı yok (inceleme notu, doğrulanmadı); meydan okumadan çıkışta
  `_current_level` level 0'da kalıyor (UI'dan ulaşılamaz); gecikmede HUD dişlisi Ayarlar'ı sonucun üstüne açabilir
  (Ayarlar maddesi).
- **Tam masaüstü kapısı (kontrollü, tek kanonik koşu, `537e8d8`):** 3 dk yatışmadan sonra, korumalı içe aktarma temiz;
  45 / 45 koşu temiz, 5800 kontrol, 0 hata, 0 SCRIPT ERROR, bot 2/2; sahibin kaydı bayt-aynı.
- **Samsung A36 kapısı GEÇTİ (2026-10-03; yalnız QA paketi `com.obappstudio.squishymerge.qa`, Google TEST reklam
  kimlikleri; telefon saati ve gezinme kipi değişmedi — meydan okuma günü uygulama içinde QA kancasıyla):** aynı kare
  penceresi canlı board'da (iki hedef − 1 parça üretim yoluyla temasta, mola aynı karenin boşta evresinde; merge ve
  bitiş GERÇEK).
  (A) HUD geri dokunuşu yolu: mola açık, round bitmemiş → gerçek temas raporu meydan okumayı bitirdi; meydan okuma
  bitiş işleyicisi pencere temizliğini mevcut RESULT_DELAY beklemesine girmeden önce eşzamanlı çağırdı — Main'in
  işleyicisinden sonra aynı `round_finished` yayımına bağlı dinleyicinin bitiş anı görüntüsü mola=false, menü
  duraklaması=false, Devam / Yeniden Başlat / Ana Menü / sonuç eylemi 0 gördü (harness'ın sonraki "PAUSE closed"
  satırı kare bazında yoklandığından FINISH satırından birkaç ms sonra görünür); sızan bırakış yok; eski mola meydan
  okuma sonucunun gösterimine / girdi sahipliğine taşınmadı → sonuç 799 ms sonra tek başına; gerçek GERİ yutuldu
  (sonuç kaldı, mola açılmadı); sonucun ANA SAYFA'sına gerçek dokunuş → çıkış 1 → Ana Sayfa, pill ✓.
  (B) Android GERİ yolu (uygulama içi `NOTIFICATION_WM_GO_BACK_REQUEST` → üretim `Main._notification`): aynı; sonuç
  811 ms sonra.
  (C) Hamur +20 tam bir kez (335 → 355), tamamlanan gün bir kez; bellek farkı tam [daily_challenge, dough]; XP / görev /
  başarım / yıldız / round istatistiği / bonus sandık / Sonsuz aynı; kayıt yalnız bitişte BİR kez yazıldı (sonuç, GERİ,
  ANA SAYFA ve +20 sn boyunca değişmedi); zorla durdurma + soğuk açılış: tamamlanma kalıcı, pencerede BAŞLA yok
  (başlatma reddedildi). İlk denemenin disk farkı `unlocked_achievements`'ı da listeledi: açılıştaki
  `reconcile_achievements()` vitrin kaydının başarımlarını yalnız BELLEKTE açar, sonraki doğal kayıt kalıcılaştırır
  (TASK/044 sözleşmesi) — meydan okumanın tek kaydı denemeden ÖNCE bellekte olanı yazdı, meydan okuma sızıntısı değil;
  sonraki iki denemede bellek farkı == disk farkı == [daily_challenge, dough].
  (D) Google TEST geçiş reklamı HAZIR + uygunken meydan okuma bitişlerinde SIFIR geçiş reklamı olayı (deneme / atlama
  yok; gösterim 0, deneme 0, bekleyen reklam arası yok); banner kuralı aynen (meydan okuma oyununda GAMEPLAY görünür,
  sonuçta gizli, Ana Sayfa / Harita'da görünür — normal round'la aynı).
  (E) TASK/049 normal korunması (Level 3, Büyütücü + anticipation içinde HUD geri): mola bitişte kapandı, sonuç 847 ms
  sonra tek başına (geçiş reklamı henüz uygun değil → atlandı); geçerli TEST geçiş reklamıyla: mola bitişte kapandı →
  reklam arası mola zaten kapalıyken başladı → Google "interstitial test ad" → ikinci gerçek GERİ ile kapandı (TEST
  reklamı ilkini yok saydı) → sonuç tam bir kez, mola geri gelmedi; ilerleme bir kez (bellek farkı == disk farkı).
  (F) Girdi: normal canlı round'da gerçek GERİ → mola → gerçek DEVAM ET (0 drop, sonraki dokunuş 1 drop) / gerçek
  Yeniden Başlat (yeni board, sızan bırakış yok, sonraki dokunuş 1 drop) / gerçek Ana Sayfa; meydan okumada bitişten
  önce gerçek DEVAM ET (deneme sürer, hamle 0); gerçek ACTION_CANCEL 0 drop, sonraki bağımsız dokunuş 1 drop (normal +
  meydan okuma); bitişten sonra gizli mola katmanı YOK — kapanan molanın DEVAM ET / Yeniden Başlat / Ana Sayfa
  konumlarına sonuç üstünde 3 gerçek dokunuş (olay günlüğünde teslim edildi) eylem üretmedi, sonucun ANA SAYFA'sı
  çalıştı, Ana Sayfa'daki ilk gerçek dokunuş normal. `_start_level` çift dokunuş / basılı parmak maddesine
  dokunulmadı.
  logcat (kurulumdan beri iki QA süreci): SCRIPT ERROR 0, çökme / ANR 0, godot hata 0, yalnız Google örnek reklam
  birimleri. Sonunda QA kaldırıldı; üretim paketi hiç kurulmadı; `com.example.squishymerge` dokunulmadı (0.8.5,
  zamanlar aynı); adb otomasyonu kalmadı; masaüstü korunan dosyalar + `_visual_source` + kayıt ailesi kapı öncesiyle
  aynı, sahibin kaydı bayt-aynı.
- **Aynen kalanlar:** TASK/047 (presetler, torba, pinlenmiş dizi, +20 / aynı gün +0, tekrar / yeniden oynama yok,
  kayıt bloğu, yalıtım, monoton gün, bozuk saat, reklamsızlık), TASK/048 (nesil, fırlatma sahipliği, erteleme),
  TASK/049 (normal yol, kapalı mola eylem yaymaz), RESULT_DELAY 0,8 sn, TOUCH_SETTLE 300 ms, ACTION_CANCEL koruması;
  kayıt şeması, reklam politikası, görsel değişiklik yok.
- **Açık (owner kararı, bu görevde düzeltilmedi):** (1) `_start_level` yatışma / çift dokunuş / basılı parmak *(→
  TASK/051 ile düzeltildi — main'de `4bae821`, §4.31)*; (2) hiç bitmeyen tam ekran molada çıkış kapısı *(→ TASK/052 ile
  düzeltildi — main'de `c7e3ccc`, §4.32)*; (3) gecikmede Ayarlar sonucun üstünde (görsel) *(→ TASK/053 ile düzeltildi —
  main'de `275c537`, §4.33)*; (4) Koleksiyon kartı + GERİ *(→ TASK/054 ile düzeltildi — main'de `88c8570`, §4.34)*; (5)
  genel GUI ACTION_CANCEL *(→ TASK/055 ile düzeltildi — main'de `e0c1a71`, §4.35)*; (6) T5 kırpması "Büyük Dumpl…"
  *(→ TASK/056 ile kapatıldı — main'de `ee2778a`, §4.36)*.

### 4.31 Round başlangıcında dokunuş sahipliği (TASK/051)

> **✅ TAMAM, main'de** — owner onayıyla ff-only `1293eb2 → 4bae821` (2026-10-04; merge commit / rebase / squash /
> cherry-pick / force push yok; dal `task/051-start-level-touch-settle` duruyor, son incelenen HEAD `4bae821`). Zincir
> (main `1293eb2`'den, 6 commit): `abe05c1` düzeltme · `5b76a68` yeni suite · `aa14b4b` TASK/048 suite uyarlaması
> (yalnız test) · `ec8d14c` + `12ca7ba` suite sağlamlaştırması (yalnız test; `12ca7ba` kapılardan geçen üretim / test
> adayı) · `4bae821` doküman / A36 kaydı (yalnız doküman). Entegrasyondan ÖNCE tamamlanan doğrulama: odak — TASK/051
> suite'i 126 / 126, 0 SCRIPT ERROR (düzeltmesiz `1293eb2`'de 90 OK / 36 FAIL, 0 SCRIPT ERROR; yalnız yatışmayla 10,
> yalnız sahiplikle 27 FAIL kalıyor — iki parça da gerekli), TASK/048 korunması 197 / 197 (3/3 temiz); mutasyon
> 19 / 19 (hepsi açık FAIL kontrolleriyle; son mutasyon kaydında 0 SCRIPT ERROR; her geri koyma bayt-aynı); 6 mercekli
> inceleme BLOCKER / HIGH / MEDIUM 0; kontrollü kanonik tam masaüstü kapısı (üretim / test adayı `12ca7ba`) 46 / 46
> temiz — 5926 kontrol, 0 hata, 0 SCRIPT ERROR, bot 2/2, sahibin kaydı bayt-aynı — ve Samsung A36 kapısı GEÇTİ
> (aşağıda; `12ca7ba`'dan dışa aktarılmış, doğrulanmış QA APK'sıyla). Entegrasyon ve doküman eşitlemesi sırasında
> hiçbir kapı yeniden koşulmadı. Aşağıdaki maddeler dal aşamasında yazıldı (tarihsel); güncel açık maddeler
> PROJECT_CONTEXT → Next action'da.

- **Hata (önceden var olan — açık madde (1); §4.28 (3)):** `_start_level` mevcut 300 ms parmak yatışmasını kurmuyordu
  (meydan okuma başlangıcı `start_daily_challenge` kuruyor). Düğmenin öykünen fare bırakışı yeni board'u eşzamanlı
  kurar; "Yeniden Başlat" / TEKRAR / Harita düğümü / Sonsuz düğümüne hızlı ikinci dokunuş (basılı tutulsa da) yeni
  board'a basış + bırakış olarak düşüp bir parça bırakıyordu; ikinci dokunuş yeni board'un HUD geri'sine düşerse mola
  açılıyordu. Ayrıca `GameBoard` bir bırakışın basışının KENDİSİNE ulaşıp ulaşmadığına bakmıyordu: değişimden önce
  basılmış ve canlı bir arayüz kontrolünün tutmadığı parmak (iki parmakla eski board'da, Harita arka planında, serbest
  bırakılan eski HUD / güç düğmesinde; TASK/048 ertelenen yeniden başlatmada bitmiş board'da) yeni board'da kalkınca bir
  parça bırakıyordu. Düzeltmesiz `1293eb2`'de sondayla (P1–P11) ve yeni suite'le yeniden üretildi. Değişimi başlatan
  parmağın KENDİ ScreenTouch bırakışı yeni board kurulduktan sonra gelir ama gizli düğmenin parmak odağına gider —
  sızıntı değil; bölünmemeli (bölünürse TASK/045.2 hatası geri gelir).
- **Kök neden:** (1) `_start_level` → `_begin_round` hiçbir yatışma kurmuyordu; kabuk `_hide_shell` ile gizlendiğinden
  `_show_tab` yatışması da yok. (2) Kanonik yatışma pencereden ÖNCE başlamış diziyi bilinçli olarak bölmez (TASK/045.2) —
  değişimi atlatan parmağı tek başına kapatamaz; `GameBoard` sahipsiz bırakışı da işliyordu.
- **Düzeltme (`abe05c1`, iki parça):** (a) `Main._start_level` mevcut `settle_touch_input()`'u `add_child(_board)`'dan
  hemen sonra BİR kez çağırır (meydan okuma başlangıcıyla aynı nokta; pencere board girdiye hazır olduğu an başlar;
  TOUCH_SETTLE_MSEC 300 aynen, yeni süre / zamanlayıcı / bekleme / kare hilesi yok; çağıranlar ayrıca kurmaz).
  (b) `GameBoard` basışı kendisine ulaşmış parmak dizilerini kaydeder (`_owned_touches` / `_note_owned_touch`,
  `_unhandled_input`'ın ilk satırı — bitiş / mola / tutorial kilidi / hedefleme kapılarından ÖNCE) ve basışı kendisine
  hiç ulaşmamış dizinin sürüklemesini / bırakışını işlemez. Kayıt bırakışla (iptal dahil) ya da aynı parmağın yeni
  basışıyla kapanır; zamanlayıcı yok. Aynı board'da başlamış diziler, ACTION_CANCEL (0 bırakış), hedefleme,
  DROP_COOLDOWN 0,4 sn ve bırakış kuralları aynen.
- **Kabul edilen davranış (TASK/051 sözleşmesi — genel bir girdi debounce sistemi DEĞİL):** `_start_level()` mevcut
  kanonik `settle_touch_input()`'u yeni board eklendikten sonra BİR kez kurar (amaçlanan geçiş sahipliği sınırı);
  `GameBoard` dokunuş sahipliği board başına açıktır — sürükleme / bırakış yalnız basışı O board'a ulaşmış dizide
  işlenir, önceki board'dan / geçişten kalan bayat dizi yok sayılır, sahiplik bırakış / iptal ya da aynı parmağın yeni
  basışıyla kapanır; yeni zamanlayıcı yok. TOUCH_SETTLE_MSEC = 300 aynen; ikinci bir keyfî yatışma süresi yok,
  ~600 ms'lik eklemeli pencere yok. Bayat geçiş jesti → 0 bırakış; pencere içinde başlayan ikinci dokunuş → board
  sahipliği / bırakış 0; board'lar arası basılı parmak → 0 bırakış; yatışmadan sonraki ilk geçerli bağımsız dokunuş →
  tam 1 bırakış; Yeniden Başlat → tam bir yeniden başlatma / bir yeni board; mola DEVAM ET `_start_level` yatışması
  KURMAZ; ACTION_CANCEL → 0 bırakış, iptalden sonraki geçerli dokunuş → 1.
- **Yollar:** mola Yeniden Başlat, sonuç TEKRAR (WIN ikincil / FAIL birincil), Harita level / Sonsuz düğümü, ilk açılış
  tutorial'ı (açılışta, jest yok — pencere board kurulurken kurulur; BAŞLA ve ilk bırakış normal), TASK/048 ertelenen
  yeniden başlatma (TASK/049'dan beri UI girişi yok; basılı parmak sahiplikle elenir) → hepsi `_start_level`'dan geçer.
  Ana Sayfa doğrudan level başlatmaz (OYNA → Harita'nın mevcut `_show_tab` yatışması — korunması sınandı). Meydan okuma
  kendi yatışmasını aynen kurar; ortak `GameBoard` sahipliği yüzünden değişimi atlatan ikinci parmak artık meydan okuma
  hamlesi harcamaz (tek etki). Mola DEVAM ET aynı board — yatışma KURULMAZ (sonraki dokunuş hemen düşürür).
- **Yol sınıflandırması (son):** TASK/051 ile düzeltilen — mola Yeniden Başlat; aynı kök nedenli sonuç TEKRAR / tekrar
  oynama; Harita level seçimi; Sonsuz seçimi; board'lar arası atlatan dokunuş sahipliği; tutorial başlangıcı (artık
  kanonik round başlangıcı yatışmasını alır); meydan okumada atlatan dokunuş (bayat sahiplikle artık hamle harcamaz);
  TASK/048 ertelenen yeniden başlatmada atlatan dokunuş (sahiplikle engellenir). Korunan / doğrudan etkilenmeyen — Ana
  Sayfa OYNA (level başlatmaz; mevcut sekme geçişi yatışması fazladan dokunuşu zaten yutar); mola DEVAM ET (aynı board,
  `_start_level` yatışması kurulmaz).
- **Kalan zamanlama notu (inceleme notu — düzeltilmedi, görev DEĞİL):** yatışma penceresi olay dağıtımı anında
  ölçülür; level başlangıcından sonraki ilk karesi hızlı ikinci dokunuşu 300 ms penceresinin sonrasına itecek kadar
  uzun takılan patolojik bir cihazda zamanlama engeli kuramsal olarak aşılabilir. Kabul edilen kanıt: 300 ms kanonik ve
  kilitli; A36'da ilk kare ~10 ms, ilk çizim ~16 ms; gerçek ikinci dokunuşlar ~110–118 ms'de yutuldu; pencereden
  sonraki 0,35 sn sınır dokunuşu tam 1 normal bırakış verdi.
- **Testler:** yeni `tools/start_level_touch_settle_test` (A–Q, S; 18 bölüm, 126 kontrol; gerçek dokunuşlar Android
  sırasıyla — öykünen fare önce, ScreenTouch sonra; kayıt `user://qa_start_level_settle/`'e yönlendirilir). Düzeltmesiz
  `1293eb2`'de 36 kontrol DÜŞTÜ (her sızıntı yolu); yalnız yatışmayla 10 (değişimi atlatan parmak: B3, B5, D2, F2, L3,
  Q ve kaynak), yalnız sahiplikle 27 (pencerede başlayan ikinci dizi: B2, B4, C ×3, C2, E ×4, F1 ×3, M, M2 ve G, H, I1,
  N, Q, S) — iki parça da gerekli; düzeltmeyle 126/126, 0 SCRIPT ERROR. TASK/048 suite'i (`result_delay_race_test`) gerçek
  Büyütücü hedef basışını round başlangıcından 70–150 ms sonra yapıyordu → pencerede (doğru biçimde) yutuldu (46 koşuluk
  ön taramada tek etkilenen suite, 10 hata) → `_fire_upgrade` pencere bitince basar (cihaz harness'ının `t48_up`'ı ile
  aynı; yalnız test) → 3/3 koşu 197/197.
- **Mutasyon 19/19 öldü** (M01–M19: yatışma kaldırma / geç / erken / 0 / 30 ms / çift pencere, sahipsiz bırakış düşürür,
  pencerede basış geçer, çift yeniden başlatma, board'lar arası ortak sahiplik, iptal düşürür, hiç bitmeyen engel,
  bırakış hiç sahiplenilmez, DEVAM ET kurar, TEKRAR baypası, sonuç gösterimi kurar, meydan okuma yatışması kaldırma,
  kapıdan sonra kayıt, sahipsiz sürükleme nişan alır); hepsi açık FAIL kontrolüyle — betik hatasıyla öldürme yok; her
  geri koyma HEAD-blob bayt-aynı.
- **Çekişmeli inceleme (6 mercek):** BLOCKER / HIGH / MEDIUM 0. LOW / NIT'ler suite'te giderildi (G zamanlama payları
  ≥ 120 ms + dağıtım anı önkoşulları; H pencere sonunu board hazır +400 ms'de yeniden okur; E / Q ekonomi denetimleri
  geçiş yolu koruması olarak adlandırıldı + "bitiş bir kez yazdı" + E4 sahte reklam arka ucu: TEKRAR'da geçiş reklamı
  isteği yok, sonraki bitiş ilerlemeyi tam bir kez yazar) ya da kayda geçti: pencere DAĞITIM anında ölçülür — level
  başlangıcından sonraki ilk kare uzun takılırsa fiziksel olarak hızlı ikinci dokunuş pencereden sonra işlenip düşebilir
  (kanonik TASK/044 yatışmasının her geçişinde var; board kurulumu kurmadan önce olduğundan pencereyi yalnız uzatabilir;
  A36'da ölçüldü — aşağıda; 300 ms kilitli, "pencere ilk çizilen kareden" owner sözleşme kararı olurdu). Masaüstü fare /
  DeX fare çift tıklaması hâlâ düşürür (`Main._input` fareyi tasarım gereği yok sayar; önceden var olan); mola DEVAM
  ET'e çift dokunuşun ikincisi düşürür (bilinçli — DEVAM ET kurmaz).
- **Tam masaüstü kapısı (kontrollü, tek kanonik koşu, `12ca7ba`, 2026-10-04):** korumalı içe aktarma temiz; 46 / 46 koşu
  temiz (yeni suite + 44 suite + bot), 5926 kontrol, 0 hata, 0 SCRIPT ERROR, bot 2/2 (%100); sahibin kaydı bayt-aynı.
- **Samsung A36 kapısı GEÇTİ (2026-10-04; yalnız QA paketi `com.obappstudio.squishymerge.qa`, Google TEST / örnek reklam
  kimlikleri; gerçek `input` dokunuşları, ikinci parmak QA harness'ıyla — adb bu cihazda çoklu dokunuş gönderemez; her
  girdi güvenlik denetimine bağlı; telefon saati ve gezinme kipi değişmedi; QA APK `12ca7ba`'dan, doğrulama PASS):**
  (A) Yeniden Başlat'ta basılı parmak (gerçek ~507 ms basış; başlatan parmağın ScreenTouch bırakışı yeni board hazır
  olduktan sonra geldi, gizli düğmede tüketildi — bölünmedi) → tek yeniden başlatma, yeni board'da 0 bırakış; pencerede
  yeniden basılıp pencere bittikten 552 ms SONRA kalkan ikinci basış → 0; değişimi atlatan ikinci parmak (eski board'da /
  eski board'un Büyütücü yuvasında; pencere bittikten ~3 sn sonra kalkış) → 0 bırakış, nişan merkezde, stok aynı. Her
  senaryodan sonra ilk bağımsız gerçek dokunuş → tam 1 bırakış.
  (B) Yeniden Başlat'a hızlı gerçek çift dokunuş ×3 → her biri tek yeniden başlatma; ikinci DOWN board hazır olduktan
  111 / 110 / 118 ms sonra yutuldu, 0 bırakış. Sınır: 0,35 sn aralık → ikinci DOWN pencere bittikten 37 ms SONRA →
  bağımsız dokunuş, tam 1 normal bırakış (pencere ~300 ms, uzamadı).
  (C) Sonuç: WIN → TEKRAR OYNA çift dokunuş; FAIL (gerçek red) → TEKRAR + basılı ikinci basış (pencereden 536 ms sonra
  kalkış) → tek yeniden deneme, 0 bırakış, ilerleme yeniden yazılmadı.
  (D) Harita level 3 düğümü ve Sonsuz düğümüne çift dokunuş → tek level, 0 bırakış, nişan merkezde; Ana Sayfa OYNA çift
  dokunuşu (korunma) → Harita, level yok. Soğuk açılışın ilk board'u: ilk kare board hazır olduktan 10 ms, ilk çizim 16
  ms sonra (takılma yok; pay ~180 ms); ikinci dokunuş 114 ms → 0 bırakış.
  (E) Gerçek ACTION_CANCEL: pencereden sonra → 0, sonraki dokunuş 1; pencere içinde → yutulan dizi iptalle kapandı,
  takılı durum yok, sonraki dokunuş 1.
  (F) Mola DEVAM ET: aynı board, yatışma kurulmadı; 198 ms sonraki gerçek dokunuş hemen tam 1 bırakış.
  (G) TASK/049 normal bitiş (Level 3 Büyütücü + öngörüde HUD geri): bitişte mola kapalı, eylem 0, sonuç 844 ms sonra
  tek başına. TASK/050 meydan okuma (gerçek pill + BAŞLA; `t50_up hud`): bitişte mola kapalı, sonuç 794 ms sonra tek
  başına, +20 Hamur tam bir kez, gün tamamlandı.
  logcat (kurulumdan beri iki QA süreci): SCRIPT ERROR 0, çökme / ANR 0, godot hata 0, yalnız Google örnek reklam
  birimleri. Telefon başka bir uygulama öndeyken güvensizdi (02:19–06:40 ve kısa bir an 10:50) → hiçbir girdi / kurulum
  gönderilmedi; girdi yalnız ≥ 60 sn güvenli durumdan sonra. Sonunda QA kaldırıldı; üretim paketi hiç kurulmadı;
  `com.example.squishymerge` dokunulmadı (0.8.5, zamanlar aynı); bu oturumun başlattığı adb sunucusu durduruldu;
  masaüstü korunan dosyalar + `_visual_source` + kayıt ailesi kapı öncesiyle aynı, sahibin kaydı bayt-aynı.
- **Aynen kalanlar:** TOUCH_SETTLE_MSEC 300, `Main._input` dizi kuralı (TASK/045.2), ACTION_CANCEL koruması (TASK/046.2),
  TASK/047 meydan okuma (yalnız atlatan parmak hamle harcamaz), TASK/048 nesil / erteleme / fırlatma sahipliği, TASK/049
  normal bitiş sahipliği, TASK/050 meydan okuma bitişi, RESULT_DELAY 0,8 sn, DROP_COOLDOWN 0,4 sn, fizik, mola
  semantiği, reklam politikası, kayıt şeması; görsel değişiklik yok.
- **Açık (owner kararı, bu görevde düzeltilmedi):** (2) hiç bitmeyen tam ekran molada çıkış kapısı *(→ TASK/052 ile
  düzeltildi — main'de `c7e3ccc`, §4.32)*; (3) gecikmede Ayarlar sonucun üstünde (görsel) *(→ TASK/053 ile düzeltildi —
  main'de `275c537`, §4.33)*; (4) Koleksiyon kartı + GERİ *(→ TASK/054 ile düzeltildi — main'de `88c8570`, §4.34)*; (5)
  genel GUI ACTION_CANCEL *(→ TASK/055 ile düzeltildi — main'de `e0c1a71`, §4.35)*; (6) T5 kırpması "Büyük Dumpl…"
  *(→ TASK/056 ile kapatıldı — main'de `ee2778a`, §4.36)*.
  İncelemenin kayda geçirdiği önceden var olan, kapsam dışı gözlemler (düzeltilmedi, yeni görev açılmadı): Harita
  `_on_node_pressed` / `_on_endless_pressed`'de kapalı-ekran kapısı yok — basılı düğüm + Android GERİ, gizleme anındaki
  sentetik tıklamayla level başlatabilir (statik çıkarım, yeniden üretilmedi; (4) ile aynı motor sınıfı; TASK/051
  sonrası bırakış düşmez) *(→ TASK/055 ile yeniden üretildi ve düzeltildi — main'de `e0c1a71`, §4.35)*; Yeniden Başlat
  sırasında mola karartmasında basılı kalan parmak, mola o parmak kalkmadan yeniden açılırsa kalkışında onu kapatır
  (gizli karartmanın parmak odağı; parça düşmez, geçişe özgü değil).

### 4.32 Tam ekran mola kurtarma + gelir odaklı geçiş politikası (TASK/052)

> **✅ TAMAM, main'de** — owner onayıyla ff-only `1d2fb28 → c7e3ccc` (2026-10-04; merge commit / rebase / squash /
> cherry-pick / force push yok; dal `task/052-fullscreen-break-recovery-monetization` duruyor, son incelenen HEAD
> `c7e3ccc`). Zincir (main `1d2fb28`'den, 10 commit): `635917b` düzeltme (kira) · `4649af1` politika (AdPolicy, 2 round +
> 300 sn) · `5e3f707` + `6ec4f93` + `5de685d` testler · `334422c` inceleme sertleştirmesi · `050ddac` testler · `41b194d`
> sertleştirme takibi · `e16da5a` testler (kapılardan geçen üretim / test adayı) · `c7e3ccc` doküman / A36 kaydı (yalnız
> doküman). Entegrasyondan ÖNCE tamamlanan doğrulama: odak — son aday `e16da5a`'da 15 suite, hepsi 0 FAIL / 0 SCRIPT
> ERROR (fullscreen_break_recovery 117 · ad_policy 54 · interstitial 62 · monetization 258 · daily_rewards 179 ·
> result_delay_race 197 · round_finish_modal 164 · start_level_touch_settle 126 · daily_challenge_flow 76 ·
> daily_challenge_terminal_modal 178 · age_ad_routing 122 · tutorial 205 · refill 119 · revive_refill_ui 266 · revive
> 120); mutasyon 47 / 47 uygulanabilir mutant açık FAIL kontrolleriyle öldü (yalnız SCRIPT ERROR ile öldürme yok, geri
> koymalar bayt-aynı); 8 inceleme merceği + sertleştirme takip incelemesi (tüm BLOCKER / HIGH giderildi; Vulkan sahte
> RESUMED HIGH'ı düzeltildi ve A36'da doğrulandı); kontrollü tam masaüstü kapısı (`e16da5a`) 49 / 49 temiz — 6100
> kontrol, 0 FAIL, 0 SCRIPT ERROR, bot 2 / 2, sahibin kaydı bayt-aynı — ve Samsung A36 kapısı GEÇTİ (aşağıda).
> Entegrasyon ve doküman eşitlemesi sırasında hiçbir kapı yeniden koşulmadı. Owner kararları (2 round + 300 sn ilk
> üretim varsayılanı, ayrı ilk gün yasağı yok, ödüllü kotalar aynı, app-open ertelendi, native takipler not, yayın
> öncesi uyum yeniden incelemesi): ADS_SYSTEM §18.7. Aşağıdaki maddeler dal aşamasında yazıldı (tarihsel); güncel açık
> maddeler PROJECT_CONTEXT → Next action'da. Ayrıntı: docs/monetization/ADS_SYSTEM.md §18 (tasarım, denetimler,
> riskler, owner kararları) + §19 (hesap tarafı kontrol listesi).

- **Hata (önceden var olan, açık madde (2)):** uygulamanın KENDİ tam ekran molası — geçiş reklamı molası (Main
  `_round_break_generation`, sonuç bekliyor) ya da ödüllü talep — SDK'nın kapanış / hata geri çağrısı kaybolursa hiç
  bitmeyebiliyordu: "gösterildi" geldikten sonra 5 sn onay zamanlayıcısı iptal ediliyor, öne dönüş payını yalnız
  APPLICATION_RESUMED kuruyordu; ikisi de yoksa sonuç hiç açılmıyor, mola / BACK bitmiş board'da açılmıyor, ertelenen
  Yeniden Başlat / Ana Menü sonsuza dek bekliyor, aktif saat ve sonraki tüm reklamlar süreç boyunca ölüyordu. Ödüllüde
  onay zamanlayıcısı hiç yoktu. Düzeltmesiz `1d2fb28`'de deterministik yeniden üretildi (sonda + yeni suite'in temel-güvenli ilk sürümü: 43 OK /
  38 FAIL / 0 SCRIPT ERROR; son sürüm süitler aynı kodda 81 FAIL).
- **Düzeltme:** token'lı tam ekran kirası (tek zamanlayıcı): SDK geri çağrıları yetkili; gelmezse kira yalnız örtülmeme
  kanıtıyla biter (gerçek öne dönüş + 3 sn, hiç örtülmeden 5 sn, kayıp öne dönüşte yeni dokunuş + 5 sn; ödüllüde
  "gösterildi" sonrası süreye bağlı bırakma yok; örtülüyken süre işlemez); "kapandı" / "gösterilmedi" sonuçları; ödül
  asla kurtarmayla verilmez; emekli kimlikler; banner PAUSED'da gizlenir. Godot 4.6.3 Vulkan'ın onStart'taki RESUMED'ı
  (reklam üstteyken) öne dönüş sayılmaz — yalnız onResume'un FOCUS_IN'i (şablon bayt kodundan doğrulandı).
- **Politika:** `AdPolicy` — önceki gerçek gösterimden bu yana ≥ 2 kesinleşen NORMAL round VE ≥ 300 aktif sn (önce 900
  sn), 60 sn bekleme aynen, meydan okuma / tutorial sayılmaz, `app_paused` / `consent_form` engel sebepleri; ödüllü kotalar
  DEĞİŞMEDİ; app-open eklenmedi (ertelendi). Envanter simülasyonu (deterministik, sentetik): 46 doğal molada 19 uygun
  zorunlu geçiş fırsatı (önce 4) — toplam fırsat 4,75 kat, +15 mutlak, %375 göreli artış; yalnız uygun envanter,
  gösterim / gelir / ARPDAU garantisi değil (ADS_SYSTEM §18.3).
- **Doğrulama:** `fullscreen_break_recovery_test` 117 / 117 + `ad_policy_test` 54 / 54 (+ uyarlanan süitler); mutasyon
  47 / 47 (açık FAIL, 0 yalnız-betik-hatası, bayt-aynı geri koyma); 8 mercekli inceleme + sertleştirme takip incelemesi
  (BLOCKER 0; HIGH L1-1 giderildi, L5-1 bu doküman güncellemesi); kontrollü tam masaüstü kapısı (`e16da5a`) 49 / 49
  temiz — 6100 kontrol, 0 FAIL, 0 SCRIPT ERROR, bot 2 / 2, sahibin kaydı bayt-aynı; Samsung A36: **GEÇTİ** (2026-10-04; QA APK `e16da5a`'dan, `verify_apk` PASS; telefonun gezinme kipi ve saati değişmedi). **A:** 2. normal round + 300 sn'de gerçek TEST geçiş reklamı — FOCUS_OUT +68 ms, PAUSED +72 ms, SDK "gösterildi" +128 ms; gerçek GERİ ile kapanış → sonuç bir kez, sıradaki reklam önyüklendi. **E:** ilk round (332 sn) yok · gösterimden hemen sonraki round yok · 2 round ama 37 sn yok · 2 round + 300 sn uygun · meydan okuma bitişinde sıfır deneme (sayaç değişmedi; TASK/050 molası bitişte kapandı) · tutorial ve tutorial'dan doğan Level 1 sayılmadı, tutorial sonrası ilk normal round 412 sn'de bile yok, ikinci round'da reklam. **B1** (sahte arka uç — temel hatanın birebiri): "gösterildi", kapanış yok → 4,99 sn'de `uncovered_lease`; mola sırasında ertelenen üretim "Yeniden Başlat"ı eski sonucun YERİNE çalıştı; geç kapanış eski; gerçek dokunuş 1 bırakış. **B2** (gerçek TEST reklamı, kapanış saklı): gerçek öne dönüşten 3,0 sn sonra `resume_grace`, sonuç bir kez. **C1:** sahte molada gerçek HOME → 15 sn arka planda bitiş yok → dönüşte RESUMED (onStart) sonra FOCUS_IN, pay FOCUS_IN'den 2,98 sn sonra. **C2:** kayıp öne dönüş (yalnız yöneticiye simüle) + gerçek dokunuş → 5 sn sonra `input_evidence`, duraklatma düştü. **C3 (inceleme L1-1):** gerçek reklam üstteyken HOME + Son Uygulamalar dönüşü → Vulkan onStart RESUMED focus_in'siz geldi; kira ~27 sn, SDK kapanışına dek korundu, kurtarma 0. **D1:** gerçek devam CTA'sı → PAUSED "gösterildi"den önce, ödül ~8 sn'de tam bir kez. **D2:** kapanış saklı → ödül bir kez, 2,97 sn'de kurtarma. **D3:** ödül + kapanış saklı — TEST reklamının açtığı Play Store yarım sayfası nedeniyle girdi durduruldu, ~47 dk yalnız okuma yoklaması; bu sürede kira hiç süreyle bırakılmadı; owner reklamı kapattıktan sonra (QA uygulamasına tek dokunuş) `resume_grace`, devam 0 (sahte ödül yok). **G:** TASK/049 / 050 / 051 korundu. **F:** app-open N/A. Logcat: SCRIPT ERROR / çökme / ANR 0, yalnız Google örnek yayıncısı; QA kaldırıldı, üretim paketi hiç kurulmadı, `com.example` dokunulmadı. Kayıt: `build/qa_052-gate/device/GATE_LOG.md`.
- **Kalan / owner:** ADS_SYSTEM §18.5 (geç SDK gösterimi, dokunuşsuz kayıp öne dönüş, eklentinin yetim yeniden
  yüklemesi — native, sıklık / elde tutma deneyi, TEEN uyum maddeleri) ve §19 hesap tarafı işler.

### 4.33 Ayarlar / terminal sonuç sahipliği (TASK/053)

> **✅ TAMAM, main'de** — owner onayıyla ff-only `5b7a727 → 275c537` (2026-10-05; merge commit / rebase / squash /
> cherry-pick / force push yok; dal `task/053-settings-terminal-ownership` duruyor, son incelenen HEAD `275c537`).
> Zincir (main `5b7a727`'den, 5 commit): `796e1e7` düzeltme · `4b29c26` test (yeni suite + TASK/049 / 050 suite
> uyarlaması) · `fd4f6e6` inceleme sertleştirmesi · `be44ca4` test (kapılardan geçen üretim / test adayı) · `275c537`
> doküman / A36 kaydı (yalnız doküman). Aşağıdaki doğrulamanın tamamı entegrasyondan ÖNCE tamamlandı; entegrasyon ve
> doküman eşitlemesi sırasında hiçbir kapı yeniden koşulmadı. Eski açık madde (3) FIXED + MAIN; o tarihte açık kalan tam
> 3 madde: (4) Koleksiyon kartı + GERİ *(→ TASK/054 ile kapatıldı — main'de `88c8570`, §4.34)*, (5) genel GUI
> ACTION_CANCEL *(→ TASK/055 ile kapatıldı — main'de `e0c1a71`, §4.35)*, (6) T5 hedef kartı kırpması (PROJECT_CONTEXT →
> Next action) *(→ TASK/056 ile kapatıldı — main'de `ee2778a`, §4.36)*. TASK/054 o tarihte tanımlanmamıştı.

- **Hata (önceden var olan, eski açık madde (3) — FIXED + MAIN):** Ayarlar `CanvasLayer` katman 13, sonuç katman 10 —
  ikisi birden görünürse Ayarlar üstte, karartması sonucun girdisini tutar. (1) TASK/049'un terminal temizliği
  (`_dismiss_terminal_gameplay_overlays`, normal + TASK/050 meydan okuma bitişi) Ayarlar'ı bilerek dışarıda bırakıyordu:
  menü dondurmasında da round biter (Büyütücü dönüşümü 0,15 sn board tween'i; aynı karede ertelenmiş merge), bitişte
  açık Ayarlar sonuç açıldığında hâlâ üstündeydi. (2) HUD dişlisinin yolu (`_on_board_settings_requested` →
  `open_settings`) round'un kesinleştiğine bakmıyordu (`open_pause_menu` bakıyor): dişli bitişten sonra dokunulabilir
  kalıyor; RESULT_DELAY (0,8 sn) ya da geçiş reklamı molası içinde Ayarlar açılıyor, sonuç onun altında açılıyordu;
  TASK/048'in ertelenen yeniden başlatması yeni round'u Ayarlar'ın altında başlatıyordu. Faz A izlemesi + düzeltmesiz
  `5b7a727`'de deterministik yeniden üretim (A–E kayıtları: round nesli, sonuç sırası, Ayarlar / mola / refill
  görünürlüğü, menü dondurması, sonuç görünürlüğü, olay sırası / zaman damgaları; yeni suite'in o sürümü 57 / 116 FAIL,
  0 SCRIPT ERROR).
- **Düzeltme (en küçük sahiplik düzeltmesi; gecikme / gezinme yeniden yazımı yok):** terminal temizlik açık Ayarlar'ı da
  kendi kapanış yoluyla kapatır (`close_settings()`; kapanış işleyicisi bitmiş board'da hiçbir şey yapmaz, tercih
  yazılmaz; sıra mola → refill → Ayarlar, gecikmeden ÖNCE, round başına bir kez); `open_settings()` (tek açma noktası:
  HUD dişlisi, Profil dişlisi, QA) `_terminal_round_owns_screen()` — `_round_finalized` + board ekranda — iken açmaz ve
  `false` döndürür; HUD dişlisi board'u yalnız `open_settings()` `true` döndürünce dondurur (reddedilen açılış board'a
  dokunmaz); `SettingsPanel` gizliyken ses / titreşim / Yaş bilgisi / gizlilik seçenekleri / politika işleyicileri
  eylem üretmez (pencere bir kontrol basılıyken gizlenirse Godot gizleme anında sentetik bırakış yollar; son girdi
  işlenmemişse BaseButton bunu tıklama sayar — TASK/049'un mola dersi; korumasız sürümde tercih yazılıyor, yaş paneli
  sonucun üstüne açılıyordu). Yeni round (`_begin_round`) bayrağı indirir; çıkış / terk board'u kaldırır — Profil / kabuk
  yolu etkilenmez. Bitiş dışında Ayarlar, GERİ, kalıcılık AYNEN; RESULT_DELAY 0,8 sn, 300 ms yatışma, TASK/046.2 iptal
  koruması ve TASK/048 nesil / erteleme yolu değişmedi.
- **Bilinçli sınırlar (inceleme notu, düzeltilmedi):** Ayarlar'dan açılan alt pencereler (yaş bilgisi paneli katman 14,
  UMP gizlilik formu, tarayıcı) temizliğin dışında — dokunuşla bitişte açık olamazlar (menü dondurmasında bitiş yalnız
  0,15 sn dönüşüm / aynı kare merge; `open_settings` 300 ms yatışma kurar; gizli Ayarlar onları açmaz); anahtarın süren
  topuz animasyonu / basış ölçeği kozmetik (Android GERİ yolunda tabanda da aynı); bitmiş board'da reddedilen dişli
  olağan dokunma sesini / squish'i oynatabilir (bitmiş board'daki HUD geri reddiyle aynı — owner KABUL ETTİ: kozmetik,
  engel değil, ayrı görev değil).
- **Doğrulama (entegrasyondan ÖNCE; entegrasyon ve doküman eşitlemesi sırasında hiçbir kapı yeniden koşulmadı):** yeni
  `tools/settings_terminal_ownership_test` 129 / 129 (A bitişte açık — gerçek dişli dönüşüm
  sırasında; B bekleme / sonuç / reklam molasında açma girişimi — gerçek dokunuşlarda pozitif kontrol: istek dişliye
  ulaştı; C bitiş dışında aynen; D GERİ; E mola / refill + Ayarlar; F menü dondurması sızmaz — F4 kapalı kapıda canlı
  board donmaz; G meydan okuma; H TASK/048; I tekrar / çıkış; J yinelenen bitiş; K tercih kalıcılığı + basılı kontrol
  varyantları — "+ olay" varyantlarında gizli tıklama tam 1, yeniden açılışta anahtar = kayıt; P kaynak sözleşmesi);
  uyarlanan `round_finish_modal_test` 163 (§I) ve `daily_challenge_terminal_modal_test` 178 (§T) — ikisi eskiden
  "Ayarlar sonucun üstünde kalır"ı mevcut davranış olarak kilitliyordu; odak grubu (`be44ca4`) 4 / 4 suite (bu üçü +
  `release_config_test` 202) — 672 kontrol, 0 FAIL, 0 SCRIPT ERROR; taban farkı (116 kontrollü sürüm, aynı koşucu):
  taban 57 · yalnız temizlik 27 · yalnız kapı 36 · pencere korumaları olmadan 7 · tam 0 FAIL; mutasyon 19 / 19 (brifin 8
  sınıfı + tasarım mutantları; hepsi açık FAIL, 0 yalnız-betik-hatası, sha doğrulamalı bayt-aynı geri koyma; M06 bitmiş
  board'da dondurma ve M14 gizlilik işleyicileri yalnız kaynak sözleşmesiyle — M06 sertleştirmeden sonra davranışsal
  eşdeğer, M14'ün davranışsal varyantı masaüstünde gerçek tarayıcı açardı); 8 mercekli salt-okunur inceleme (4 ajan)
  BLOCKER / HIGH / MEDIUM 0 — LOW / NIT sertleştirmesi `fd4f6e6` / `be44ca4`; kontrollü tam masaüstü kapısı (`be44ca4`)
  50 / 50 temiz — 6228 kontrol, 0 FAIL, 0 SCRIPT ERROR, bot 2 / 2, sahibin kaydı bayt-aynı; Samsung A36: **GEÇTİ**
  (2026-10-05; QA APK `be44ca4`'ten, sha `11c947ec…`, `verify_apk` PASS; yalnız `com.obappstudio.squishymerge.qa`,
  Google örnek kimlikleri; RUNBOOK §0–§6). **1a** Büyütücü dönüşümü sırasında uygulama içi GUI dişli dokunuşu Ayarlar'ı
  açtı (board donuk), round Ayarlar açıkken bitti: Ayarlar bitiş işleyicisinde kapandı (kapanış 1, FINISH kaydından
  önce), menü dondurması bırakıldı, sonuç 0,79 sn sonra tek başına; sonuçta iki gerçek GERİ yok sayıldı (görüntü: yalnız
  sonuç kartı). **1b** gerçek adb dişli dokunuşu canlı round'da Ayarlar'ı açtı ve board'u dondurdu; dar dikişle
  (`GameBoard._finish`) bitiş → aynı sonuç. **2a** bitişten 285 ms sonra uygulama içi GUI dişli basışı dişliye ulaştı,
  Ayarlar açılmadı, board donmadı; **2b** GERÇEK adb dokunuşu bitişten 233 ms sonra dişliye ulaştı (`finalized=true`,
  sonuç henüz yok), Ayarlar açılmadı, sonuç 0,80 sn'de tek başına. **3** canlı round'da gerçek dişli → Ayarlar (board
  donuk), gerçek GERİ kapattı (kapanış 1, mola açılmadı, board çözüldü), ardından gerçek tahta dokunuşu tam 1 bırakış.
  **4** meydan okuma aynı karede Ayarlar açıkken kazanıldı → Ayarlar bitişte kapandı, CHALLENGE_WIN 0,77 sn'de tek
  başına, +20 bir kez (görüntü), sonuç düğmesine gerçek dokunuş → Ana Sayfa; ertesi QA gününde (uygulamanın gün kancası
  `t47_clock`; cihaz saati değişmedi) beklemede GUI dişli reddedildi, +20 bir kez. **5** TASK/049 (dönüşüm sırasında
  Android GERİ yoluyla mola → bitişte eylemsiz kapandı, sonuç tek başına) ve TASK/050 (meydan okuma molada aynı karede
  kazanıldı → mola kapandı, CHALLENGE_WIN tek başına, +20) korunuyor. Kapı boyunca gerçek dokunuş 5 / 5 (yabancı girdi
  yok); logcat: 1 QA süreci, 0 SCRIPT ERROR / çökme / ANR / Godot hatası, yalnız Google örnek yayıncısı; QA kaldırıldı,
  üretim paketi hiç kurulmadı, `com.example` dokunulmadı, gezinme kipi / otomatik saat / saat değişmedi; yalnız bu
  oturumun başlattığı adb daemon'u durduruldu.

### 4.34 Koleksiyon basılı dokunuş + Android GERİ (TASK/054)

> **✅ TAMAM, main'de (COMPLETE + MAIN)** — owner onayıyla ff-only `6a4a2b2 → 88c8570` (2026-10-05; merge commit / rebase
> / squash / cherry-pick / force push yok; dal `task/054-collection-hold-android-back` duruyor, son incelenen HEAD
> `88c8570`). Zincir (main `6a4a2b2`'den, 9 commit): `e49293e` düzeltme · `ef08df1` + `6322101` test · `84770b3`
> inceleme sertleştirmesi · `3d4cb4a` + `158022e` test (A36 ve mutasyondan geçen üretim adayı `158022e`) · `a5b3e35`
> doküman / A36 kaydı · `db5542f` yalnız test (`age_gate_test` tarih fikstürü deterministik; son tam masaüstü kapısından
> geçen test adayı — üretim kodu `158022e` ile bayt-aynı) · `88c8570` doküman (son kapı; yalnız doküman). Aşağıdaki
> doğrulamanın tamamı entegrasyondan ÖNCE tamamlandı; entegrasyon ve doküman eşitlemesi sırasında hiçbir test / mutasyon
> / A36 / Godot / derleme kapısı yeniden koşulmadı. Eski açık madde (4) — Koleksiyon basılı dokunuş + Android GERİ bayat
> bırakış sorunu — FIXED + MAIN (KAPANDI); o tarihte AÇIK kalan tam 2 madde: (5) genel GUI ACTION_CANCEL *(→ TASK/055
> ile kapatıldı — main'de `e0c1a71`, §4.35)*, (6) T5 hedef kartı kırpması `Büyük Dumpl…` (PROJECT_CONTEXT → Next
> action) *(→ TASK/056 ile kapatıldı — main'de `ee2778a`, §4.36)*. TASK/055 o tarihte tanımlanmamıştı.

- **Hata (önceden var olan, eski açık madde (4) — FIXED + MAIN):** Godot 4.6.3 basılı bir düğmenin fare odağını
  düşürürken — düğme gizlenince (`Viewport::_gui_hide_control`: Android GERİ, sekme değişimi, detay kapanışı) ya da
  pencere odağı gidince (`NOTIFICATION_WM_WINDOW_FOCUS_OUT`: Android onPause) — ona iç aygıtlı (`DEVICE_ID_INTERNAL`)
  sentetik bir bırakış yollar; son girdi işlenmemişse (cihazda GERİ tuşunun kendisi — 4.6.3 GERİ'yi işlenmeyen bir
  `Key::BACK` olayı olarak da verir —, bir ses tuşu; masaüstünde parmak titremesi) BaseButton bunu `pressed` sayar.
  BaseButton ACTION_CANCEL bırakışını da `pressed` sayar (iptal bayrağına bakmaz); paylaşılan `UiKit.attach_dim_close`
  de iptali ayırt etmez. Koleksiyon'un işleyicileri dokunuşun sahibine bakmıyordu: gizli albümde detay açılıyor (yeniden
  açılışta ekranda bekliyor, ilk taze dokunuşu yutuyor, Ana Sayfa'nın otomatik günlük penceresini bastırıyor), kapanan
  detayın VİTRİNE EKLE / VİTRİNDEN ÇIKAR'ı kayda yazıyor, MAĞAZAYA GİT / üst çubuk "+" GERİ'den sonra Mağaza'ya, üst
  çubuk geri ikinci kez Ana Sayfa'ya gidiyordu; bırakış düşünce (son girdi işlenmiş) BaseButton'ın
  `pressed_down_with_focus`'u asılı kalıyor, sonraki basış button_down (dokunuş sesi / basış ölçeği) yaymıyordu. Faz A
  izlemesi + düzeltmesiz `6a4a2b2`'de deterministik yeniden üretim (gerçek Main, gerçek parmak olayları: kart / birincil
  / kilitli birincil / ikincil / üst çubuk + GERİ, sekme değişimi, ACTION_CANCEL, olay yokken asılı basış); final suite
  tabanda 59 / 95 FAIL, 0 SCRIPT ERROR.
- **Düzeltme (yalnız `scripts/ui/collection_screen.gd`; Koleksiyon-yerel en küçük sahiplik düzeltmesi):** pozitif
  dokunuş sahipliği — her Koleksiyon düğmesi (20 albüm kartı, üst çubuk geri / "+", detay birincil / ikincil / X, 3
  değiştirme kutusu) `_own_gesture` ile bağlı: `gui_input` basışın gerçek, iptal edilmemiş sol bırakışını kaydeder (iç
  aygıtlı sentetik bırakış bu sinyali yaymaz; gerçek olay BaseButton'dan önce gelir), button_down / button_up basılı
  durumu tutar; eylem yalnız `_gesture_ok`'ta — düğme hâlâ ekranda VE (basış yoksa — kodla yayılan / erişilebilirlik /
  kısayol `pressed`'i — ya da basışın gerçek bırakışı görüldüyse). Basılıyken gizlenen düğmenin basışı
  `visibility_changed`'de (CanvasItem bildirimi Control'ün gizleme işinden ÖNCE yayılır) genel API'yle biter (`disabled`
  true → false: basış durumu sıfırlanır, button_up yayılır, eylem yok); pencere odağı kaybında (`_notification`) hâlâ
  basılı sahipli düğmeler de. Detay X sahiplik korumasından geçer; karartmanın bırakış kaydı paylaşılan
  `attach_dim_close` işleyicisinden ÖNCE bağlanır (Godot sinyal sırası = bağlantı sırası) → ACTION_CANCEL kapatmaz.
  `close_detail` sırası, Main'in GERİ yönlendirmesi / 300 ms yatışması / günlük pencere kapısı, UiKit, ScreenTopBar,
  CollectionSkinCard ve GameBoard DEĞİŞMEDİ; global girdi yutma, global GERİ engeli, zaman aşımı yok.
- **Bilinçli sınırlar / ön koşullar:** sahipli düğmeler bırakışta eylem kipinde, yalnız sol düğme maskeli ve FOCUS_NONE
  (doğrulandı; `ACTION_MODE_BUTTON_PRESS` bir düğme hiç eylem üretmezdi); Android uzun basış = sağ tık ayarı kapalı
  kalmalı (açılırsa motor uzun basışta ACTION_CANCEL üretir, uzun tutuşlar eylemsiz kalır); Android 13+ tek parmak
  iptali (POINTER_UP + FLAG_CANCELED) Godot'ya düz bırakış olarak gelir — motor sınırı; odağa dönüşteki
  `ensure_touch_mouse_raised` bırakışı fare odağı düştüğü için hedefsiz (önceden var olan, zararsız). Masaüstü testinde
  (headless, dokunmatik ekran yok) galeri sürüklemesi gerçek değildir — kaydırmaya geçmiş kart + GERİ kontrolü yalnız
  koruma kontrolüdür.
- **Kapsam dışı gözlemler — ileride TASK/055 için kanıt (o tarihte düzeltilmedi, görev açılmadı — owner kararı; TASK/054
  engeli değil; TASK/055 o tarihte başlamamıştı):** *(→ TASK/055 ile düzeltildi — main'de `e0c1a71`, §4.35; Android 13+
  çok parmaklı tek-işaretçi iptali motor sınırı olarak kalır)* aynı motor sınıfı başka ekranlarda — Profil vitrin yuvası
  (PASS düğme; basılı + GERİ → gizlemedeki bayat tıklama `_on_collectible_requested` ile Koleksiyon detayını açabilir;
  statik çıkarım), Profil dişlisi / KOLEKSİYONA GİT, Harita düğümü (TASK/051 notu); Mağaza SATIN AL ACTION_CANCEL
  bırakışında Hamur harcar (genel GUI ACTION_CANCEL (5)'in parçası); diğer genel GUI ACTION_CANCEL yolları ((5));
  Android 13+ tek parmak iptalinin motor anlamı (yukarıda, bilinçli sınırlar). En temiz yol ileride paylaşılan bir
  sahiplik yardımcısı olur (owner kararı). *(→ TASK/055'te `GestureGuard` olarak geldi; Koleksiyon'un yerel modeliyle
  birleştirme ayrı owner kararı, §4.35.)*
- **Doğrulama (entegrasyondan ÖNCE; entegrasyon ve doküman eşitlemesi sırasında hiçbir kapı yeniden koşulmadı):** yeni
  `tools/collection_hold_back_test` 95 / 95 (A kart + GERİ — olay yok / işlenmeyen olay / titreme; B sekme değişimi; C
  detay birincil / kilitli / ikincil / kutu / X + GERİ; D ACTION_CANCEL — kart, birincil, ikincil, kutu, üst çubuk, X,
  karartma, karartma iptali + GERİ tek gezinme; E iptal + bayat UP, ardından taze dokunuş; F taze dokunuş tam bir kez; G
  öykünülen fare sırası; H çok parmak; I hızlı GERİ; J asılı basış (+ kaydırma koruma kontrolü); K ekonomi; L normal tek
  dokunuşlar; M gezinme; O pencere odağı kaybı; R Ana Sayfa günlük penceresi; S gizli / kapanırken `pressed` — düğmenin
  kendi gizlenme anında, detay id'si hâlâ dururken; P kaynak sözleşmesi; N sahibin kaydı); taban farkı (aynı koşucu, 95
  kontrol): taban `6a4a2b2` 59 · ilk aday `6322101` 16 · koruma yok 21 · pozitif sahiplik yok 16 · gizlenmede basış
  bitirme yok 5 · karartma süzgeci yok 5 · odak kaybında basış bitirme yok 3 · tam 0 FAIL (hepsi 0 SCRIPT ERROR, sha
  doğrulamalı geri koyma); mutasyon 25 / 25 (brifin 11 uygulanabilir sınıfı + tasarım mutantları; hepsi açık FAIL, sha
  doğrulamalı bayt-aynı geri koyma; "işaretçi kimliğini yok say" uygulanamaz — Control yolunda işaretçi kimliği yok,
  fare öykünmesi yalnız 0. parmak; M24 karartma kaydedicisinin sırası yalnız kaynak sözleşmesiyle — öykünme açıkken
  davranışsal eşdeğer; M25 kodla yayılan `pressed` `collection_ui_test`'le); inceleme: 4 salt-okunur ajan / 8 mercek
  (`6322101`) + sertleştirme incelemesi (`158022e`) — BLOCKER / HIGH 0; MEDIUM pencere odağı kaybı ve X / karartma
  iptali `84770b3`'te giderildi, Profil vitrin yuvası ve Mağaza iptali kapsam dışı kaydedildi; LOW / NIT test
  sertleştirmesi; koruma grubu 13 suite 1553 kontrol, hepsi yeşil, sahibin kaydı bayt-aynı (TASK/051, TASK/053,
  Koleksiyon, Profil, Ana Sayfa, Harita, Mağaza, ekonomi, kalıcılık, günlük pencere kapısı); **kontrollü tam masaüstü
  kapısı — son aday `db5542f` (üretim kodu `158022e` ile bayt-aynı): 51 / 51 temiz, 6324 kontrol, 0 FAIL, 0 SCRIPT
  ERROR, bot 2 / 2, sahibin kaydı bayt-aynı; entegre edilen tepe `88c8570` bu adayın üstünde yalnız doküman, üretim
  baytları aynı.** Kapı geçmişi: ilk tam kapı (`158022e`, 51 koşu — 50 temiz, 6321 kontrol, 0 SCRIPT ERROR) önceden var
  olan bir test fikstürü hatasını açığa çıkardı — `age_gate_test` 207 / 209, TASK/054'ten BAĞIMSIZ (aynı gün üretim
  ağacı main `6a4a2b2` iken aynı 2 FAIL; 2026-10-04 23:22'ye kadarki her kapıda 209 / 209). Kök neden (yönlendirilmiş
  kayıtta tanı sondasıyla kanıtlandı): `_test_save_format` eski UNDER_13 bölümü 13. yaş gününü "2026-10-05" seçiyor ve
  "eski tarih hiçbir kopyada kalmaz" diye TÜM kayıt metnini tarıyor; kayıt yüklemesi (`_migrate_missions`) fikstürde
  görev bloğu olmadığı için dönemi `Missions.accepted_day()` → `DailyRewards.day_key()` → cihaz takviminden açıyor,
  sonraki kayıt `missions.day_key` + `missions.week_start_day_key`'i (haftanın pazartesisi) diske yazıyor → 2026-10-05 …
  11 haftasında iki kontrol düşüyordu (yaş mantığı her durumda doğru; enjekte 2026-10-08 de çakışır, 2026-10-12 /
  2026-10-01 çakışmaz). **Yalnız-test düzeltmesi `db5542f`:** kayıt bölümü mevcut `DailyRewards.clock_override`
  kancasını bölümün kendi gününe (`SAVE_DAY` 2026-10-01, haftası 2026-09-28) sabitler, bölüm / test sonunda sıfırlar;
  yeni negatif kontrol yüklemenin açtığı görev döneminin enjekte günden geldiğini ve eski 13. yaş gününün haftasıyla
  çakışmadığını doğrular — sabitleme kaldırılınca (cihaz takvimine düşüş) açık FAIL verir (doğrulandı: 207 / 210, yeni
  kontrol + iki eski kontrol). İddialar, yaş sınırı anlamı (geçiş öncesi / tam geçiş günü / sonrası, saklanan bant +
  sonraki geçiş tarihi, kayıt / yeniden yükleme, aynı kayıtta GÜNLÜK ÖDÜLLER / görev durumu) aynen; `age_gate_test` 210
  / 210, ilgili `age_ad_routing_test` 122 / 122, `age_gate_ui_test` 26 / 26, `missions_test` 136 / 136,
  `daily_rewards_test` 179 / 179. **Samsung A36: GEÇTİ** (2026-10-05; QA APK `158022e`'den, sha `d325537c…`,
  `verify_apk` PASS — sertleştirilmiş aday belirteçleri var, ilk adayınki yok; yalnız `com.obappstudio.squishymerge.qa`,
  Google örnek kimlikleri): **1** basılı kart + gerçek GERİ + bırak 5 / 5 — her koşuda `ALBUM off` ile aynı ms'de basış
  bitti, PRESSED / detay 0, Ana Sayfa; **2** madalyonla yeniden açılış (bayat detay yok) + taze dokunuş tam 1 detay;
  **3** VİTRİNE EKLE basılı + GERİ → vitrin bellek + disk aynı, sonra taze dokunuş tam 1 ekleme; kilitli MAĞAZAYA GİT
  basılı + GERİ → Mağaza'ya gidilmedi; **4** VİTRİNDEN ÇIKAR basılı + hızlı çift GERİ → tek detay kapanışı + tek
  gezinme, vitrin aynı; **5** gerçek `input motionevent CANCEL`: kart (motorun PRESSED'i koruma tarafından reddedildi),
  iptal + bayat UP, ardından taze dokunuş tam 1; karartma ve X iptali detayı kapatmadı; karartma iptali + GERİ tek
  gezinme (Koleksiyon'da kalındı); **6** GERİ zinciri, üst çubuk geri / "+" tam 1 gezinme, X / karartma normal dokunuşu
  tam 1 kapanış. Gate boyunca gerçek dokunuş 28 / 28 (yabancı girdi yok); logcat: 1 QA süreci, 0 SCRIPT ERROR / çökme /
  ANR / Godot hatası, yalnız Google örnek yayıncısı; QA kaldırıldı, üretim paketi hiç kurulmadı, `com.example`
  dokunulmadı, gezinme kipi / otomatik saat / saat değişmedi; yalnız bu oturumun başlattığı adb daemon'u durduruldu.
  Pencere odağı kaybı A36'da sürülmedi (sahibin telefonunda HOME / güç / arama gerektirir) — masaüstü O bölümü. A36
  yeniden koşulmadı: son sertleştirme (`db5542f`) yalnız test / belge değiştirdi, üretim ağacı `158022e` ile bayt-aynı —
  üretim mutasyonu 25 / 25 de bu yüzden geçerli, yeniden koşulmadı.

### 4.35 Genel GUI ACTION_CANCEL sertleştirmesi (TASK/055)

> **✅ TAMAM, main'de (COMPLETE + MAIN)** — owner onayıyla ff-only `60f8b71 → e0c1a71` (2026-10-06; merge commit / rebase
> / squash / cherry-pick / force push yok; dal `task/055-gui-action-cancel` duruyor, son incelenen HEAD `e0c1a71`).
> Zincir (main `60f8b71`'den, 5 commit): `1db02b6` düzeltme · `855d49a` test · `287781f` inceleme sertleştirmesi ·
> `7671882` gereksiz dal temizliği (masaüstü kapılarından ve Samsung A36'dan geçen son üretim / test adayı) · `e0c1a71`
> doküman / A36 kaydı (yalnız doküman; test edilen adayın üstünde). Aşağıdaki doğrulamanın tamamı entegrasyondan ÖNCE
> tamamlandı; entegrasyon ve doküman eşitlemesi sırasında hiçbir odak test / mutasyon / inceleme / masaüstü / A36 /
> Godot / derleme kapısı yeniden koşulmadı. Kabul edilen son kanıt: odak `gui_action_cancel_test` 148 / 148, 0 SCRIPT
> ERROR; taban farkı `60f8b71` 100 FAIL → son aday 0 FAIL; mutasyon 45 / 45 uygulanabilir mutant açık FAIL ile öldü (M39
> eşdeğer, hedeflediği gereksiz kod son adaydan önce kaldırıldı); inceleme 5 salt-okunur inceleyici / 10 mercek — 0
> BLOCKER / 0 HIGH; kontrollü tam masaüstü kapısı (`7671882`) 52 / 52 temiz, 6472 kontrol, 0 FAIL, 0 SCRIPT ERROR, bot 2
> / 2, sahibin kaydı bayt-aynı; Samsung A36 (`7671882` QA APK'sı) GEÇTİ — iptal edilen Mağaza SATIN AL'da Hamur
> harcaması 0. Eski açık madde (5) — genel GUI ACTION_CANCEL — FIXED + MAIN by TASK/055 (KAPANDI); AÇIK kalan tek ürün
> maddesi (6) T5 hedef kartı kırpması `Büyük Dumpl…` (PROJECT_CONTEXT → Next action). TASK/056 tanımlanmadı, başlamadı.
> *(Sonra: (6) TASK/056 ile kapatıldı — FIXED + MAIN, main'de `ee2778a`, §4.36.)*

- **Kök neden (Faz A motor sondası, Godot 4.6.3):** BaseButton Android ACTION_CANCEL bırakışını tıklama sayar
  (`canceled`'a bakmaz); basılı bir düğme gizlenince ya da pencere odağı gidince Viewport ona iç aygıtlı bir bırakış
  yollar — son girdi işlenmemişse (cihazda GERİ tuşunun kendi olayı, bir ses tuşu) bu da tıklama olur, işlenmişse basış
  asılı kalır (sonraki basış button_down yaymaz). Paylaşılan `UiKit.attach_dim_close` iptal edilen bırakışta da
  kapatıyordu, Mağaza onay karartması öykünülen fare BASIŞINDA kapatıyordu. Uygulamanın `pressed` işleyicilerinde
  pozitif dokunuş sahipliği yoktu. Denetimin vardığı gerçek: Godot 4.6.3'ün yerel BaseButton iptal anlamı denetlenen
  dokunma yolları için YETERLİ DEĞİL — hiçbir hazır Button iptale karşı güvenli değil; "güvenli" yalnız sonuçsuz
  kontroller için geçerli. Bu yüzden kontroller körlemesine değil EYLEM SONUCUNA göre sınıflandırıldı.
- **Taban yeniden üretimi (değiştirilmemiş `60f8b71`; gerçek Main, yönlendirilmiş kayıt, gerçek parmak olayları):** 32
  vakanın 29'unda geçersiz dokunuş eylem üretti: **Mağaza onay SATIN AL iptali Hamur 900 → 720, Büyütücü 2 → 3 (bellek +
  disk)**; refill "Hamur ile" 900 → 800; güç yuvası (Sarsıntı) stok 1 → 0; günlük AÇ ücretsiz sandığı talep etti (iptal
  ve basılı + GERİ); günlük REKLAM İZLE ve devam DEVAM ET ödüllü reklam istedi; yaş ONAYLA bandı ADULT → TEEN yazdı;
  MEYDAN OKUMA BAŞLA ve Harita düğümü round başlattı (düğüm basılı + GERİ'de başlatma `_show_tab(0)`'ın görünürlük
  yayılımı içinde yeniden girdi); Mola Yeniden Başlat round'u yeniden başlattı; tutorial ATLA onboarding'i tamamladı;
  Ayarlar ses tercihi ve unvan satırı kayda yazdı; Profil vitrin yuvası / KOLEKSİYONA GİT / dişli ve Ana Sayfa OYNA /
  madalyonları gezindi ya da pencere açtı; Görevler karartması iptal + aynı jestin GERİ'si (kenar geri kaydırması)
  uygulamadan çıkardı. Güvenli çıkan iki vaka (onay SATIN AL basılı + GERİ, unvan satırı basılı + GERİ) yalnız GERİ
  yolunu işleyici sırası koruyordu.
- **Denetim matrisi ve korunan kapsam (3 salt-okunur denetim ajanı + okuma + sondalar):** ekonomi (Mağaza onay SATIN AL,
  refill Hamur), ödül / reklam isteği (günlük AÇ, günlük REKLAM İZLE ×2, refill reklam, devam DEVAM ET), seviye / round
  (Harita düğümleri, Sonsuz, MEYDAN OKUMA BAŞLA, sonuç birincil / ikincil, tutorial ATLA / CTA, mola Yeniden Başlat /
  Ana Menü), kalıcı yazma (Ayarlar ses / titreşim, unvan satırı, yaş ONAYLA), gezinme / pencere (Ana Sayfa avatar, Hamur
  +, 4 madalyon, GÖREVLER, MEYDAN OKUMA, OYNA, seviye hapı; Profil vitrin ×3, unvan, TÜM BAŞARIMLAR, KOLEKSİYONA GİT;
  Mağaza kart SATIN AL ×24, günlük AÇ; Ayarlar gizlilik / politika / yaş Güncelle; sandık OYNA), HUD / güç kontrolleri
  (geri / dişli / çıkış, güç yuvaları ×4), karartma ve kapatma kontrolleri (12 karartma; X / Vazgeç / KAPAT / TAMAM /
  mola DEVAM) ve paylaşılan üst çubuğun Profil / Harita / Mağaza tüketici röleleri — 21 UI dosyası, çalışma anında 115
  düğme örneği, hepsi tek tek açık bağlamayla (fabrika / global sarmalayıcı YOK). **Bilinçli dokunulmayan:** TASK/054
  Koleksiyon kendi korumasını taşır (taşınmadı); `ScreenTopBar` / Main gezinmesi + 300 ms yatışma / GameBoard DEĞİŞMEDİ;
  gerçekten sonuçsuz kontroller doğal kaldı (Ayarlar Göster/Gizle, yaş ekranı sihirbaz adımları — kayıt yalnız korunan
  ONAYLA'da —, günlük DEVAM, kozmetik iç bağlantılar). Fiyat / ödül / reklam politikası değişmedi.
- **Düzeltme — `GestureGuard` sahiplik modeli** (`scripts/ui/gesture_guard.gd`; açık API: `on_pressed(button, action)`,
  `own(button)`, `allows(button)`, `invalidate(button)`; düğmeye iç çocuk düğüm, düğme başına durum): geçersiz basış
  eylemden ÖNCE biter — iptal edilen sol bırakışta basış `gui_input` sinyalinde, BaseButton'ın kendi işleyişinden önce
  bitirilir, `pressed` / `toggled` hiç doğmaz; gizleme, pencere odağı kaybı ve Android GERİ isteği sahipliği
  geçersizleştirir (basış genel API'yle, `disabled` true → false); eylem yalnız düğme ekrandayken ve (işaretçi basışı
  yoksa ya da basışın gerçek, iptal edilmemiş bırakışı görüldüyse) çalışır — klavye / erişilebilirlik / kodla
  etkinleştirme serbest kalır (yalnız işaretçi basışı sahiplenilir); karartmalar iptal edilen bırakışı yok sayar (Mağaza
  onayı da paylaşılan bırakış kapanışına geçti); Ayarlar anahtarları reddedilen dokunuştan sonra kayıttaki değere döner
  (UiToggle topuzu anahtarın şu anki durumuna kayar, `set_on` süren topuz animasyonunu durdurur). Global girdi yutma,
  Input değişikliği, zaman aşımı yok.
- **Bilinçli davranış değişiklikleri — OWNER KABUL ETTİ (2026-10-06; açık madde değil):** (1) GERİ / eşdeğer gezinme
  geçersizleştirmesi, GERİ o ekranı kapatmasa bile süren korunan bir basışı iptal eder (sonuç ekranı, devam teklifi,
  zorunlu yaş ekranı, tutorial GERİ onayı, mola açılırken HUD / güç yuvası) — gezinme sınırını aşan bir basış sonradan
  eyleme dönüşmez; eski bayat basış davranışı geri getirilmez. (2) Mağaza satın alma onayı karartması dokunuş başında
  değil geçerli BIRAKIŞTA kapanır — ACTION_CANCEL'ın jesti iptal edebilmesi için gerekli; bırakışta kapanma korunur.
- **Bilinçli sınırlar / ön koşullar:** Android 13+'ta birden çok parmaklı bir jestte tek işaretçinin iptali (POINTER_UP
  + FLAG_CANCELED — avuç / kavrama reddi) Godot 4.6.3'e düz bırakış olarak gelir; o işaretçi fare öykünen ilk parmaksa
  ayırt edilemez (motor sınırı; tek parmak ACTION_CANCEL'ı — kenar geri kaydırması, sistem jesti — her zaman `canceled`
  taşır). Android uzun basış = sağ tık ve pan / ölçek jestleri KAPALI kalmalı; `own` + `allows` rölesi `allows`'u
  `pressed` yayımı içinde okumalı. Sonuçsuz doğal düğmeler iptalde yine çalışabilir (yaş seçimi "Geri" kenar geri
  kaydırmasında yeniden girişte iki adım atabilir — kayıt yok). Motor gerçeği (sonda): ağaçtan çıkan basılı düğmeye
  motor button_up yayar — yardımcıya ayrıca bir dal gerekmez (inceleme kaynaklı gereksiz dal `7671882`'de kaldırıldı).
- **Kapsam dışı gözlemler (önceden var olan; düzeltilmedi, görev açılmadı — owner kararı):** refill ödüllü istek
  bekliyorken "Hamur ile" alım iki kez sonuçlanabilir (dar zaman aralığı); öne dönüşte otomatik günlük pencere açık
  Mağaza onayının üstüne açılabilir (yalnız bakiye metni bayatlar); bitiş anında basılı tutulan HUD dişlisi devam
  teklifi açıldıktan sonra kalkarsa Ayarlar teklifin üstüne açılır (iptal değil, gerçek bırakış); Koleksiyon'un yerel
  sahiplik modeli ile `GestureGuard` ayrı (ileride birleştirme owner kararı).
- **Doğrulama (masaüstü):** yeni `tools/gui_action_cancel_test` **148 / 148** (A Profil vitrini · B dişli / üst çubuk /
  unvan · C Harita · D Mağaza SATIN AL — kesin Hamur, iptal / odak kaybı / GERİ 0 harcama, kayıt dosyası bayt-aynı,
  geçerli dokunuş tam bir harcama, yinelenen fare + dokunuş bırakışı ikinci harcama yok · E iptal + bayat UP matrisi · F
  gizleme / GERİ / sekme · G odak kaybı · H asılı basış · I doğal düğme · J klavye / kod / erişilebilirlik · K çok
  parmak · L ekonomi kaydı · M gezinme · R çalışma anı sahiplik taraması · P kaynak sözleşmesi · N sahibin kaydı); taban
  farkı (aynı suite, `287781f`): **taban `60f8b71` 100 FAIL** (48 OK, 0 SCRIPT ERROR) · karartma süzgeci yok 5 · iptalde
  basış bitirme yok 56 · gizlemede basış bitirme yok 12 · odak / GERİ geçersizleştirmesi yok 3 · `allows` kapısı yok 21
  · **tam aday 0**; mutasyon **45 / 45 uygulanabilir** mutant açık FAIL ile öldü (sha doğrulamalı bayt-aynı geri koyma;
  M39 "ağaçtan çıkışta sahiplik sıfırlaması" EŞDEĞER çıktı — motor button_up yayıyor — ve hedeflediği gereksiz kod final
  adaydan önce kaldırıldı; `7671882`'de M13 / M18 / M19 yeniden koşuldu); inceleme 5 salt-okunur inceleyici / 10 mercek
  — 0 BLOCKER / 0 HIGH, tek MEDIUM (tabanda boşa geçen üç test) giderildi; koruma: TASK/053 suite'inin pozitif kontrolü
  yeni anlama güncellendi (basış gizlemede sentetik bırakıştan önce biter — davranış kontrolleri aynen), TASK/054
  suite'i yalnız ifade; **kontrollü tam masaüstü kapısı (`7671882`): 52 / 52 temiz, 6472 kontrol, 0 FAIL, 0 SCRIPT
  ERROR, bot 2 / 2 kazandı, sahibin kaydı bayt-aynı.**
- **Samsung A36: GEÇTİ** (2026-10-06; QA APK `7671882`'den, sha256 `77bf53b9…`, `verify_apk` PASS — yalnız
  `com.obappstudio.squishymerge.qa`, Google örnek kimlikleri, TASK/055 belirteçleri paketli). Ön kontrol: aygıt yetkili,
  uyanık, kilitsiz, arama / perde / üst afiş yok, ön plan başlatıcı; kurulu yalnız `com.example.squishymerge`; gezinme
  kipi 0, otomatik saat / saat dilimi 1, cihaz saati masaüstüyle eş. **1 Mağaza SATIN AL (zorunlu):** onay gerçek kart
  dokunuşuyla açıldı; onay SATIN AL'a gerçek DOWN + `input motionevent CANCEL` → basış iptal edilen bırakışın içinde
  bitti, PRESSED 0, onay açık, Hamur 335 / disk 335, Büyütücü 1 / disk 1 (değişim 0); iptal + bayat UP → bayat UP hiçbir
  kontrole ulaşmadı, değişim 0; basılı + gerçek GERİ + bırak → onay GERİ ile kapandı, PRESSED 0, Mağaza'da kalındı,
  değişim 0; karartmada gerçek iptal → onay açık kaldı; **taze geçerli SATIN AL → PRESSED tam 1, Hamur 335 → 155 (−180,
  disk 155), Büyütücü 1 → 2 (disk 2), onay kapandı — tek harcama, çift harcama yok.** **2 Profil:** vitrin yuvası
  basılı + gerçek GERİ + bırak → Ana Sayfa, basış gizlemede bitti, PRESSED / Koleksiyon gezinmesi / detay 0, vitrin
  aynı; yuva ve dişlide gerçek iptal → eylem 0; dişli basılı + GERİ → Ana Sayfa, Ayarlar açılmadı; taze yuva dokunuşu →
  tam 1 Koleksiyon gezinmesi + rare_02 detayı. **3 Harita:** düğümde gerçek iptal → seviye 0; düğüm basılı + GERİ → Ana
  Sayfa, seviye 0; "+" basılı + GERİ → Ana Sayfa görünür (boş ekran yok), Mağaza'ya gidilmedi; taze düğüm dokunuşu → tam
  1 Seviye 1 başlangıcı. **4 Normal kontroller:** Profil dişlisi → Ayarlar tam 1; Göster/Gizle (doğal) açtı / kapattı;
  Kapat → Ayarlar tam 1 kapandı; Ana Sayfa OYNA → Harita tam 1; fiziksel klavye / erişilebilirlik etkinleştirmesi N/A —
  masaüstü J. **5 TASK/054 koruması:** Koleksiyon kartı basılı + GERİ → Ana Sayfa, PRESSED / detay 0; madalyonla yeniden
  açılış bayat detaysız; taze kart dokunuşu → tam 1 detay. **6 TASK/053 dumanı:** dişliyle açılan Ayarlar gerçek GERİ
  ile kapandı, Profil'de kalındı (Android'in çift GERİ teslimi ikinci gezinme yapmadı); hemen ardından normal etkileşim
  korundu (Ana Sayfa OYNA → Harita tam 1). Fiziksel odak kaybı: **N/A — COVERED BY DESKTOP DETERMINISTIC TEST** (sahibin
  telefonunda HOME / güç / arama kullanılmadı). Kapı boyunca gerçek dokunuş 25 / 25 (yabancı girdi yok); logcat: 1 QA
  süreci, 0 SCRIPT ERROR / çökme / ANR / Godot hatası, yalnız Google örnek yayıncısı; QA kaldırıldı, üretim paketi hiç
  kurulmadı, `com.example` meta verisi aynı (0.8.5), gezinme kipi / otomatik saat / otomatik saat dilimi / saat
  değişmedi; yalnız bu oturumun başlattığı adb daemon'u durduruldu.
- **Bütünlük:** sahibin kayıt ailesi bayt-aynı (`deb7ff6f…`); `default_bus_layout.tres`, `project.godot`,
  `export_presets.cfg` içerikleri bayt-aynı (yeni sınıfın kaydı için gereken headless import ve QA dışa aktarımının
  bayt-aynı geri koyması yalnız değişiklik zamanlarını tazeledi; hiçbiri stage / revert / restore / stash edilmedi);
  `_visual_source/` ve `OWNER_WORKING_PROFILE.md` değişmedi. Bir arka plan koşucusu durdurulduğunda alt süreçleri öksüz
  kalıp ikinci koşuyla çakıştı — tüm süreçler kapatıldı, ağaç HEAD'e döndürüldü, o koşuların sonuçları atılıp temiz koşu
  tekrarlandı.

### 4.36 HUD hedef kartı ad sığdırma — T5 `Büyük Dumpl…` (TASK/056)

> **✅ TAMAM, main'de (COMPLETE + MAIN)** — owner onayıyla ff-only `a8bf454 → ee2778a` (2026-10-06; merge commit /
> rebase / squash / cherry-pick / force push yok; dal `task/056-t5-target-card-truncation` duruyor, son incelenen HEAD
> `ee2778a`).
> Zincir (main `a8bf454`'ten, 4 commit): `721b97a` düzeltme · `c17fa4c` test · `0c0dc09` inceleme sertleştirmesi
> (masaüstü + Samsung A36 kapılarından geçen son üretim / test adayı) · `ee2778a` doküman / A36 kaydı (yalnız doküman;
> test edilen adayın üstünde). Üretim farkı yalnız `scripts/ui/gameplay_hud.gd`. Aşağıdaki doğrulamanın tamamı
> entegrasyondan ÖNCE tamamlandı; entegrasyon ve doküman eşitlemesi sırasında hiçbir odak test / mutasyon / inceleme /
> masaüstü / A36 / Godot / derleme kapısı yeniden koşulmadı. Kabul edilen son kanıt: odak `target_card_text_fit_test`
> 328 / 328, 0 SCRIPT ERROR; taban farkı `a8bf454` 141 FAIL → son aday 0 FAIL; mutasyon 20 varyant — 19 / 19
> uygulanabilir mutant açık FAIL ile öldü, 1 eşdeğer (satır yüksekliği yuvarlaması); inceleme 4 salt-okunur inceleyici
> / 8 mercek — 0 BLOCKER / 0 HIGH; kontrollü tam masaüstü kapısı (`0c0dc09`) 53 / 53 temiz, 6800 kontrol, 0 FAIL, 0
> SCRIPT ERROR, bot 2 / 2, sahibin kaydı bayt-aynı; Samsung A36 (`0c0dc09` QA APK'sı) GEÇTİ — Türkçe T5 Level 3'te ve
> meydan okumada tam (ürün dili Türkçe; EN / RTL yalnız-test vekilleri). Eski açık madde (6) — HUD hedef kartı T5
> kırpması `Büyük Dumpl…` (§4.27 (d)) — FIXED + MAIN by TASK/056 (KAPANDI); bilinen, izlenen açık ürün maddesi: 0
> (ürünün hatasız olduğu iddia edilmez). TASK/057 oluşturulmadı *(o günkü durum — sonra TASK/057 §4.37, tamam + main'de)*.

- **Kanonik metin ve dil:** T5 = `Büyük Dumpling` (`TierConfig.TIERS`, GAME_DESIGN §2 — değişmedi). Ürün tek dilli
  Türkçe: projede çeviri kaynağı / yerel ayarı yok (`project.godot`'ta `internationalization` bölümü yok;
  `missions_ui_test` bunu doğrular) — İngilizce / Arapça kopya ve RTL yerelleştirmesi YOK.
- **Taban yeniden üretimi (değiştirilmemiş `a8bf454`; gerçek GameBoard + production `GameplayHud`, TextServer ölçümü +
  pencereli çekimler):** hedef kartı (`goal_plate`, `_build_row2` içinde satır içi kurulur, başka yerde yeniden
  kullanılmaz; normal level, meydan okuma, sonsuz ve tutorial board aynı kartı kullanır) `GameplayLayout.compute`'tan
  300 px — tuval `canvas_items` + `expand` (720x1280 taban) olduğundan genişlik hiçbir telefonda 720'nin altına inmez,
  kart her telefonda (720x1280 / 1560 + üst pay 61 / 1600 / 1440 / banner 100) aynı, daha geniş tuvalde yalnız genişler.
  Satır: level rozeti 60 (+10) | sütun 192: HEDEF başlığı → ad satırı = portre 38 (+6) + **ad etiketi** (`LabelSection`
  Baloo2-Bold, 20 px, `clip_text` + `OVERRUN_TRIM_ELLIPSIS`, autowrap kapalı, EXPAND_FILL) + 6 + `goal_extra` ("+N
  skor", 12 px; boşken de görünür, 1 px) → çubuk satırı. Ad etiketi **141 px** (meydan okumada BUGÜN rozeti 65 px →
  136; L08 / L10'da skor hedefi 67 px → 75; sonsuzda 173). 20 px doğal genişlikler: T1 Mini Dumpling 129 · T2 Küçük
  Dumpling 147 · T3 Dumpling 87 · T4 Şişkin Dumpling 145 · T5 Büyük Dumpling 148 · T6 Dev Dumpling 126 · T7 Jumbo
  Dumpling 151 · T8 Dumpling Kralı 133. Çizilen (çekimle doğrulandı): L03 `Büyük Dumpli…`, meydan okuma T5 `Büyük
  Dumpl…` (bildirilen dize), L01 / L02 `Şişkin Dumpli…` (ilk level ve tutorial), L06 / L07 `Jumbo Dumpli…`, **L08
  `Jumbo` ve L10 `Dumpli` üç noktasız** (Godot 6 karakterden azı kalınca üç nokta eklemez — sessiz kırpma); L04 / L05
  (T6), L09 (T8) ve sonsuz sığıyordu; T2 hiçbir levelin hedefi değil. T5 tek değildi — yalnız fark edilen belirtiydi
  (bildirim meydan okumada, 136 px'te).
- **Kök neden:** (1) **kardeşin yer ayırması** — skor hedefi `goal_extra` HUD v2'de çubuğun içindeydi; HUD v3
  (`29504e5`) onu ad satırına taşıdı, "hedef adı ile yer için yarışmaz" yorumu bayat kaldı: boşken bile görünür etiket 1
  px + 6 px ayraç, doluyken 73 px alıyordu (L08 / L10 adı 75 px); (2) **sabit punto, sığdırma yok** — HUD v4
  (`150cc9f`) adı 22 → 20 px yaptı ama sığdırma eklenmedi; ad satırının en fazlası 148 px (meydan okumada 143), T7 (151)
  ve meydan okuma T5'i (148) 20 px'te hiçbir kardeş düzenlemesiyle sığmaz. Kart, rozet, portre ve `GameplayLayout`
  (tepsiler 78 px dokunma hedefli slotlarla sabit) doğru; sorun etiketin kendi sözleşmesindeydi.
- **Düzeltme (yalnız `scripts/ui/gameplay_hud.gd`):** skor hedefi HEDEF / REKOR başlık satırının sağ ucuna taşındı (yeni
  `caption_row`: başlık EXPAND_FILL solda, "+N skor" 12 px sağda; ad satırı = portre + ad). `set_goal_name(text)` (tier
  adı ve sonsuz rekor) + `_fit_goal_name()`: punto her seferinde `GOAL_NAME_FONT_SIZE` 20'den başlar; etiketin ÇİZDİĞİ
  metnin (`atr(text)` — ileride çeviri olursa çevrilmiş ad) `Font.get_string_size` genişliği + `GOAL_NAME_FIT_SLACK` 2
  px, etiketin kapsayıcıdan aldığı tam sayı genişliğe (Label'ın kendi hesabı) sığana kadar 1 px düşer;
  `GOAL_NAME_MIN_FONT_SIZE` 16'nın altına inmez (okunur taban: temanın en küçük Baloo stili `LabelBadge` 16; HUD
  başlıkları 13 / 12 px'ten büyük); tabanda da sığmayan metin için etiketin mevcut kırpma + üç noktası sınırlı son
  çaredir (taşma / çakışma yok). Yeniden sığdırma: metin yazılınca, `resized` (ilk yerleşim, BUGÜN / SONSUZ rozeti,
  tuval genişliği) ve `NOTIFICATION_TRANSLATION_CHANGED` (dil değişince Label yeniden çevirir ama boyutu değişmez);
  kapsayıcı etikete 1 px giriş genişliğinden fazlasını vermeden dokunmaz (geçici 16 px yok); ad satırı yüksekliği taban
  puntonun satır yüksekliğinde (`ceilf(font.get_height(20))` = 33) sabit. Sonuç: T2 / T5 / T7 19 px, diğerleri 20 px;
  meydan okuma T5 19 px; hepsi tam. Kopya, tier adları, level hedefleri, kart / rozet / portre / çubuk geometrisi, girdi
  (tüm kart `MOUSE_FILTER_IGNORE`) ve TASK/055 `GestureGuard` HUD düğmeleri DEĞİŞMEDİ. Tier'a özel istisna, sabit
  genişlik, kısaltılmış kopya ya da genel punto küçültme YOK.
- **TR / EN / AR:** TR — tek ürün dili: sekiz kanonik ad, on level, meydan okuma, sonsuz ve tutorial tam. EN — ürün dili
  değil (N/A); vekil: Godot'nun GERÇEK çeviri hattından yalnız-test kataloğu (`en`: Dev Dumpling → Gigantic Dumpling,
  Büyük Dumpling → Big Dumpling) — etiket çevrilmiş adı çizer, dil değişince ad yeniden sığdırılır (`Gigantic Dumpling`
  17 px, tam), katalog kaldırılınca TR'ye döner; ayrıca Latin metin `set_goal_name` yolundan. AR / RTL — ürün
  yerelleştirmesi değil (N/A); vekil: kart `layout_direction = RTL` (yalnız test): aynalı sıra (rozet sağda, portre adın
  sağında, skor hedefi başlığın solunda), kırpma / çakışma yok; üretim yönü zorlamaz (INHERITED / AUTO). Arapça
  şekillendirme ve yedek yazı tipi KANITLANMADI (ürün dili değil).
- **Doğrulama (masaüstü):** yeni `tools/target_card_text_fit_test` **328 / 328** (54'ü `[yapı]` yapısal pozitif kontrol,
  ayrı sayılır; A kanonik T5 L03 + meydan okuma · B T1–T8 + L1–L10, skor hedefinin satırı ve sağ uç konumu · C EN çeviri
  vekili · D RTL vekili · E 720 tuval öncülü, 300 / 148 / 143 / 180 px, 1280 / 1560 + 61 / 1600 / 1440 / banner 100, 960
  tuval · F hiyerarşi geometrisi · G uzun metin: T5'ten uzun, İ/ğ/ö/ç, aşırı uzun → 16 px + üç nokta · H ilk yerleşim,
  sonsuz 0 / 123 456, meydan okuma T6, tutorial board, yeniden `set_level` · I sahibin kaydı). Kanıt kaynak metni değil:
  Godot 4.6.3 `Label::_shape()` aynen yeniden koşulur (çizilen metin `atr` / büyük harf / görünür karakter + U+200B,
  etiketin dili ve yönü, tam sayı genişlik, etiketin kendi taşma bayrakları). **Taban farkı:** düzeltmesiz `a8bf454` 141
  FAIL / 0 SCRIPT ERROR (L03 `Büyük Dumpli…`, meydan okuma `Büyük Dumpl…`, L08 `Jumbo`, L10 `Dumpli`, …; pozitif
  kontroller geçti) → son aday 0 FAIL. **Mutasyon:** 20 üretim mutantı — 19 / 19 uygulanabilir mutant açık FAIL ile
  öldü, 0 SCRIPT ERROR (sığdırmasız, yalnız yeniden boyutta ya da yalnız yazınca sığdıran, paysız, tabansız, yükseklik
  sabitsiz, genel 19 px, tabandan yeniden başlamayan, gerçek genişliği yok sayan, skor hedefi ad satırına geri, ad
  EXPAND'sız, geniş portre, üç noktasız son çare, ad LTR'ye zorlanmış, başlık satırı sırası, başlık EXPAND'sız,
  yerleşimden önce sığdıran, çevrilmemiş metni ölçen, dil değişiminde sığdırmayan); `m20` (yükseklik `ceilf`'siz)
  EŞDEĞER — Baloo2-Bold 16–20 px yükseklikleri tam sayı (27 / 28 / 30 / 31 / 33). Her geri koyma HEAD ile bayt-aynı
  (sha + `git diff --quiet HEAD`). **İnceleme:** 4 salt-okunur inceleyici / 8 mercek (Godot kapsayıcı / en küçük boyut ·
  tipografi · TR · EN · AR / RTL · dar mobil · bileşen yeniden kullanımı · erişilebilirlik) — 0 BLOCKER / 0 HIGH; 1
  MEDIUM (testin yeniden koşusu üretimle aynı varsayımları paylaşıyordu — Label'ın kendi şekillendirmesi aynen koşulacak
  şekilde düzeltildi) ve LOW'lar `0c0dc09`'da kapandı (ilk yerleşimde geçici 16 px, çevrilmiş metni ölçme + dil
  değişiminde yeniden sığdırma, tuval öncülü ve sabit genişlikler, LTR skor hedefi konumu + mutantı, yapısal
  kontrollerin ayrı sayımı, çekim aracının varsayılan klasörü); NIT `ceilf` uygulandı. **Kontrollü tam masaüstü kapısı
  (`0c0dc09`): 53 / 53 temiz, 6800 kontrol, 0 FAIL, 0 SCRIPT ERROR, bot 2 / 2 (L3, hedef T5), sahibin kaydı
  bayt-aynı.**
- **Görsel kanıt (yerel; `build/` git'e girmez):** pencereli `tools/target_card_shots` (26 durum, tam kare + kart
  kırpması): taban `build/qa_056/shots/base_720x1280/` (03_L03, 12_DC_T5, 01_L01, 06_L06, 08_L08, 10_L10, 25_RTL_T5 …),
  düzeltme `build/qa_056/shots/fix1_720x1280/` ve son aday `build/qa_056/shots/fix2_720x1280/` (kart içi fix1 ile
  piksel-aynı), dar fiziksel pencere `build/qa_056/shots/fix1_540x960/`, A36 ölçeği
  `build/qa_056/shots/fix1_1080x2340/`; L08 yakın plan `build/qa_056/shots/base_720x1280/08_L08_zoom.png` ↔
  `build/qa_056/shots/fix1_720x1280/08_L08_zoom.png`.
- **Samsung A36: GEÇTİ** (2026-10-06; QA APK `0c0dc09`'dan, 104,796,412 B, sha256 `46194b32…`, `verify_apk` PASS —
  yalnız `com.obappstudio.squishymerge.qa`; cihaz saati / tarihi değişmedi, gün Salı = meydan okuma T5). Gerçek
  dokunuşlarla Ana Sayfa → OYNA → Harita → Level 3: `Büyük Dumpling` tam — cihazdaki Label yeniden koşusu 19 px, doğal
  140 / etiket 148 px, trim / üç nokta -1, dil `tr_TR`; Ana Sayfa → MEYDAN OKUMA → BAŞLA: BUGÜN rozetiyle `Büyük
  Dumpling` tam (140 / 143 px). Komşular: L01 `Şişkin Dumpling` 20 px, L04 `Dev Dumpling` 20 px, L08 `Jumbo Dumpling` 19
  px ve başlık satırında "+6 750 skor". EN vekili (yalnız test kataloğu) `Gigantic Dumpling` 17 px tam; kapatınca `Dev
  Dumpling` 20 px, dil `tr_TR`, yüklü katalog 0. RTL vekili (yalnız test) aynalı ve tam. Etkileşim: hedef kartı görüntü
  amaçlı (dokunuş önceki gibi board'a düşer — 1 bırakış, hiçbir pencere açılmadı); HUD dişlisi → Ayarlar tam 1, gerçek
  GERİ → kapandı; HUD geri → mola tam 1, DEVAM ET → kapandı (TASK/055 korunuyor). Girdi hesabı 11 / 11 (yabancı girdi
  yok); logcat (1 QA süreci): 0 SCRIPT ERROR, 0 çökme / ANR, godot E 0, yalnız Google test yayıncı kimliği. Çekimler:
  `build/qa_056-gate/device/A1_T5_L03.png`, `A1b_T5_challenge.png`, `A2_T4_L01.png`, `A2_T6_L04.png`, `A2b_T7_L08.png`,
  `A3_EN_proxy_L04.png`, `A4_RTL_proxy_L03.png` (her biri + `_card.png` kırpması). QA kaldırıldı, üretim paketi hiç
  kurulmadı, `com.example.squishymerge` meta verisi aynı (0.8.5), gezinme kipi 0 / otomatik saat / saat dilimi
  değişmedi, yalnız bu oturumun başlattığı adb daemon'u durduruldu.
- **Kayda geçen, düzeltilmeyen (owner incelemesi; açık ürün maddesi DEĞİL):** (a) L08 / L10'da başlık satırına taşınan
  "+N skor" yazısı, skor plakasının sağ alt köşesindeki 10 px altın pırıltının ~4,5 px altında (çakışma yok; görsel
  yakınlık — A36 çekimi `A2b_T7_L08_card.png`); istenirse pırıltı 6 px yukarı alınabilir (kart dışı, owner kararı). (b)
  Skor hedefi 12 px kaldı (doküman değeri; 13 px owner kararı). (c) RTL vekili Arapça şekillendirmeyi kanıtlamaz (ürün
  dili değil).
- **Bütünlük:** sahibin kayıt ailesi bayt-aynı (`deb7ff6f…`, .tmp / .bak yok); `default_bus_layout.tres`,
  `project.godot`, `export_presets.cfg` içerikleri bayt-aynı (yeni test betiklerinin `.uid`'leri için headless import ve
  QA dışa aktarımının bayt-aynı geri koyması yalnız değişiklik zamanlarını tazeledi; hiçbiri stage / revert / restore /
  stash edilmedi); `_visual_source/` ve `OWNER_WORKING_PROFILE.md` değişmedi; sahibin kaydının değişiklik zamanını tam
  masaüstü kapısındaki aynı baytların yeniden yazılması tazeledi (içerik aynı).

### 4.37 Squishy UI System V3 + küresel gezinme kabuğu (TASK/057) — TAMAM + MAIN (`84964af`)

> **TAMAM + MAIN (COMPLETE + MAIN) — OWNER / ChatGPT GÖRSEL ONAYI: APPROVED (2026-10-07).** Owner onayıyla ff-only
> `d5237bf → 84964af` (merge commit / rebase / squash / cherry-pick / force push yok); doğrusal 12 commit, son üretim /
> test adayı `a126ace`, tepe `84964af` yalnız doküman; dal `task/057-ui-system-v3-global-nav` yerelde ve origin'de
> duruyor. Onaylanan temel: küresel gezinme yönü, sıra `ANA SAYFA / MAĞAZA / HARİTA / KOLEKSİYON / PROFİL`, merkez
> HARİTA vurgusu, tek candy-madalyon simge ailesi (pembe / altın / cyan / nane / aynı aile içinde Profil avatarı), oyun
> benzeri seçili durum (madalyon büyür + yükselir, krem kaide, altın hale, krem etiket hapı; merkez + ince premium
> halka), sadeleştirilmiş tek nesne tepsi, kaldırılan hub geri okları, gerçek A36 görünümü ve gerçek TEST banner
> fiziksel yerleşimi. Doğrulama ve cihaz kapıları entegrasyondan ÖNCE tamamlandı (aşağıdaki maddeler); entegrasyon ve
> doküman eşitlemesi sırasında hiçbir odak test / tam masaüstü kapısı / A36 / Godot / derleme / mutasyon yeniden
> koşulmadı. AdMob politika / uyum HARİCİ RELEASE KONTROLÜ. Product Vision V3 AKTİF; (TASK/057 entegrasyonu anında) TASK/058 /
> 059 BAŞLAMADI — *sonra: TASK/058 TAMAM + MAIN (§4.38)*; Release PAUSED. Aşağıdaki "READY FOR OWNER REVIEW / main'e ALINMADI" ifadeleri yazıldıkları günün dal aşamasını anlatır
> (TARİHSEL).

> *(Tarihsel — ilk aday, 2026-10-06:)* **READY FOR OWNER VISUAL REVIEW — main'e ALINMADI.** Dal
> `task/057-ui-system-v3-global-nav` (kanonik main
> `d5237bf`'ten; `main == origin/main == d5237bf` DEĞİŞMEDİ; merge / PR yok). Product Vision V3'ün ([GitHub Issue
> #1](https://github.com/oguzhanbilgi/Squishy-Merge/issues/1)) ilk uygulama görevi; owner görsel incelemesi SERT KAPI —
> onay ya da istenen değişiklikler gelmeden tamam sayılmaz, tam kontrollü kapı (A36 dahil) koşulmaz, TASK/058 başlamaz.
> Release Readiness PAUSED / YELLOW. Zincir: `86bde6c` UI System V3 temeli · `d571555` küresel gezinme kabuğu ·
> `3592889` testler + inceleme araçları · `c614e02` doğrulama inceleyicisi kalıntıları (cila — son üretim / test adayı)
> · bu doküman commit'i. İnceleme paketi: `build/qa_057_visual_review/REVIEW_INDEX.md` (git dışı).

- **Faz A denetimi (özet):** mevcut katman `UiTokens` (sayılar) → `make_ui_theme.gd` → `ui_theme.tres` → `UiKit`
  (fabrika) + bileşen sınıfları (`HomeFeatureButton`, `ShopPowerCard`, `MapLevelNode`, `AvatarButton` …) + `UiType`
  rolleri + `UiMotion` + `GestureGuard`; V3 bunun EVRİMİ (ikinci sistem / tema / font yok). Hub ekranları: Ana Sayfa
  (0), Harita (1), Koleksiyon (2), Mağaza (3), Profil (4) — `Main._show_tab`; pencereler ayrı CanvasLayer (10–14); ekran
  içi pencereler: Mağaza onayı, Koleksiyon detayı, Profil başarımlar / unvan. Tuval her telefonda 720 genişlik
  (`canvas_items` + `expand`); en dar pratik görünüm 20:9 (720×1600), en kısa 16:9 (720×1280). Ölçüm: A36'da 1 tuval px
  = 0.571 dp → eski 48 px TOUCH_MIN = 27 dp, 56 px köşe butonu = 32 dp (küçük buton hissinin kaynağı).
- **UI System V3:** tipografi / boşluk / yarıçap / derinlik / kenar / renk rolleri, ölçülmüş dokunma kuralı (84 px =
  A36'da 48 dp; kompakt 64 px), `SquishyButton` (5 tür × 3 boy, açık durum makinesi), `AttentionBadge`, `FeatureCard`,
  `OfferCard`, `PowerCard`, bölüm başlığı V3, onay penceresi — ayrıntı UI_VISUAL_SYSTEM §27. Hiçbiri ekonomi / reklam /
  görev / kayıt çağırmaz; bu görevde üretim ekranına bağlanmadı.
- **Küresel gezinme kabuğu:** `GlobalNav` (katman 6) ANA SAYFA · MAĞAZA · [HARİTA] · KOLEKSİYON · PROFİL; görünürlük ve
  seçili hedef yalnız `Main._sync_nav` (sinyalle); hub dışı / engelleyici yüzeylerde gizli (matris §27.5); aynı hedef /
  gizli kabuk isteği yok sayılır; öğeler GestureGuard'a ait; Android GERİ zinciri değişmedi; opak dock; banner yuvası
  varken 28 px dokunulmayan aralık (uyum AÇIK); hub ekranları `set_nav_inset` ile içeriği kabuğun üstünde bitirir.
- **Owner kararı güncellemesi:** 2026-09-16 "Ana Sayfa'da sekme çubuğu yok" kararı owner'ın son talimatıyla (Issue #1
  §7–§8, TASK/057) değişti — kabuk Ana Sayfa dahil beş hub ekranında.
- **Doğrulama (masaüstü):** odak `ui_system_v3_test` 96 / 96 · `global_nav_shell_test` 175 / 175 (0 SCRIPT ERROR);
  negatif kontroller 15 / 15 varyant açık FAIL ile öldü (seçili durum güncellemesi, Mağaza / Ana Sayfa / Harita alt
  payı, GestureGuard atlatma, aynı sekmeye ikinci gezinme, her yerde görünen kabuk, ekran içi pencere sinyali, gizli
  kabuğun isteği, rozet 0 sayısı, basış çökmesi, ALINDI etkinliği, dokunma bandı, dock, banner aralığı), her geri koyma
  bayt-aynı; çekişmeli inceleme 4 salt-okunur inceleyici / 11 mercek — 0 BLOCKER; 7 HIGH (görünmez dokunma bandı, tepsi
  altında görünen içerik, banner'a 8 px yakınlık, etiket / merkez ikon kontrastı, rozet ölçüm sırası, Harita 16:9 +
  banner sığmazlığı, görsel A36 kanıtı eksik) ve MEDIUM'lar (PowerCard sabit 0/2 kotası, çekim aracının kayıt yolu, geç
  banner yolu / dokunuş düzeyi test kapsamı, FeatureCard min genişlik, REWARDED_AD durum makinesi, CTA durumunun karta
  yansıması …) giderildi; banner aralığı uyumu AÇIK (owner); doğrulama inceleyicisi ayrıca koştu; tam masaüstü
  regresyonu (aday `c614e02`) 55 / 55 temiz, 7071 kontrol, 0 FAIL, 0 SCRIPT ERROR, bot 2 / 2; sahibin kayıt ailesi
  bayt-aynı. **Samsung A36 cihaz kapısı KOŞULMADI** (owner görsel onayından sonra, tam kontrollü kapıyla).
- **Bilinen görsel uzlaşmalar → kabul edilen, engellemeyen takip işleri (owner onayıyla):** Ana Sayfa'da OYNA +
  merkez HARİTA aynı hedef; Ana Sayfa Mağaza / Koleksiyon kısayolları ve avatar kabukla yineleniyor → TASK/058;
  ~~hub ekranlarında üst satır geri oku kaldı~~ (Tur 2: kaldırıldı); ~~Harita 16:9 + banner yuvasında %18~~ (Tur 2: %7.4
  geçici hafifletme; kaydırılabilir yolculuk + Meydan Okuma rotası → TASK/059); Ana Sayfa maskotu A36 + banner'da ~391
  px (TASK/058); Profil banner göstermez, kabuk sabit konumda — altında koyu ayrılmış footer alanı (DÜŞÜK, sonraki
  cila); A36'da ~2 s'yi aşan basılı tutuşta basış önizlemesi düşebiliyor (gözlem); banner aralığının AdMob uyumu HARİCİ
  RELEASE KONTROLÜ — §27.9.
- **Kapsam dışı / sonraki görevler (BAŞLAMADI):** TASK/058 Ana Sayfa V3 · 059 Harita V3 (meydan okuma rotası,
  kaydırılabilir yolculuk) · 060 Gameplay HUD V3 + ödüllü güçler (güç başına kota GAME_DESIGN §5.7.3 değişikliği + owner
  onayı ister) · 061 Günlük & Görevler V3 · 062 Mağaza V3 + Başlangıç Paketi · 063 Meydan Okuma merkezi · 064 Koleksiyon
  / Profil / Ayarlar cilası.
- **İnceleme notu (önceden var olan, düzeltilmedi):** uygulamaya dönüşte otomatik günlük pencere kapısı Mağaza onayını
  kontrol etmez (pencere onayın üstüne açılabilir; TASK/055 notlarında da kayıtlı) — owner kararı.
- **Görsel Cila Tur 2 (owner incelemesi, 2026-10-06) — o gün yeniden owner incelemesine sunuldu (TARİHSEL; son aday
  2026-10-07 owner onayıyla main'de).** Owner
  kararları: küresel gezinme yönü TUTULDU (sıra / merkez HARİTA / Ana Sayfa'da kabuk / gizli yüzeyler / 84-64 px /
  GestureGuard / V3 aynen); **hub geri okları KALDIRILDI** (Harita / Mağaza / Koleksiyon / Profil; `back_button()` null,
  `home_requested` ve `Main._on_home_requested` yok; Ana Sayfa'ya dönüş kabuk ANA SAYFA + Android GERİ — zincir
  DEĞİŞMEDİ); kabuk cilası (tepsi ön dudağı, ikon 58 / etiket 19, **tek seçili aile** `NavItem.selected_family()` —
  merkez yalnız +1 altın halka); **Harita 16:9 + banner %18 REDDEDİLDİ → %7.4** (kompakt kabuk: kullanılabilir yükseklik
  < 1200 px'te merkez taşması 0, pay 160 → 120, her öğe ≥ 84 px; `MIN_SQUASH_NAV` 0.78 → 0.92; kurdele gerekirse satırını
  bırakır; sıradaki düğüm ≥ 84 px; 6 haneli Hamur bilinçli sınır); banner aralığı kaide + dikiş (dokunuş almaz, uyum
  AÇIK); Ana Sayfa OYNA ↔ kabuk +18 px; vitrin bileşen cilası. Doğrulama: odak + koruma 15 suite temiz (odak
  `global_nav_shell_test` 207 + `ui_system_v3_test` 98; geri okuna dayanan koruma suite'leri kabuk ANA SAYFA / Android
  GERİ'ye taşındı, niyet aynı); tam masaüstü regresyonu 55 / 55 temiz, 7 116 kontrol, 0 FAIL, 0 SCRIPT ERROR, bot 2 / 2
  (negatif kontroller durdurulduktan sonra yeniden koşuldu); negatif kontroller 20 / 20 varyant açık FAIL ile öldü (Tur 2
  için: geri oku geri, kompakt öğe < 84, Tur 1 sıkıştırması, kompakt kip kapalı, merkezin ayrı seçili malzemesi; owner
  talimatıyla hafif tutuldu — ek varyant koşulmadı, durdurulan koşunun dosyası bayt-aynı geri konduğu hash ile
  kanıtlandı); salt-okunur inceleme 2 inceleyici / 9 mercek — 0 BLOCKER / 0 HIGH, MEDIUM'lar (kompakt merkez zayıflığı,
  seçili merkezin halka ağırlığı, kurdele uç durumu, A36 yan dumpling'in level pill'ine binmesi, FeatureCard alt yazı
  kontrastı) giderildi; sahibin kayıt ailesi bayt-aynı. Zincir: `4f53332` üretim · `f6ece0f` testler · `05978c5` doküman
  (bu paragrafın yer tutucuları son cila doküman commit'inde dolduruldu). Ayrıntı UI_VISUAL_SYSTEM §27.11; inceleme
  paketi `build/qa_057_visual_review/REVIEW_INDEX.md` (Owner Review Round 2) +
  `build/qa_057_owner_review/TASK057_OWNER_REVIEW.zip` (git dışı).
- **Son görsel cila + gerçek A36 kapısı (2026-10-07) — SON GÖRSEL ADAY; owner / ChatGPT görsel onayı APPROVED, owner
  onayıyla ff-only main'e alındı (`d5237bf → 84964af`).**
  Owner / ChatGPT: Tur 2 yön onaylı ama kabuk kısmen genel uygulama araç çubuğu gibi. Uygulanan: **tek gezinme simge
  ailesi** (her hedef aynı candy madalyonu: beyaz kenar + vurgu yüz + koyu dudak + lacivert picto; Profil yüzü avatar;
  merkez Harita aynı ailenin büyük üyesi), **oyun benzeri seçili durum** (madalyon büyür + tepsiden yükselir + krem kaide
  + altın hale + krem etiket hapı; hücre boyu krem karo yok; merkez +1 altın halka), güçlendirilmiş basılı önizleme,
  **tek parça tepsi** (iç gloss / parlaklık bandı yok). Dokunma alanları / kompakt kip / GestureGuard / GERİ aynen.
  Doğrulama (aday `a126ace`): `ui_system_v3_test` 100 · `global_nav_shell_test` 211; tam masaüstü regresyonu 55 / 55
  temiz, 7 122 kontrol, 0 FAIL, 0 SCRIPT ERROR, bot 2 / 2; yeni mekanizma için 2 hafif negatif kontrol (seçili yan öğe
  hücre karosu, simge ailesi kırılması) açık FAIL ile öldü, geri koyma bayt-aynı; sahibin kayıt ailesi bayt-aynı.
  **Gerçek Samsung A36** (QA paketi `com.obappstudio.squishymerge.qa`, APK sha256 `c9b595fd…`, Google TEST reklamları):
  beş hub + seçili yan / merkez + basılı + oyun ve pencerede kabuk yok yakalandı; gerçek TEST banner Ana Sayfa / Harita /
  Mağaza / Koleksiyon'da 168 fiziksel px = 112 tuval px (masaüstü varsayımı geçerli), banner üstü y 2172 ↔ tepsi altı
  2128 (28 tuval px kaide aralığı), çakışma yok; dokunuş duman testi: beş gerçek kabuk dokunuşu her biri tam bir
  gezinme, aynı sekme 0, ACTION_CANCEL 0, sürükleyip bırakma 0, Android GERİ Mağaza → Ana Sayfa, pencere / oyun kabuğu
  gizler, Mağaza'nın son SATIN AL'ı kabuğun üstünde ve onayı açar (0 gezinme, satın alma yok); logcat 0 SCRIPT ERROR /
  0 çökme / 0 ANR, yalnız Google örnek yayıncı; yabancı dokunuş 0. QA paketi owner incelemesi için cihazda KURULU
  bırakıldı; üretim paketi hiç kurulmadı, `com.example.squishymerge` dokunulmadı; gezinme kipi / saat değişmedi.
  Gözlem: ~2 s'yi aşan basılı tutuşta basış önizlemesi düşüyor (Android uzun basış; araştırılmadı). Harita 16:9 +
  banner hafifletmesi GEÇİCİ temel; kaydırılabilir yolculuk + Meydan Okuma rotası TASK/059. Ayrıntı UI_VISUAL_SYSTEM
  §27.12; paket `build/qa_057_visual_review/REVIEW_INDEX.md` (Final) + `build/qa_057_owner_review/TASK057_OWNER_REVIEW.zip`
  (git dışı). Zincir: `26e0323` ui · `a8bb297` test · `a126ace` ui (basılı önizleme) · bu doküman commit'i.

### 4.38 Ana Sayfa V3 (TASK/058) — TAMAM + MAIN (`7025bd4`; owner görsel onayı APPROVED)

> **TAMAM + MAIN (2026-10-08).** Owner son fiziksel Samsung A36 Ana Sayfa'sını inceledi ve **yalnız TASK/058 Ana Sayfa V3'ü**
> (kompakt GÜNLÜK | MEYDAN karoları ve TEXT-LIGHT / ICON-FIRST Ana Sayfa yönü dahil) ONAYLADI — Harita / Mağaza / Koleksiyon /
> Profil / Meydan Okuma V3 için genel onay DEĞİL. Owner onayıyla ff-only `28a5bf1 → 7025bd4` (2026-10-08; merge commit / rebase / squash / cherry-pick / force push YOK; dal `task/058-home-v3` = `7025bd4` duruyor). Son
> üretim / test adayı `9b4e2ed`'in masaüstü + gerçek A36 kanıtı entegrasyondan ÖNCE alındı (aşağıda); entegrasyon ve doküman
> eşitlemesi sırasında hiçbir test / Godot / derleme / cihaz kapısı yeniden koşulmadı. TASK/057 kabuğu korunuyor. TASK/059
> BAŞLAMADI; Release PAUSED. Aşağıdaki "dal aşaması / owner incelemesi bekliyor" ifadeleri o turların TARİHSEL kaydıdır.
>
> *(Tarihsel — dal aşaması, 2026-10-07:)* Dal `task/058-home-v3`, text-light son aday `9b4e2ed` (taban `28a5bf1`); owner görsel
> yönü onayladı, K1–K9 kilitlendi, owner'ın gerçek A36 elle denemesinden sonra K10 uygulandı; masaüstü ve gerçek A36 kapısı
> GEÇTİ; owner text-light incelemesi bekleniyordu.

- **Faz A denetimi (düzenlemeden önce, `build/qa_058/AUDIT_PHASE_A.md`):** taban Ana Sayfa'da 10 eşit ağırlıkta öğe; kabukla
  yinelenen KOLEKSİYON / MAĞAZA madalyonları, Hamur "+", avatar (Profil), level hapı (Harita); OYNA merkez HARİTA'nın hemen
  üstünde; Günlük / Meydan Okuma özellik olarak keşfedilmiyordu.
- **Owner bulgusu "Ana Sayfa'daki Günlük'e basınca bir şey gelmiyor" — KÖK NEDEN (kanıtlı):** ilk gün kapısı.
  `Main.open_daily_rewards()` tutorial'ın bitirildiği gün sessizce döner (GAME_DESIGN §12.3, kilitli), eski madalyon ise
  etkin ve sıradan görünüyordu. Salt okunur cihaz kanıtı: QA paketi 2026-10-06 14:06'da kuruldu, kendi kaydında
  `onboarding_completed_day = "2026-10-06"` (owner'ın test günü) — girdi / ekran görüntüsü yok, oturumun adb süreci
  durduruldu. Sınıf: kayıt / durum ön koşulu + Ana Sayfa'nın durumu göstermemesi; rota / gizli pencere / TASK/061 DEĞİL.
  İnceleme sırasında ayrıca iki GİZLİ kusur (owner'ın o gün gördüğü olduğuna dair kanıt yok): madalyon etiketi ölü bölgesi
  ve günlük pencerenin yatışmasız açılış / kapanışı (hızlı ikinci dokunuş pencereyi aynı anda kapatıyordu).
  Taban farkı (`tools/home_v3_test.tscn -- daily-only`, dokunulmamış `28a5bf1` üretim kodu, son test): 22 kontrol, **5 açık
  FAIL**; aday 186 / 186.
- **Düzeltme:** GÜNLÜK ÖDÜLLER kartı ilk gün pasif + kilit + "Yarın açılır" (kural / ekonomi aynen; öne dönüşte tazelenir);
  `HomeFeatureButton._has_point` etiket plakasını kapsar; günlük pencere açılış / kapanışta 300 ms yatışma (GÖREVLER / MEYDAN
  OKUMA gibi). Ödül miktarı / kota / otomatik pencere / Mağaza kartı / görev mantığı DEĞİŞMEDİ (TASK/061'e dokunulmadı).
- **Ana Sayfa V3:** üst durum satırı (seviye + unvan + XP · Hamur — dokunma almaz) · logo + büyük maskot + köşelerde GÖREVLER /
  BONUS SANDIK madalyonları · V3 kahraman OYNA (→ Harita, rota aynen) + dokunma almayan level bilgisi · iki V3 özellik kartı
  (GÜNLÜK ÖDÜLLER, MEYDAN OKUMA — gerçek veriyle) · gizli boş teklif yuvası (TASK/062) · TASK/057 kabuğu aynen. Etkileşimli
  öğe 10 → 5. Ayrıntı: UI_VISUAL_SYSTEM §28.
- **Commit'ler (dal):** `c5d3bbc` düzeltme (günlük pencere yatışması + madalyon etiketi) · `029eced` arayüz (Ana Sayfa V3) ·
  `9080a85` + `fd59d69` + `749080b` + `6e88368` test · `8b070e8` doküman (görsel inceleme adayı) · **son cila:** `e060cd0`
  arayüz (K9 terimleri) · `91c74b2` test (K9) · `6de0410` GAME_DESIGN ifadesi · `01f167e` test araçlarının `.uid` dosyaları ·
  bu doküman commit'i.
- **Kanıt (son üretim / test adayı `6e88368`; üretim kodu `029eced`'ten beri değişmedi):** kontrollü tam masaüstü kapısı 56 / 56 temiz (home_v3_test dahil), 7243 kontrol, 0 FAIL, 0 SCRIPT ERROR, bot 2 / 2, sahibin kaydı bayt-aynı; `home_v3_test` 186 / 186. İlk tam koşu
  (`749080b`) 55 / 56 temizdi — tek FAIL `age_ad_routing_test`in tam OYNA kayma beklentisi (V3 kompakt sabitleri eksikti);
  test uyarlandı (`6e88368`), tam kapı yeniden koşuldu. Hafif negatif kontroller: 10 / 10 varyant açık FAIL ile öldü
  (rota kopuk · Hamur "+" geri · kabuk payı yok · OYNA çift gezinme · GestureGuard'sız Günlük · açılış / kapanış yatışması yok ·
  öne dönüş tazelemesi yok · etiket isabeti yok · ilk gün kartı etkin), her geri koyma bayt-aynı. Çekişmeli salt-okunur inceleme
  3 inceleyici / 10 mercek — 0 BLOCKER; tek HIGH (OYNA → Harita yinelemesi) owner talimatıyla kabul edilmiş yineleme (iki kart
  arayla); MEDIUM'lar giderildi (bayat kilit, unvan genişliği, kilitli kart görünümü, alt yazı puntosu, test geçerliliği,
  dürüst ifade). Görsel paket: `build/qa_058_visual_review/` (taban + aday 6 görünüm × 8 kare, 8 contact sheet).
- ~~**Açık / owner kararı:** K1–K9; GAME_DESIGN ifade güncellemesi~~ → **owner kararı (2026-10-07): görsel yön ONAYLI;
  K1–K8 A** (ilk gün kartı pasif + kilit + "Yarın açılır" · Ana Sayfa avatarı yok · Hamur "+" yok · GÖREVLER / BONUS SANDIK
  köşe madalyonları · sıradaki bölüm satırı yalnız gösterge · kart metinleri aynen · gizli 0 yükseklikli teklif yuvası ·
  OYNA → Harita ve HARİTA → Harita aynen); **K9** (yalnız Ana Sayfa): oyuncu rozeti "SV." (önce "LV."), "SIRADAKİ BÖLÜM N"
  (önce "Level N"), sonsuzda "SONSUZ MOD" + yıldızlar aynen — `PlayerLevelBadge.set_caption` eklendi, Profil / sonuç "LV."
  aynen. GAME_DESIGN §5.4.1 / §5.8 / §5.10 / §5.11 / §7 / §12.3 yalnız ifade (`6de0410`; kural / sayı / ekonomi aynen).
- **Son kanıt (son aday `6de0410`; üretim / test içeriği `91c74b2` ile aynı):** K9 odak koşusu 6 / 6 temiz, 997 kontrol
  (ilk denemede `PlayerLevelBadge`'de yinelenen `caption_text` ayrıştırma hatası — koşucu ağacı durduruldu, kayıt bayt-aynı,
  düzeltildi, yeniden koşuldu); **kontrollü tam masaüstü kapısı gate3: 56 / 56 temiz, 7248 kontrol, 0 FAIL, 0 SCRIPT ERROR,
  bot 2 / 2, sahibin kaydı bayt-aynı (görev öncesi yedekle de)**; `home_v3_test` 191 / 191; K9 hafif negatif kontroller
  2 / 2 açık FAIL ile öldü ("Level %d" geri · rozet "LV." geri), bayt-aynı geri kondu.
- **Gerçek Samsung A36 kapısı — GEÇTİ (2026-10-07):** QA paketi `com.obappstudio.squishymerge.qa`, QA APK `6de0410`'dan
  (statik doğrulama 102 kontrol: QA kimliği, Google örnek kimlikleri, GMA 25.3.0 / UMP 4.0.0, Ana Sayfa V3 + K9
  tanımlayıcıları var, kaldırılan kısayollar yok); QA katmanı `qa058_device` yalnız `build/` altında, commit EDİLMEDİ.
  Üretim paketi hiç kurulmadı; `com.example.squishymerge` dokunulmadı; salt okunur ön kontrol; her girdi / çekim güvenlik
  denetimli — iki arama sırasında tüm girdi / çekim engellendi, arama sonrası alınan yanlış içerikli bir kare silindi,
  sürücü ilk güvensiz denetimde durur hâle getirildi ve adımlar 60 sn güvenli süreden sonra yeniden koşuldu; otomatik kilit
  açma / gezinme kipi / saat / saat dilimi değişikliği yok; QA paketinin kendi kaydı (+ .bak) bayt-aynı geri kondu, paket
  kurulu bırakıldı; yalnız oturumun adb daemon'u durduruldu. 9 fiziksel kare (Ana Sayfa TEST banner'lı / banner'sız,
  seçili ANA SAYFA, ilk gün kilitli, hepsi tamam, GÜNLÜK / MEYDAN OKUMA / GÖREVLER pencereleri). Gerçek dokunuş: her giriş
  (kart gövdesi / başlık / alt yazı, madalyon gövdesi / etiket) tam bir açılış; karartma / KAPAT / X / GERİ kapatır; çift
  dokunuş tek açılış; 600 ms basılı tut + bırak tek açılış; bas + sürükle + bırak 0; ilk gün kilitli kart 0 açılış;
  OYNA tek / çift dokunuş tam bir Harita geçişi, 0 level başlatma; kabuk ANA SAYFA Ana Sayfa'da 0 gezinme, diğerleri birer;
  öne dönüş (HOME + yeniden açma) doğru; yabancı dokunuş sayımı her grupta kendi dokunuşlarına eşit. Log taraması: 0 SCRIPT
  ERROR, 0 çökme / ANR / yerel sinyal, yalnız Google TEST yayıncısı. **Gerçek Google TEST banner** (yerleşim kanıtı,
  politika sertifikası DEĞİL): SHOWN, 113 tuval px = 170 fiziksel px, tepsi ile ~42 fiziksel px (~28 tuval px) aralık,
  çakışma yok. Fiziksel görsel değerlendirme: TASK/058'e özgü gerileme yok → kod değişikliği gerekmedi. Engellemeyen not
  (TASK/058 dışı): banner yuvası hiç yokken kabuk tepsisi ekran altına ~12 fiziksel px yakın — TASK/057 kabuk kodu,
  değişmedi (TASK/064 cila).
- **Owner paketi:** `build/qa_058_owner_review/TASK058_OWNER_REVIEW.zip` (git dışı) — `final_real_a36/` (9 kare),
  `contact_sheets/` (taban vs V3, `pre_a36_vs_final.png`, `final_real_a36.png`, son duyarlı matris), doküman 00–06, kanıt,
  `MANIFEST.sha256`; APK / kayıt / seri no / reklam kimliği / anahtar YOK.
- **K10 — TEXT-LIGHT / ICON-FIRST (owner, 2026-10-07; gerçek A36 elle denemesinden sonra):** "Alt bar iyi. Günlük ve
  Meydan Okuma çok büyük, ortada ağır duruyor; fazla yazı; ürün genelinde neredeyse hiç yazı olmasın; ikon, rozet, sayı,
  ilerleme; gerekiyorsa tek kelime." Büyük kartlar REDDEDİLDİ; yerine yeni V3 bileşeni `FeatureTile` (candy ikon kuyusu +
  tek kelime + durum cipleri, köşe rozeti, hazır halesi, › yok, karonun tamamı tek hedef; `FeatureCard` değişmedi) ile OYNA'nın
  altında yan yana **GÜNLÜK | MEYDAN** (yarım sütun 328 × 108 tuval px). Metin denetimi (Ana Sayfa): GÜNLÜK ÖDÜLLER → GÜNLÜK ·
  seri cümlesi → alev + sayı · "ücretsiz sandık / giriş ödülü hazır" → HAZIR (+ "!" + hale) · "bugünün sandığı alındı" →
  kaldırıldı · "bugünlük tamam" / "Bugün tamamlandı · yarın yenisi" → ✓ TAMAM · "Yarın açılır" → kilit + YARIN · › →
  kaldırıldı · MEYDAN OKUMA → MEYDAN · "Dev Dumpling yap · 38 hamlede" → hedef portresi + "38 HAMLE" (oyun HUD'unun kelimesi)
  · "+20 HAMUR" → Hamur ikonu + "+20" · BONUS SANDIK → SANDIK; KEEP: SV. N, unvan, Hamur, GÖREVLER + N/6, SIRADAKİ BÖLÜM N,
  SONSUZ MOD, OYNA, kabuk etiketleri. Maskot: 720×1280 449 → 600 · 16:9 + banner 112 361 → 486 · 128 347 → 465 · A36 +
  banner 528 → 600 tuval px. Davranış aynen (rotalar, ilk gün kuralı, yatışma, öne dönüş tazelemesi, ekonomi). GAME_DESIGN
  yalnız ifade (§5.4.1 / §5.10 / §5.11 / §7 / §12.3). İlke UI_VISUAL_SYSTEM §29'da kayıtlı (TASK/059–064 varsayılanı).
  **Commit'ler:** `0b49b3f` arayüz (kompakt karolar) · `9b4e2ed` test · bu doküman commit'i (+ GAME_DESIGN ifadesi).
  **Kanıt (`9b4e2ed`):** `home_v3_test` 229 / 229 (yapı, durumlar, ikon / kelime / karo dokunuşu tam bir kez, iptal 0,
  çift dokunuş tek, beş veri durumunda uzun / açıklayıcı metin sızmaz, kaynak sözleşmesi, maskot ≥ 440); odak + koruma
  koşusu 16 / 17 (tek kirli koşu eski kart API'sini çağıran `home_ui_test` sürümü — uyarlandı, 153 / 153); K10 hafif negatif
  kontroller 4 / 4 açık FAIL ile öldü (uzun Günlük metni · uzun Meydan Okuma cümlesi · karo < dokunma hedefi · ikon dokunuşu
  yutuluyor), bayt-aynı geri kondu; **kontrollü tam masaüstü kapısı gate4: 56 / 56 temiz, 7286 kontrol, 0 FAIL, 0 SCRIPT
  ERROR, bot 2 / 2, sahibin kaydı bayt-aynı (görev öncesi yedekle de)**. **Gerçek Samsung A36 (K10) — GEÇTİ:** QA APK
  `9b4e2ed`'den (statik doğrulama 105 kontrol); üretim paketi hiç kurulmadı; `com.example.squishymerge` dokunulmadı; QA
  paketinin kaydı owner'ın kendi elle denemesinden sonra değişmişti — o güncel durum yedeklendi ve bayt-aynı geri kondu; her
  girdi güvenlik denetimli + QA-önde koruması, güvensiz dönem olmadı; 9 fiziksel kare (varsayılan, banner, meydan açık,
  sandık alındı, ilk gün YARIN, günlük tamam, meydan tamam, iki pencere); gerçek dokunuş: GÜNLÜK / MEYDAN gövde / ikon /
  kelime tam bir kez, çift dokunuş tek, iptal 0, kilitli 0, OYNA tek Harita geçişi, kabuk aynen, SANDIK / GÖREVLER birer;
  log: 0 SCRIPT ERROR, 0 çökme / ANR, yalnız Google TEST yayıncısı (2 "E godot" satırı = yalnız QA koşum sahnesinin eski UID
  uyarısı, üretim değil). Gerçek TEST banner (yerleşim kanıtı, politika iddiası DEĞİL): karolar tepsiden 81 fiziksel px
  yukarıda, tepsi–banner ~42 px, çakışma yok. Fiziksel görsel değerlendirme: karolar oyun özelliği gibi, büyük orta kart
  yok, OYNA baskın, maskot büyük, tek kelimeler / cipler okunur, kırpma yok — TASK/058'e özgü gerileme yok.
- **Owner paketi (K10):** `build/qa_058_owner_review/TASK058_OWNER_REVIEW.zip` — `pre_text_light_vs_final.png`,
  `final_real_a36.png`, `final_real_a36_tiles.png`, son duyarlı matris, `final_real_a36/` (9 kare), doküman 00–06 (02:
  `K10 — TEXT-LIGHT / ICON-FIRST: APPROVED`), kanıt, `MANIFEST.sha256`; APK / kayıt / seri no / reklam kimliği / anahtar YOK.
- ~~**Açık:** owner text-light görsel incelemesi (+ sonra entegrasyon onayı, main'e ff-only)~~ → **owner görsel onayı APPROVED
  (2026-10-08, yalnız Ana Sayfa V3) — ff-only `28a5bf1 → 7025bd4` entegre edildi + doküman eşitlemesi.** Açık TASK/058 maddesi
  yok. Engellemeyen notlar: QA koşum sahnesinin eski UID uyarısı (yalnız QA paketi, üretim değil); banner'sız kabuk payı
  (TASK/057 kodu → TASK/064); AdMob politika / uyum harici release kontrolü.

### 4.39 Harita V3 — kaydırılabilir candy yolculuk + MEYDAN portalı (TASK/059) — DAL AŞAMASI, owner görsel incelemesi bekliyor

> **DAL AŞAMASI (2026-10-08).** Dal `task/059-map-v3` (taban `f6dcf29` = main = origin/main, `git ls-remote` ile doğrulandı);
> main DEĞİŞMEDİ, PR / merge YOK. Owner görsel incelemesi: `build/qa_059_owner_review/TASK059_OWNER_REVIEW.zip` (git dışı).
> Gerçek Samsung A36 kapısı owner görsel onayından SONRA (bu turda koşulmadı; 1080×2340 masaüstü çekimleri A36 kanıtı DEĞİLDİR).
> Owner onaylı DEĞİL. TASK/060 BAŞLAMADI; Release PAUSED.

**Faz A denetimi (`f6dcf29`, düzenlemeden önce — `build/qa_059/AUDIT_PHASE_A.md`):** owner zemini TEK 720×1280 perspektif
resim (yakın patika → kale kapısı). f6dcf29 yolculuğu tek ekrana sığdırmak için zemini dikeyde sıkıştırıyordu (`sy/sx`
720×1280 0.944, 16:9 + 112 0.926, 16:9 + 128 0.909; kurdele satırını bırakıyordu); 16:9 + 128 taban çekiminde düğüm 5'in OYNA
plakası düğüm 4'e biniyordu. Düğüm plakası (OYNA) buton dikdörtgeninin DIŞINDA ve `MOUSE_FILTER_IGNORE` — kelimeye dokunuş
hiçbir kontrole ulaşmıyordu (TASK/058 Günlük plakasıyla aynı kusur sınıfı); kabukla en küçük düğüm ≈ 68 px (< V3 84).
MEYDAN OKUMA penceresi yalnız Ana Sayfa'nındı (`open_daily_challenge` `_active_tab == 0` dışında dönüyordu).

**Fizibilite (Seçenek A seçildi, ölçüldü — `build/qa_059/shots/FEAS_*`):** tek tip dünya ölçeği + sınırlı dikey kaydırma.
1.45 A36'da 1:1 belirgin yumuşak (2.18× fiziksel), 1.15 A36'da neredeyse kaymıyor (205 px); **1.3**: kaydırma 16:9 484, 16:9 +
112 616, 16:9 + 128 632, 720×1600 164, A36 benzeri 265 / + banner 397 px; A36'da 1.95× fiziksel (bugünkü onaylı A36 haritası
1.83×). Yeni sanat yok; Seçenek B / C gerekmedi. Bilinen bedel: zeminin iki alt maskotu 1.3'ün yatay kırpmasında yarıya
yakın görünür (owner kararı — ZIP 02).

**Uygulama (commit'ler):** `1308b44` ui — kaydırılabilir dünya (`WorldClip` / `World` / gök + toprak bandı), kendi jest sahibi
(14 px eşik, `NOTIFICATION_SCROLL_BEGIN`, savurma, iptal), giriş odağı politikası, açılışta kamera süzülmesi, düğüm dokunma
alanı gövde + plaka + en küçük ≥ 84, text-light Sonsuz plakaları, yeni `MapChallengePortal` + `MapTrail` yan yol paleti, ⭐
toplam yıldız pill'i, kurdele gizli, Main: Harita portalı → mevcut `open_daily_challenge` (Ana Sayfa ya da Harita; pencere
açan ekranın — `_challenge_origin_tab`), `_refresh_challenge_entries`, `_sync_nav` harita jestini iptal eder · `d11d820` test
— yeni `map_v3_test`, `map_v3_shots`, niyet korunarak uyarlanan `map_ui_test` / `global_nav_shell_test` /
`monetization_test` / `daily_challenge_ui_test` · `5af4aa2` ui — inceleme sonrası sertleştirme (savurma / süzülme yakalaması
düğüm başlatmaz, üst satır pill'leri dokunuşu tutar ama sürükleme kaydırır, sınırda ölü parmak yolu yok, gizlenince açılış
animasyonu durur, dinlenme konumu pill'lerden ≤ 160 px kaçar, portal durumu gerçek "+20" çipi / ✓ — "!" yok, yan yol 5→6
kesiminin ortasından ve kalın) · `b609054` test — inceleme sonrası güçlendirme (çizilen zeminden türetilen patika kontrolü,
pozitif kontroller, yakalama, gün dönümü, en-boy oranı) · `8c77985` test — TASK/051 suite'i (`start_level_touch_settle_test`)
bitmiş-oyuncu fikstüründe level 3'ü dokunmadan önce kamerayla açık banda getirir (yeni harita girişte Sonsuz kalesine
odaklanır; level 3 kabuğun arkasında kalıyordu — ilk tam kapıda bu suite 9 FAIL verdi, ürün hatası DEĞİL; sözleşme aynen
ölçülür, 126 / 126) · + bu dal-aşaması doküman commit'i. Üretim kodu `b609054`'ten beri DEĞİŞMEDİ.

**Değişmeyenler:** level verisi / sırası, unlock (`highest_level_unlocked`), yıldızlar, Sonsuz şartı, level başlatma yolu,
fizik, XP, ekonomi, kayıt şeması, reklam / rıza / yaş, Ana Sayfa V3 (TASK/058, kod diff'i yok), küresel gezinme kabuğu
(TASK/057, kod diff'i yok; görünürlük / GERİ zinciri aynen), meydan okuma kuralları / ödülü / round çıkışı (Ana Sayfa).
Harita ilerleme / ekonomi kaydına yazmaz; tek olası yazma portalın gün okumasının (TASK/047 monoton gün gözlemi) yeni günü
ilk kez görmesidir — Ana Sayfa MEYDAN karosuyla aynı okuma.

**Kanıt (son üretim kodu `b609054`, son test adayı `8c77985`):** `map_v3_test` 165 / 165; uyarlanan `map_ui_test` 122,
`global_nav_shell_test` 211, `monetization_test` 258, `daily_challenge_ui_test` 151, `start_level_touch_settle_test` 126 — hepsi
0 FAIL. Kontrollü tam masaüstü kapısı (57 koşum): 57 / 57 temiz, 7445 kontrol, 0 FAIL, 0 SCRIPT ERROR, bot 2/2, sahibin kaydı bayt-aynı (ilk kapıdaki 9 FAIL yalnız TASK/051 suite'inin harita ön koşuluydu — uyarlandı, `8c77985`).
4 hafif negatif kontrol (N1 sürükleme basışı iptal etmez · N2 portal normal level'a gider · N3 düğüm tabanı kabuğu yok sayar ·
N4 odak yanlış düğüm) — dördü de öldü (`map_v3_test` açık FAIL, rc 1), her biri bayt-aynı geri kondu
(`build/qa_059/mutations/summary.txt`). Salt-okur inceleme 4 gözden geçirici × 10 mercek (sanat sürekliliği, düğüm okunurluğu,
keşfedilebilirlik, küçük ekran / banner, kaydırma / girdi güvenliği, GlobalNav entegrasyonu, Meydan Okuma sahipliği, text-light,
Türkçe etiketler, kapsam + test yeterliliği): BLOCKER 0; HIGH yalnız "kanonik dokümanlar güncel değil" (bu commit); MEDIUM'lar
giderildi (yukarıdaki `5af4aa2` / `b609054`) ya da owner kararına bırakıldı (ZIP 02). Sahibin kayıt ailesi (`deb7ff6f…`, `.tmp`
/ `.bak` yok) baştan sona bayt-aynı; `default_bus_layout.tres`, `project.godot`, `export_presets.cfg`,
`OWNER_WORKING_PROFILE.md`, `_visual_source` (13 738 dosya, `914c63e8…`) dokunulmadı.

**Bilinçli olarak yapılmayan / owner kararı:** GAME_DESIGN §5.11 "Arayüz" paragrafındaki "Harita'da yok" ifadesi bu görevin
owner talimatıyla eskidi — GAME_DESIGN kilitli olduğu için bu dalda DEĞİŞTİRİLMEDİ; owner onayıyla yalnız ifade güncellemesi
önerildi (ZIP 02). Meydan Okuma merkezi / pencere metinleri TASK/063; HUD / güçler TASK/060; Mağaza TASK/062; Koleksiyon /
Profil / Ayarlar TASK/064.

## 5. Dosya/klasör yapısı ve script envanteri

```
squishy-merge/
├── project.godot            # 3 autoload, 720x1280 portrait, mobile renderer
├── scenes/
│   ├── main.tscn            # akış kontrolü (tek gerçek "sahne")
│   ├── game/                # dumpling, game_board, pop_effect
│   └── ui/                  # home_screen, level_select, collection_screen,
│                            #   shop_screen, round_result, daily_rewards_popup
│                            #   (M8.9-02; eski daily_reward_popup 02.1'de kalktı),
│                            #   settings_panel, shell_backdrop (M8.5-10)
├── addons/AdmobPlugin/      # godot-admob v6.0 release (kaynak değişmedi) + android_export.cfg (M8.9-01)
├── addons/squishy_ads_export/ # proje export eklentisi: android_export.cfg'yi PCK'ye ekler + doğrular
├── scripts/
│   ├── autoload/            # GameState, AudioManager, SaveManager
│   ├── ads/                 # MonetizationManager (+ interstitial M8.9-02), AdBackend/AdmobBackend, AdConfig, AdEvents (M8.9-01)
│   ├── game/                # oyun mantığı
│   └── ui/                  # ekran mantığı
├── resources/
│   ├── levels/              # level_01..10.tres + endless.tres  (data-driven)
│   └── skins/               # 20 skin .tres                      (data-driven)
├── assets/
│   ├── audio/               # sfx/{ui,gameplay,powers,rewards}/ (27 dosya) + CREDITS.md
│   └── visual/              # sprite'lar, fx/, ui/, icon/, ui_theme.tres, CREDITS.md
├── tools/                   # ⚠️ SADECE geliştirme araçları — export'ta filtrelenmeli
└── _visual_source/          # ⚠️ ham kaynaklar — export'ta filtrelenmeli
```

### Autoload'lar (sadece üç tane — dördüncüyü eklemeden gerekçelendir)

| script | işi |
|---|---|
| `autoload/game_state.gd` | Koşu-anı durumu: skor, merge sayısı, aktif level. Sinyal yayar (`score_changed`, `merge_performed`). |
| `autoload/audio_manager.gd` | Tüm SFX çalma noktası (M8.5-15): `EVENTS` olay tablosu, 12 kanal + öncelikli kanal çalma, soğuma/tavan, yerel RNG, fallback. `play(&"merge")`, `play_merge(tier)`, `play_landing(tier, hız)`. Bus: Master → SFX (limiter) / Music. |
| `haptics.gd` | `Haptics` statik servisi (M8.5-15): LIGHT/MEDIUM/STRONG/SPECIAL, spam penceresi, editor'de güvenli, test sink'i. |
| `autoload/save_manager.gd` | Yerel kalıcı kayıt, JSON, `user://`. Bulut yok. `save_game() -> bool` (TASK/045.1); `save_path` yalnız testlerin yönlendirmesi. |
| `autoload/save_file.gd` | `SaveFile` (autoload DEĞİL, TASK/045.1): çökmeye dayanıklı kayıt işlemi (bellekte doğrulanan yük → kurtarılacak `.tmp` önce terfi → `.tmp` + bayt geri okuma → eski kayıt `.bak`'a, bir önceki kayıt olarak kalır → `.tmp` kanonik ada) ve deterministik kurtarma (geçerli kanonik > geçerli `.tmp` > geçerli `.bak` [kanonik ad dolu ya da `.tmp` izi varken] > yok; bilerek silinmiş kayıt = temiz başlangıç); yalnız testler için tek atımlık hata enjeksiyonu. |

### Reklam (M8.9-01 — `scripts/ads/`)

| script | işi |
|---|---|
| `ads/monetization_manager.gd` | `MonetizationManager` — tek üretim reklam soyutlaması: **yaş kapısı (TASK/043: bant → rota TFAT + derece → geri doğrulama → attach → UMP; UNKNOWN / UNDER_13'te eklenti / UMP / SDK yok; SDK sonrası bant değişimi oturumu reklamsız yapar)**, UMP rıza yaşam döngüsü, SDK başlatma, ödüllü durum makinesi (devam + refill + günlük sandık + günlük Hamur, talep bağlamı, önyükleme, geri çekilme), **geçiş reklamı durum makinesi + aktif süre saati + doğal mola (`try_show_interstitial`) + 60 sn tam ekran beklemesi (M8.9-02)**, banner yaşam döngüsü + yuva (5 yüzey), onboarding kapısı, olaylar. Main'in çocuğu (autoload değil); eklentisiz platformda yaratılmaz. |
| `ads/ad_backend.gd` | `AdBackend` — SDK'ya bakan soyut arayüz (düz tipli sinyaller). |
| `ads/admob_backend.gd` | `AdmobBackend` — eklentinin `Admob` düğümünü sarar; kimlikler `AdConfig`'ten; banner uyarlanabilir/alt/güvenli alan; TFCD/TFUA UNSPECIFIED, içerik G. *(TASK/042: yapılandırma init öncesi + geri okuma, kilit. TASK/043: yaş işlemi + en yüksek derece yaş bandından — `set_max_ad_content_rating` aynı kilitle; getter'lar attach öncesi güvenli.)* |
| `ads/ad_config.gd` | `AdConfig` — `addons/AdmobPlugin/android_export.cfg` → is_real + app/rewarded/banner kimlikleri + debug_geography; gerçek modda eksik/örnek kimlikte geçersiz. |
| `ads/ad_events.gd` | `AdEvents` — analitik olay dikişi (28 olay: ödüllü / banner / interstitial / günlük; abone/son 200); sağlayıcı sonraki milestone. |

### Oyun mantığı

| script | işi |
|---|---|
| `game/game_board.gd` | **En büyük dosya.** Kap geometrisi, drop kontrolü, merge çözümü, hedef takibi, taşma kontrolü, combo, sarsıntı, danger şeridi, level 1 tutorial ipucu. |
| `game/dumpling.gd` | Tek parça. Aynı tier çarpışınca `merge_requested` yayar. |
| `game/dumpling_visual.gd` | Görsel katman: tier sprite'ı, ±20° eğim, squash-stretch. |
| `game/tier_config.gd` | 8 tier'ın veri tablosu: yarıçap, isim, renk, merge puanı, yıldız eşikleri. |
| `game/level_data.gd` / `level_library.gd` | `.tres` level verisi + klasör tarayıcı. |
| `game/skin_data.gd` / `skin_library.gd` / `skin_entry.gd` | Koleksiyon parçası (Squishy; ad tarihsel "skin") kataloğu (final önizleme; render alanları TASK/044'ten beri inert) + klasör tarayıcı + oyuncuya göre durum view model'i (sahip / vitrinde / yuva, avatar, en son keşfedilen, rarity sayaçları). |
| `game/player_profile.gd` | `PlayerProfile` (TASK/044): Profil'in salt okunur istatistik / kimlik API'si — kanonik alanlardan türetir, yazmaz. *(`game/skin_visual.gd` TASK/044'te SİLİNDİ — gameplay skin render'ı emekli.)* |
| `game/drop_bag.gd` | Bag randomizer (§4.4). |
| `game/chest_system.gd` / `chest_reward.gd` | Sandık kurası ve ödül nesnesi; `ChestReward.title/description/note` oyuncuya Türkçe (M8.6-09), iç ad `rarity_name` değişmedi. |
| `game/shop.gd` | Fiyatlar ve satın alma. **Fiyat tune edilecek tek yer.** |
| `game/age_gate.gd` | `AgeGate` (TASK/043) — SAF yaş hesabı: takvim yaşı (13. / 18. yaş günü, 29 Şubat → 1 Mart), doğum tarihi → bant + geçiş günü, kayıttaki durumun doğrulanması + soğuk açılış geçişleri (fail-closed → UNKNOWN), owner yönlendirme tablosu (`ad_route`: TEEN → TEEN + T, ADULT → UNSPECIFIED + MA), bozuk saat denetimi. Autoload'a dokunmaz (release kapısı da derler). |
| `game/daily_reward.gd` | Günlük GİRİŞ ödülü + streak (GAME_DESIGN §5.4; ekonomi değişmedi). M8.9-02.1: onboarding false iken `claim_if_new_day` / `is_claimable` no-op (kayıt mutasyonu yok); `claimed_today()` / `view()` pencere görünümü. |
| `game/daily_rewards.gd` | `DailyRewards` (M8.9-02) — GÜNLÜK ÖDÜLLER modelinin tek yetkili noktası: yerel gün anahtarı + geri alma koruması, üç ayrı kota (ücretsiz sandık 1 / reklamlı sandık 2 / reklamlı +150 Hamur 1), tek transaction grant'ler, otomatik pencere işareti; RNG enjekte edilir. |
| `game/daily_chest_loot.gd` / `daily_chest_reward.gd` | `DailyChestLoot` (DAILY reçetesi: +15 garanti, %30 skin, 60/25/12/3, sahip olunmayan skin, tükenmişse +15 bonus) + `DailyChestReward` (değişmez sonuç). Level sandığı reçetesi (`chest_system.gd`) DEĞİŞMEDİ. |
| `game/missions.gd` | `Missions` (TASK/046, saf `RefCounted` — autoload DEĞİL): 6 kilitli görevin kataloğu + metin tablosu, katı gün anahtarı, pazartesi haftası, kayıt durumunun doğrulanması (`sanitize`), dönem (`for_day` — kayıttakinin gerisine düşmez), saf ilerleme / ödül (`advance`), görünüm satırları. Kayda yazmaz; tek mutasyon `SaveManager.record_mission_round` (round kesinleşmesinde). |
| `game/pop_effect.gd` | Merge parçacık patlaması. |

### UI

| script | işi |
|---|---|
| `main.gd` | Ekranlar (Ana Sayfa hub / Harita / Koleksiyon / Mağaza) ↔ oyun ↔ sonuç akışını bağlar. Kurallar burada DEĞİL. Alt sekme çubuğu M8.6-06'da kalktı. |
| `ui/home_screen.gd` | Ana sayfa: logo, streak, Hamur, "Oyna"; Günlük madalyonu → GÜNLÜK ÖDÜLLER penceresi (M8.9-02.1); TASK/044: üst-sol profil avatarı (eski ayarlar butonu), Koleksiyon madalyonunda en son keşfedilen Squishy. TASK/046: Günlük ile Mağaza arasında tek GÖREVLER girişi + "N/6" rozeti (`refresh_missions`, yalnız okur). |
| `ui/profile_screen.gd` | Profil (TASK/044): kimlik + 3 yuva vitrin + 6 istatistik + salt okunur güçler + koleksiyon kartı; dişli → Ayarlar. Kayda yazmaz. |
| `ui/avatar_button.gd` / `profile_showcase_slot.gd` / `profile_stat_tile.gd` / `collectible_stage.gd` | TASK/044 bileşenleri: yuvarlak candy avatar, vitrin yuvası, istatistik kutucuğu, rarity halesi + candy kaide + nefes alan sanat sahnesi (Koleksiyon detayı + Profil yuvası). |
| `ui/level_select.gd` | Harita: patika üstünde 10 düğüm + durumlar + açılış animasyonu + Sonsuz Mod kapısı (M8.5-12); banner yuvası varken dünya yuvanın üstünde biter (`_fit_world`, 16:9'da ≤ %4 dikey sıkıştırma — M8.9-02). |
| `ui/map_trail.gd` | Düğümleri bağlayan programatik candy patika (Catmull-Rom + noktalar, tamamlanmış/gelecek). |
| `ui/collection_screen.gd` | Koleksiyon (M8.6-06 → TASK/044 Collection V1): `ScreenTopBar` + sabit albüm başlığı (N/20, VİTRİN N/3, rarity sayaçları) + kaydırılan 3 sütun albüm + parça detayı (`CollectibleStage`; VİTRİNE EKLE / VİTRİNDEN ÇIKAR / AVATAR YAP / MAĞAZAYA GİT; dolu vitrinde açık değiştirme adımı). Yalnız kanonik `SaveManager.showcase_*` yazar; satın alma yok. |
| `ui/collection_skin_card.gd` | `CollectionSkinCard` — albüm kartı (Button; rarity halkası/hale, final sanat, kilit, VİTRİNDE plakası; TASK/044: seçim halkası / TAKILI yok). |
| `ui/shop_screen.gd` | Mağaza (M8.6-05): `ScreenTopBar` + kaydırılan içerik: **GÜNLÜK ÖDÜLLER kartı (M8.9-02, en üstte; HAZIR / N ödül kaldı / BUGÜNLÜK TAMAMLANDI, AÇ → pencere; onboarding bitmeden gizli)** + 2 sütun kart gridi + onay penceresi (`UiKit.modal_frame`) + candy geri bildirim plakası. Satın alma yalnız kanonik yoldan. |
| `ui/shop_power_card.gd` | `ShopPowerCard` — güç ürün kartı (candy kuyu + owner sanatı, amaç, fiyat, SATIN AL, stok rozeti; yetmiyor/başarı durumları). |
| `ui/shop_skin_card.gd` | `ShopSkinCard` — koleksiyon parçası ürün kartı (SkinSwatch önizleme, rarity halkası/hale/pırıltı, fiyat veya SAHİPSİN + "Koleksiyonunda"; TASK/044: TAKILI yok). |
| `ui/round_result.gd` | Round sonu (M8.6-09 production yeniden kurulum, shell v2 `hero` + kaydırılan gövde + sabit altlık): WIN / FAIL / ENDLESS modları, yıldız reveal → ödül kartı reveal, SKOR/HEDEF/HAMUR çipleri, HARİTA / TEKRAR DENE rotaları; yalnız sunar, kayda yazmaz. **A36'da doğrulandı (M8.6-09.1)**. |
| `ui/result_reward_card.gd` | `ResultRewardCard` — Hamur / parça (gerçek final sanat, YENİ SQUISHY + "keşfedildi!") / geri düşüş / teselli kartı; dokunma hedefi değil (M8.6-09; metin TASK/044). |
| `ui/result_star_strip.gd` | `ResultStarStrip` — yay üstünde üç owner yıldızı, yumuşak lavanta kontur (türev `icon_star_empty_soft`), pop + pırıltı reveal (M8.6-09). |
| `ui/reward_gem.gd` | Sandık ödül görseli: kapalı → açılış → rarity katmanları; `setup(reward, size)`, reveal sonrası `settle()` (M8.6-09). |
| `ui/skin_swatch.gd` | Skin önizlemesi (M8.5-13): final önizleme sanatı + rarity parıltısı; kilitli = `reveal_locked` ile final sanat + kilit (Koleksiyon/Mağaza, M8.6-06) ya da silüet; varsayılan = orijinal dumpling. |
| `ui/ui_icons.gd` | HUD ikonlarının tek tanımı, BBCode `[img]` üretir. |
| `ui/ui_type.gd` | Tipografi rol adları (M8.5-09). |
| ~~`ui/ui_palette.gd`~~ | **Silindi (M8.6-10):** M8.5-10 tasarım sistemi; tek kaynak artık `ui_tokens.gd` + `ui_kit.gd`. |
| `ui/ui_motion.gd` | Mikro-etkileşimler: basış, pop, pencere açılışı, sekme geçişi, toast (M8.5-10). |
| `ui/ui_toggle.gd` | Ayarlar anahtarı (M8.5-10); `UiKit.switch_toggle` ile LayerLab ray/topuz; ScrollContainer içinde kaydırma başlayınca basış ölçeğini bırakır (M8.6-08). |
| `ui/ui_kit.gd` | Production UI bileşen fabrikası (M8.6-01+): `modal_frame` (Mağaza onayı), **`modal_shell` iskelet v2** (kurdele/başlık+tepelik, oturmuş X, kaydırılan gövde + sabit altlık, tavan sistemi, `attach_dim_close`, `settings_row`) (M8.6-08). |
| `ui/streak_strip.gd` | `StreakStrip` — Günlük ödül seri şeridi: 7 düğüm (alınmış / bugün / gelecek), bağlantı çizgileri, gün numaraları, "+N" rozeti (M8.6-08). |
| `ui/settings_panel.gd` | Ayarlar penceresi (M8.6-08 yeniden kurulum, shell v2): ses efektleri, titreşim (M8.5-15), gizlilik (gövdede açılır, taşmaz; metin M8.9-01'de AdMob'u anlatır), **"Gizlilik seçenekleri" satırı yalnız UMP form sunuyorsa** (M8.9-01), sürüm; yalnız `set_sfx_enabled` / `set_haptics_enabled` yazar. *(TASK/043: "Yaş bilgisi → Güncelle" satırı yalnız TEEN / ADULT'ta — nötr yaş ekranını yeniden giriş kipinde açar; gizlilik metnine yaş cümlesi.)* |
| ~~`ui/daily_reward_popup.gd`~~ | **Silindi (M8.9-02.1):** M8.6-08 giriş ödülü penceresi; işlevi birleşik GÜNLÜK ÖDÜLLER penceresinin üst bölgesine taşındı (`StreakStrip` yeniden kullanılıyor). |
| `ui/daily_rewards_popup.gd` | GÜNLÜK ÖDÜLLER penceresi (M8.9-02 / 02.1, shell v2 kurdele + X) — oyuncunun TEK günlük ödül penceresi: üst bölge "N. GÜN · +15 HAMUR · ALINDI" + seri şeridi (giriş ödülü pencereden önce `DailyReward` ile yazılmış gelir; ilk açılışta kutlama), üç seçenek kartı (ücretsiz sandık AÇ / +150 Hamur REKLAM İZLE / reklamlı sandık REKLAM İZLE), durum rozetleri, sağlayıcı notları, in-modal reveal (RewardGem → +N HAMUR → YENİ SKİN kartı hale payıyla, DEVAM). Ödül vermez, kayda yazmaz; yalnız sinyal. |
| `ui/age_gate_panel.gd` | Yaş ekranı (TASK/043; **TASK/046.1 yeniden tasarım**, shell v2, tepeliksiz, opak kabuk zemini): GÜN / AY / YIL seçicileri + pencere içi seçim ızgarası yalnız 13+ tarih sunar (`AgeGate.selectable_*`), hazır tarih yok, onay adımı (DÜZELT / ONAYLA, tek gönderim), tek nötr hata; ZORUNLU (geri çıkmaz) / YENİDEN GİRİŞ kipleri; seçim yalnız bellekte, dışarı yalnız `resolved(band, transition)` (TEEN / ADULT). *(TASK/043'ün tuş takımı emekli.)* |
| ~~`ui/age_restricted_screen.gd`~~ | **Silindi (TASK/046.1):** TASK/043'ün 13 altı nötr kısıt / ÇIKIŞ ekranı (katman 30); normal girişten ulaşılamıyordu, eski UNDER_13 kaydı artık UNKNOWN + yeniden sorma. |
| `ui/pause_menu.gd` / `ui/bonus_chest_info.gd` | Mola ve Bonus Sandık bilgi pencereleri — shell v2, oturmuş X (M8.6-08 cila; eylemler/kural değişmedi). |
| `ui/missions_overlay.gd` / `ui/mission_card.gd` | GÖREVLER penceresi (TASK/046, Main'e ait, katman 12, shell v2 kurdele + X): hero "N / 6" + ray + otomatik ödül notu, GÜNLÜK / HAFTALIK bölümleri (sabit yenilenme ipuçları), 3'er `MissionCard` (metrik kuyusu, metin, TAMAMLANDI çipi, ray + "x / y", Hamur ödülü, 3 px durum halkası); talep butonu yok, kayda yazmaz. |
| ~~`ui/candy_button.gd`~~ | **Silindi (M8.6-10):** M8.5-08 candy pill CTA'ları; son kullanıcıları Devam + Refill `UiKit`e geçti. Dokuları (`cta_button_*`, `power_button_*`, `panel_candy.png`) ve M8.5 ikon klasörü (`ui/icons/`) de kaldırıldı. |
| `ui/revive_offer.gd` | Devam (revive) teklifi (M8.6-10 production yeniden kurulum, shell v2 + tepelik): DEVAM HAKKI plakası (iki kalp, `icon_heart_revive`), DEVAM ET kahraman / BİTİR; sağlayıcı yokken CTA pasif + sebep; talep kilidi; yalnız sinyal yayar, hak vermez. |
| `ui/power_refill.gd` | Stok 0 refill penceresi (M8.6-10 production yeniden kurulum, shell v2 kurdele + X): güç sanatı kahraman + STOK ×0, ÖDÜLLÜ REKLAM / HAMURLA AL kartları, KAPAT; fiyat `PowerUpEconomy`, kota `RewardedPolicy`; yalnız sinyal yayar, stok/Hamur/kota'ya dokunmaz. |

### Geliştirme araçları (`tools/` — oyun çalışırken hiçbiri kullanılmaz)

| araç | işi |
|---|---|
| `bot_runner.gd` + `bot_brain.gd` | **Headless denge testi.** Gerçek `GameBoard`'u gerçek fizikle oynatır. Bu projedeki tüm kazanma oranı ölçümlerinin kaynağı. |
| `fake_ad_backend.gd` | `FakeAdBackend` — reklam SDK'sı test çifti (M8.9-01): çağrı sayar, her SDK olayı testten elle tetiklenir. Export dışı. |
| `monetization_test.gd` + `.tscn` | **Headless monetizasyon testi** (M8.9-01/02, 191 kontrol): yapılandırma korumaları (interstitial kimliği fail-closed), olay dikişi (28), kaynak taraması, rıza akışı/hataları/gizlilik seçenekleri, ödüllü başarı + callback güvenliği (çift/geç/eski/iptal/yanlış güç) + hata/geri çekilme/zaman aşımı + arka plan, banner yuva/5 yüzey/gezinme/hata/onboarding, Main entegrasyonu (gerçek pencereler + board + kota + Ayarlar). Kaydı byte'ı geri koyar. |
| `daily_rewards_test.gd` + `.tscn` | **Headless günlük ödüller testi** (M8.9-02/02.1, 134 kontrol): onboarding migration'ı, gün anahtarı (ileri/geri/aynı gün), üç kota + tek transaction + bağımsızlık, loot (4000 seed'li kura), Mağaza kartı + pencere + reveal, Main + sahte SDK (talep/çift/iptal/hata/gün değişimi), birleşik giriş ödülü (yeni gün / yeniden açılış / ertesi gün / kırık seri / geri saat / bağımsızlık / onboarding false no-op), otomatik pencere, onboarding bastırması. Kaydı byte'ı geri koyar. |
| `tutorial_test.gd` + `.tscn` | **Headless ilk açılış tutorial'ı testi** (M8.10, 149 kontrol): yeni kayıt açılışında otomatik tutorial, WELCOME girdi kapısı, FIRST_DROP clamp'i + yalnız geçerli bırakmanın ilerletmesi, MATCH_DROP hizalaması, GERÇEK merge şartı (T2 + skor + merge sayacı + tutorial T2'si board'da kalıyor + torba tüketilmedi), açıklama adımlarında girdi/dondurma + "coach kartı hedefi örtmüyor", tamamlanma atomikliği (iki alan tek transaction, çift tamamlanma yazmıyor), ilk gün bastırmasının tamamı + ertesi gün +15/seri, ATLA'nın aynı kanonik yoldan geçmesi, Android geri onayı (mola açılmıyor, kabuğa düşülmüyor), yarıda kapanma → baştan, onboarded oyuncunun Level 1 tekrarında tutorial görmemesi, monetizasyon ertelemesi (round ortası yuva 0 + rıza başlamadı → kabuk geçişinde açılıyor). Kaydı byte'ı geri koyar. |
| `tutorial_shots.gd` + `.tscn` | **M8.10 tutorial çekimleri** (pencereli): gerçek `main.tscn` + gerçek board üstünde 10 durum (karşılama, ilk bırakma, eşleştirme, merge kutlaması, hedef/tehlike/güçler spot'ları, hazırsın, geri onayı, tamamlanma sonrası); her adımda kart/hedef dikdörtgenleri, örtüşme, güvenli alan ve banner yuvası ölçümü stdout'ta. Adım beklemesi SÜREYE değil DURUMA bağlı. `--headless` ile çalışmaz. |
| `interstitial_test.gd` + `.tscn` | **Headless geçiş reklamı testi** (M8.9-02, 60 kontrol): 899/900 saat, dışlanan anlar, doğal mola / hazır değil / gösterim → saat 0 / callback bir kez, 60 sn bekleme, ödüllü dışlaması, yükleme/gösterim hataları, onay zaman aşımı, süresi dolma, Main: sonuç tam bir kez. Kaydı byte'ı geri koyar. |
| `daily_ads_shots.gd` + `.tscn` | **M8.9-02 düzen çekimleri** (pencereli): Harita/oyun + banner yuvası (orta ve yeni oyuncu), Mağaza günlük kartı, GÜNLÜK ÖDÜLLER penceresi (hazır/karışık), reveal (Hamur / Common / Legendary), yuvasız referanslar; ölçümler stdout'ta. `--headless` ile çalışmaz. |
| `ads_device.gd` + `.tscn` | **Reklam cihaz kapısı sürücüsü** (M8.9-01.1 / M8.9-02.2): gerçek `main.tscn`'i gerçek ya da sahte arka uçla kurar, `user://qa_cmd.txt` komut kanalı + `user://qa_state.txt` durum dosyası (reklam/ödüllü/geçiş/banner/günlük/pencere/harita/oyun dikdörtgenleri ekran px, son olaylar). M8.9-02.2 QA komutları: onboarding, login, dailyq, dayclock, fresh, relaunch, daily_open/close/reveal, clock (aktif süre enjeksiyonu), inter_block, fake_i*. **Yalnız ayrı QA paketinde** (`…squishymerge.qa`); üretim export'u `tools/*` hariç — üretim sabitlerine dokunmaz. |
| `ui_shots.gd` + `ui_shots.tscn` | **Production UI kabuğu çekimleri** (M8.5-10): dört sekme, ayarlar, en kötü durum, oyun ekranı; üç ölçü. `--headless` ile çalışmaz. |
| `ui_smoke_test.gd` + `ui_smoke_test.tscn` | **Headless UI davranış testi** (57 kontrol, TASK/044): ayar anahtarı, onay diyaloğu, geri tuşu, koleksiyon detayı + VİTRİNE EKLE. |
| `profile_test.gd` + `.tscn` | **Profil testi** (TASK/044, 135 kontrol): üç ilerleme durumu + eski kayıt, rotalar (avatar / dişli / yuvalar / geri), oyun içi ayarlar + mola, gerçek round sayaçları, sahte arka uçla banner yüzeyi + Profil dişlisinden TASK/043 yaş yeniden girişi, 7 pencere + A36. |
| `collection_rework_test.gd` + `.tscn` | **Skin emekliliği + vitrin kuralları testi** (TASK/044, 64 kontrol): `equipped_skin` göçü, kanonik gameplay (kaynak taraması dahil), vitrin kuralları + tek yazma, oyuncu dili, dondurulmuş ekonomi. |
| `save_persistence_test.gd` + `.tscn` | **Çökmeye dayanıklı kayıt testi** (TASK/045.1): işlem (normal / üzerine / ×40 / ~1 MB / Unicode / bayt-aynı biçim / ara dosya yok), her aşamada hata + süreç ölümü enjeksiyonu, kurtarma matrisi, SaveManager entegrasyonu (yeni oyuncu, şema, TASK/044–045 göçleri, başarısız kayıt, çökmeden kurtarma, bozuk kayıt). YALNIZ test yolu — sahibin kaydına dokunmaz. |
| `power_input_test.gd` + `.tscn` | **Hedefli güç dokunuş tüketimi testi** (TASK/045.1): Bomba / Büyütücü parmak / fare / kod yolu (güç bir kez, stok bir kez, bırakış düşürmez, sonraki dokunuş düşürür), T7→T8, geçersiz hedef, iptal, sürükleme, hızlı / aynı kare / iki parmak, kayıp bırakış, duraklama, stok 0, anında güçler, Main + 300 ms yatışma. Test yolu. |
| `daily_popup_gate_test.gd` + `.tscn` | **Günlük pencere ↔ Koleksiyon detayı kapısı testi** (TASK/045.1): detay açıkken sekme / kabuk tazeleme, öne dönüş, gün dönümü, değiştirme adımı, Profil vitrini → detay; due kalır, sonraki fırsatta açılır; TASK/045 kapısı aynen. Test yolu. |
| `settings_input_test.gd` + `.tscn` | **Ayarlar geri girdi odağı / dizi bazlı yatışma testi** (TASK/045.2): cihaz sırasıyla parmak olayları (öykünen fare önce) + pencere GO_BACK bildirimi; oyun içi dişli → GERİ / KAPAT / karartma → ilk dokunuş (nişan, sürükleme, tek drop), parmak / indeks / masaüstü fare, pencerede başlayan dizi (sonrası dahil) + iptal + kaybolan bırakış, iki parmak (bölünmez / tamamen yutulur), çift dokunuş, Bomba / Büyütücü, Profil dişlisi, Mola / Refill / Devam, Koleksiyon / Başarımlar / Unvanlar / Günlük / Sandık. Test yolu. |
| `missions_test.gd` + `.tscn` | **Günlük / haftalık görev çekirdek testi** (TASK/046, 136 kontrol, yalnız test yolu): katalog, gün / hafta (1200 gün kaba kuvvet), doğrulama, dönem, ilerleme, göç / kurtarma (`.tmp` / `.bak`), saat (geri alma, bozuk saat), gerçek Main round akışı (kazanma / kayıp / tekrar / sonsuz / terk / yeniden başlatma / süreç ölümü / yinelenen kesinleştirme / eski board / tek yazma), tutorial round'u, sahte arka uçla reklam yok + sonuç banner'sız, kaynak sözleşmesi. |
| `missions_ui_test.gd` + `.tscn` | **GÖREVLER arayüz testi** (TASK/046, 139 kontrol, yalnız test yolu): Ana Sayfa girişi + N/6, pencere içeriği / durumları, TAMAMLANDI çipi + durum halkası, geri / X / karartma / gerçek parmakla hızlı çift dokunuş, kapılar + kendiliğinden kapanış, 5 görünüm + A36 üst payı (kırpma / çakışma / maskot pikseli), uzun metin, dil, banner yuvası, yazma girişimi dedektörü, öne dönüşte gün dönümü. |
| `missions_shots.gd` + `.tscn` | **GÖREVLER çekimleri** (TASK/046, pencereli, test yolu): 14 kare — Ana Sayfa 3 durum, pencere 7 durum (uzun metin provası dahil), 4 gerçek round sonucu; `-- <dir> [GxY] [safe=61] [only=H|M|R]`, piksel boyutu doğrulanır. |
| `missions_economy.py` | Görev Hamur'unun mevcut haftalık gelire eki (TASK/046, deterministik; `shop_economy.py` varsayımları; koleksiyon eksik / tamam iki tablo). Ayar yapmaz. |
| `profile_shots.gd` + `.tscn` | **Profil çekimleri** (TASK/044): yeni / orta / geç (üst + kaydırma sonu), 0 / 3 vitrin, eski kayıt, Profil'den Ayarlar, Ana Sayfa avatarı, yuva → detay. `--headless` ile çalışmaz. |
| `secondary_modal_ui_test.gd` + `.tscn` | **Headless ikincil pencere testi** (M8.6-08 / M8.9-02.1, 100 kontrol): shell v2 iskeleti (oturmuş X, gövde/altlık sınırları, tavan + kaydırma, karartma), Ayarlar (kanonik yazma yolu, taşma regresyonu 5 yapılandırma), Günlük = birleşik GÜNLÜK ÖDÜLLER (claim pencereden önce tam bir kez, üst bölge, yeniden açılış +15 yok, kapanış yolları, 540×960), Mola/Sandık (hiyerarşi, z-order, rota). Kaydı byte'ı geri koyar. |
| `secondary_ui_shots.gd` + `.tscn` | **İkincil pencere çekimleri** (M8.6-07/08): 48 durum × pencere boyutu + A36 simülasyonu; `groups=` ile alt küme. `--headless` ile çalışmaz. |
| `result_ui_test.gd` + `.tscn` | **Headless round sonu testi** (M8.6-09, 226 kontrol): yapı (eski iskelet yok, kayda yazma çağrısı yok), kazanma / kayıp / ödül kartları / dil taraması, 6 ödül taşma + sürükleme, kayıt güvenliği + gerçek kayıp yolu (teselli tam bir kez), rotalar + Android geri, L10 / Sonsuz, devam sırası, 5 yapılandırma, performans. Kaydı byte'ı geri koyar. TASK/046: görev hapı + TASK/045 hapları birlikte, en uzun şerit her boyutta + A36, gerçek round TEST yolunda (265 kontrol). |
| `result_shots.gd` + `.tscn` | **Round sonu çekimleri** (M8.6-09): 31 kare (kazanma/kayıp, yıldızlar, 4 rarity Hamur + skin, geri düşüş, çoklu/5/6 ödül + kaydırma, L10, Sonsuz, retry/Harita basış) × pencere boyutu + A36; `only=` ile alt küme. `--headless` ile çalışmaz. |
| `result_device.gd` + `.tscn` | **Cihaz kapısı sürücüsü** (M8.6-09.1): `result_shots`'ı miras alır, cihazda gerçek çözünürlükte her durumda DURUR (`user://qa_cmd.txt` komut kanalı, `user://qa_state.txt` durum/istatistik: kart sayısı, kaydırma, kare profili, yıldız/kart ms'leri, kayıt özeti). Komutlar: start/next/stats/scroll_top/scroll_end/dup_show/dup_finish/timeline/quit. Ek durumlar: D4 (4 ödül), R1/R2 (gerçek kanonik kazanma ve gerçek taşma → Devam → sonuç). **Ayrı pakette** (`…squishymerge.qa`) export edilir — owner kaydına dokunamaz. |
| `make_result_art.py` | Owner kontur yıldızından yeniden boyanabilir `icon_star_empty_soft.png` türetir (M8.6-09). |
| ~~`make_pack_icons.gd`~~ | **Silindi (M8.6-10):** Free Casual GUI ikon türetmesi; çıktı klasörü de kaldırıldı. |
| `revive_refill_ui_test.gd` + `.tscn` | **Headless Devam + Refill testi** (M8.6-10, 266 kontrol): kaynak taraması (eski iskelet / yazma çağrısı yok, emeklilik kanıtı), devam durumları + işlem sınırı (talep tam bir kez, UI hak vermez, callback tam bir kez, sağlayıcısız pasif), Android geri + BİTİR→sonuç sırası, dört güç + kanonik fiyat + Hamur, ödüllü (sağlayıcı yok / bağlı / kota dolu / DÖRT gücün toplamı), satın alma tek transaction + çift basış, kapanış yolları (X/KAPAT/karartma/geri) kayda yazmaz, 5 yapılandırma, performans. Kaydı byte'ı geri koyar. |
| `revive_refill_shots.gd` + `.tscn` | **Devam + Refill çekimleri** (M8.6-10): 17 durum (devam 2/2, 1/2, sağlayıcı yok, talep, 0/2, BİTİR geçişi, sonuç; refill Bomba yeterli/yetersiz, Büyütücü, Sarsıntı, Temizleyici, ödüllü uygun/kota dolu/sağlayıcı yok, SATIN AL basış/başarı) × pencere boyutu + A36; `only=` ile alt küme. `--headless` ile çalışmaz. |
| `make_revive_art.py` | Owner kanatlı-kalp tepeliğinden izole kalp `icon_heart_revive.png` türetir (M8.6-10). |
| `audio_test.gd` + `audio_test.tscn` | **Headless ses + titreşim davranış testi** (M8.5-15, 45 kontrol): eşleme, RNG izolasyonu, soğuma/tavan/öncelik, ayar kalıcılığı, haptik politikası. Kaydı kendi yedekler. |
| `audio_qa.gd` + `audio_qa.tscn` | **Ses/titreşim QA sahnesi** (pencereli): her olay, rarity, güç, titreşim seviyesi, spam/stres düğmeleri; kanal ve atılan çağrı sayaçları. Production navigasyonunda yok. |
| `audio_probe.gd` | Eşlenmiş her ses dosyasının süre / tepe dBFS / RMS / sessizlik / kırpma ölçümü (AudioEffectCapture, headless). |
| `make_sfx.gd` | GEÇİCİ sentez SFX üretici (22 dosya, deterministik). Final örnek gelince gereksizleşir. |
| `contact_audit.py` | **Temas geometrisi denetimi** (M8.5-11): alfa bbox, gövde silueti, collider, dünya boşlukları; `--fit` kalibrasyon tablosu. |
| `contact_rig.gd` + `contact_rig.tscn` | **Deterministik temas/yığın rig'i**: lineup, pile, wall, large, stress; settle/yükseklik/merge/kaçan/overlap. |
| `feel_shots.gd` + `feel_shots.tscn` | Game-feel kare dizileri: düşüş, iniş, merge, zincir, tehlike, hedef, tier 8. |
| `map_shots.gd` + `map_shots.tscn` | Harita QA çekimleri: owner / orta / sıfır kayıt (bellekte), açılış animasyonu. |
| `screenshot_runner.gd` + `screenshot_test.tscn` | Ekran görüntüsü üretir (merge, combo, skor pop, tutorial, danger, sandık, 4 sekme, kilitli harita). İkinci argümanla pencere ölçüsü verilebilir (`540x1170` → dar/uzun telefon testi). **`--headless` ile çalışmaz.** |
| `make_owner_sprites.gd` | Owner'ın ChatGPT görsellerini hazırlar: kırpma, küçültme, adaptive icon düzeltmeleri, `icon_sheet.png` parçalama. |
| `make_ui_sprites.gd` | Wenrexa UI paketinden tema sprite'ları. |
| `make_fx_sprites.gd` | Kenney Particle Pack'ten efekt parçacıkları. |
| `make_placeholder_sprites.gd` | Kenney Shape Characters (**artık kullanılmıyor**). |
| `tier_geometry.py` | Tier yarıçapı aday daraltma (alan modeli). |
| `star_thresholds.py` | Yıldız eşiği Monte Carlo. |
| `shop_economy.py` | Mağaza ekonomisi simülasyonu. |

---

## 6. Asset envanteri

Detay için **`assets/visual/CREDITS.md`** (uzun ve teknik olarak değerli) ve
`assets/audio/CREDITS.md`.

### Owner'ın kendi ürettiği (ChatGPT) — telifi owner'da

| ne | adet | nerede |
|---|---|---|
| Dumpling karakterleri (8 tier) | 8 | `assets/visual/dumpling_tier1..8.png` |
| Sandık (kapalı/açık) | 2 | `assets/visual/ui/chest_*.png` |
| UI asset'leri | 7 | harita zemini, logo, kilitli skin silueti, tehlike şeridi, rozet, banner, tutorial pozu |
| Adaptive icon katmanları | 2 | `assets/visual/icon/adaptive_*_432.png` (+ türetilmiş `launcher_main_192.png`) |
| HUD ikonları (`icon_sheet.png`'den kesildi) | 7 | dolu/boş yıldız, Hamur, kilit, taç, alev, bayrak |

**Ham kaynakları artık repoda:** `_visual_source/chatgpt_characters/` ve
`_visual_source/chatgpt_ui/`. Bu klasör 2026-09-09'da bilinçli olarak
gitignore'dan çıkarıldı — **başka hiçbir yerde yedeği olmayan** orijinaller
böylece GitHub'da yedeklenmiş oluyor.

### CC0 üçüncü taraf

| kaynak | ne | durum |
|---|---|---|
| **Wenrexa** — "Assets FREE: UI Casual Game Interface" | Buton + panel teması | ✅ kullanımda (`ui_theme.tres`) |
| **Kenney** — Particle Pack | fx parçacıkları (dot, sparkle, burst, ring) | ✅ kullanımda |
| **Kenney** — UI Pack | yıldızlar | ⚠️ **artık kullanılmıyor** (owner'ın sheet'iyle değiştirildi), dosyalar geri dönüş için duruyor |
| **Kenney** — Shape Characters | eski placeholder karakterler | ❌ kullanılmıyor |
| **Kenney** — ses paketleri | 5 SFX (`kenney_*`) | ✅ kullanımda, owner kulakla onaylayacak / değiştirecek |
| **Sentez** — `tools/make_sfx.gd` | 22 SFX (`sfx_*.wav`) | ⚠️ GEÇİCİ, kulakla doğrulanmadı — final örnekler bekleniyor (`docs/AUDIO_ASSET_REQUIREMENTS.md`) |

> Lisans notu: Wenrexa paketinde lisans dosyası yok; CC0 bilgisi itch.io
> ürün sayfasındaki "Asset license" alanından geliyor. Kenney paketlerinde
> `License.txt` var.

### Henüz entegre EDİLMEMİŞ owner asset'leri

`_visual_source/chatgpt_ui/` altında duruyor, hiçbir yerden referans
verilmiyor:

| dosya | ne olabilir |
|---|---|
| `bg_scene.png` (1.7 MB) | Tam sahne arka planı — oyun tahtasının arkasına konabilir |
| `panel_frame.png` (932 KB) | Panel çerçevesi — `ui_theme.tres`'teki Wenrexa panelinin yerine |
| `btn_normal_a.png`, `btn_normal_b.png`, `btn_disabled.png` | Buton durumları — Wenrexa butonunun yerine |

**Bunlar için bir talimat gelmedi.** Kap duvarları hâlâ düz renk
(`Color("6b5a52")`), oyun arka planı düz koyu gri.

---

## 7. Bilinen açık sorunlar ve teknik borç

### Tasarım/ürün

| # | sorun | durum |
|---|---|---|
| 1 | **Geç oyun Hamur enflasyonu** (§4.8). M8.5'te mağaza çalışır hâle geldi (medyan oyuncu koleksiyonun ~yarısını satın alıyor) ama koleksiyon hâlâ 6-17 günde doluyor ve sonrasında Hamur'un alıcısı kalmıyor. | 🔴 **Owner kararı bekliyor.** Fiyat/gelir değiştirilmedi. |
| 2 | **L8 ve L10 bitirilince her zaman 3★** veriyor (§4.7). | 🟡 Kasıtlı, kabul edildi. |
| 3 | Görsel yol haritası. | 🟢 **M8.5-12'de yapıldı** (§4.15): düğümler patikayı takip ediyor, candy patika, açılış animasyonu, Sonsuz Mod kapısı. |
| 4 | Açılmış skin'ler hâlâ placeholder (renkli daire). Skin başına ayrı görsel owner'dan gelmedi; sadece kilitli silüet gerçek asset. | 🟡 Asset bekliyor. |
| 5 | Sandık görseli her rarity'de aynı; Common-Legendary farkı yalnızca efekt katmanlarında. | 🟢 Owner'a soruldu, şimdilik böyle kalsın denmedi/denildi — düşük öncelik. |

### Teknik

| # | sorun | durum |
|---|---|---|
| 6 | **`danger_stripe.png` seamless değil** (kenar farkı ort. 0.16, en kötü 1.20). Bu yüzden tile edilmiyor, kap genişliğine **tek parça geriliyor**. Kap genişliği level'a göre değiştiği için germe zaten gerekliydi, ama yeni bir şerit gelirse aynı kısıt geçerli. | 🟡 Kabul edilmiş kısıt. |
| 7 | **Duvar dokusu yok.** Kap duvarları düz `Color("6b5a52")` dikdörtgen. `bg_scene.png`/`panel_frame.png` entegre edilirse buraya da doku gelebilir. | 🟡 Yapılmadı. |
| 8 | **`map_background.png` 1.8 MB** — tek başına kalan tüm görsellerden büyük. Fotoğrafik illüstrasyon PNG'de kötü sıkışıyor. Import ayarında lossy (WebP) yapılabilir. | 🟡 M9 APK bütçesi notu. |
| 9 | **Uzun ekranda oyun tahtasının altında boş alan.** `FLOOR_Y` sabit 1180, viewport 9:19.5'te 1560'a çıkıyor. Kap yukarıda kalıyor. | 🟢 **M8.6-02'de çözüldü:** `GameplayLayout` bölge sözleşmesi (HUD / BOARD / STRIP / BANNER seam) + kamera ile referans fizik penceresini BOARD bölgesine sığdırma (zoom ≤ 1.2, fizik değişmedi); 720×1280 / 1560 / 1440 / 1600 + banner 0/100 çakışmasız (`tools/gameplay_shell_test`, 146). Bkz. docs/UI_VISUAL_SYSTEM.md §13. |
| 10 | **`tools/` ve `_visual_source/` export'ta filtrelenmeli.** Aksi hâlde AAB'ye ~73 MB gereksiz veri giriyor. `_visual_source/` artık repoda olduğu için bu **daha kritik**. | 🔴 **M9'da mutlaka yapılacak.** |
| 11 | Proje ikonu hâlâ Godot'un varsayılan robotu (`config/icon="res://icon.svg"`). Kompozit ikon üretildi ama `project.godot`'a bağlanmadı. | 🔴 M9/M10 öncesi. |
| 12 | `_visual_source/` içinde 4 zip (~17.6 MB) var ve bunlar yanlarındaki açılmış klasörlerin **birebir kopyası**. Repo boyutunun dörtte biri. | 🟡 Silinebilir; git geçmişinden çıkarmak history rewrite gerektirir. |
| 13 | Kazanma/kaybetme jingle'ı kulakla doğrulanmadı (M6 blokajı, hiç kapanmadı). | 🟡 Owner playtest'inde kontrol edilmeli. |
| 15 | **AdMob eklentisi UMP boşluğu (M8.9-01) — ÜRETİM ENGELİ:** godot-admob v6.0 `canRequestAds` / `getPrivacyOptionsRequirementStatus` / `showPrivacyOptionsForm` sarmaz (SDK'dan türeyen eşdeğerler kullanılıyor, PRIVACY_CONSENT §4) VE `debug_geography` cihazda uygulanamıyor (upstream #120: Java `Integer` bekliyor, Godot `Long` gönderiyor; v7.0 kaynağında düzeltilmiş ama v7.0 Godot 4.7) → EEA rıza formu A36'da gösterilemedi. Üretim öncesi küçük AAR yaması ya da upstream PR. | 🔴 Owner/ChatGPT kararı. |
| 17 | **Ödül callback'i reklam kapanmadan geliyor (A36 gözlemi, M8.9-01.1):** Godot AdActivity arkasında çalışmaya devam ettiği için `grant_revive` / `grant_rewarded_power` (ve M8.9-02 günlük reveal'i) reklam hâlâ üstteyken uygulanıyor; veri doğru ama "Devam!" flaşı, +1 pop ve MEDIUM titreşim reklamın arkasında oynuyor. İstenirse grant kapanışa ertelenebilir. | 🟡 UX; owner kararı, değişiklik yapılmadı. |
| 18 | **İki günlük pencere (M8.9-02):** günlük GİRİŞ ödülü (M8.6-08) ve GÜNLÜK ÖDÜLLER günün ilk açılışında art arda açılıyordu. | 🟢 **M8.9-02.1'de birleştirildi:** tek pencere, eski pencere silindi, giriş ödülü üst bölgede; onboarding false iken giriş işlemi de kapalı. |
| 19 | **16:9'da oyun kabı banner ile −%10 (M8.9-02):** 720×1280'de kamera zoom 0,971 → 0,874 (T1 çapı 42,7 → 38,5 tuval px) — aralıklar daraltıldıktan sonra kalan tek kaldıraç. A36'da L1–L3 değişmez, L4+ ≤ −%6. Fizik değişmedi. | 🟡 Kabul edildi; cihazda okunurluk kontrolü A36 kapısında. |
| 16 | **Gradle debug APK 102 MB** — `android_source` şablonunun debug `libgodot_android.so` 75 MB (strip'siz). Release/AAB'de küçülür; prebuilt debug 45 MB idi. | 🟢 Beklenen; M9'da release boyutu ölçülecek. |
| 14 | **Gameplay/tooling RNG coupling.** Kamera sarsıntısı `_process` içinde `randf_range` çağırıyordu — görsel ama `drop_bag.shuffle()` ile aynı global RNG akışını tüketiyor ve fizik kareleri arasında değişken sayıda çalışıyordu; `bot_runner` tekrarlanamazdı. | 🟢 **M8.5-11'de kaldırıldı:** sarsıntı `_fx_rng` kullanıyor; global RNG'yi artık yalnızca drop bag tüketiyor. Bot hâlâ seed'siz (rastgele başlangıç); seedli harness istenirse `seed()` eklemek yeter, drop_bag'e dokunmak gerekmiyor. |

---

## 8. Kalan işler

### M8.9 — Monetizasyon (AdMob) — kalanlar

`M8.9-01` temel main'de (33b6382, A36'da doğrulandı); `M8.9-02` genişletme
(Harita/oyun banner'ı, geçiş reklamı, günlük ödüller, onboarding dikişi) dal
`task/034`'te, test reklamı. Kalan:

1. **Owner: AdMob hesabı** — uygulama kaydı (App ID), rewarded + banner +
   interstitial reklam birimleri, Privacy & messaging GDPR mesajı →
   `addons/AdmobPlugin/android_export.cfg [Release]` + `is_real=true` (yalnız
   release adımında).
2. **Owner/ChatGPT: kitle politikası** — Play "Hedef kitle" beyanı ↔ TFCD /
   TFUA / içerik derecesi (PRIVACY_CONSENT §6). *(Ürün kitlesi sonra kapandı:
   owner kararı 2026-09-25 — 13+ genel kitle, `general_13_plus`; TFCD/TFUA/derece
   değişmedi. 13–17 genç reklam işlemi / yargı bölgesi uyumu AÇIK — aşağıda M9.)*
3. ~~**A36 test reklamı cihaz kapısı**~~ → **GEÇTİ (M8.9-01.1, 2026-09-21)**;
   rıza formu #120 yüzünden gösterilemedi (yukarıda §7 #15), uçak modu owner'ın
   günlük telefonunda denenmedi (gerçek no-fill + masaüstü testleri kapsıyor).
4. ~~**M8.9-02 A36 cihaz kapısı**~~ → **GEÇTİ (M8.9-02.2, 2026-09-22;
   ADS_SYSTEM §14):** gerçek test interstitial'ı doğal molada (gösterim →
   sonuç bir kez, saat yalnız SDK gösteriminde sıfır, 60 sn bekleme; uygun
   değil / bekleme / hazır değil / gösterim hatası yollarında sonuç hemen),
   Harita/oyun banner'ı, günlük reklamlı sandık ×2 + +150 + ücretsiz sandık,
   otomatik pencere tam bir kez, onboarding false bastırması, gün değişimi,
   arka plan, logcat temiz, PSS düz; owner görsel kontrolü 5/5 PASS. Cihazda
   erişilemeyen tek yol: test ödüllü reklamında ödülden önce kapatma (Google
   test yaratıcısı ~8 sn'de ödül verip öncesinde kapatma göstermiyor) — sahte
   arka uçla kapsandı. `task/034` push edildi, **main'e merge kararı owner'da.**
5. ~~İki günlük pencere kararı~~ → M8.9-02.1'de birleştirildi (§7 #18).
6. **Analitik sağlayıcı** — `AdEvents` dikişine bağlanır (28 olay hazır).
7. ~~Eklenti UMP boşluğu kararı (§7 #15)~~ → **M9-01'de yama + deterministik
   AAR yeniden derlemesiyle kodda kapandı** (aşağıda M9); cihaz kapısı M9-01.1'de
   Samsung A36'da GEÇTİ (2026-09-23).
8. ~~M8.10 ilk açılış tutorial'ı~~ → **KAPANDI: uygulandı, A36 kapısı
   GEÇTİ, main'e alındı `3fb2945`** (ff-only, push edildi, 2026-09-22;
   base `d72fde5`). Dal `task/035-first-run-tutorial` duruyor. Ayrıntı
   aşağıda ve `docs/TUTORIAL_SYSTEM.md` §12.1'de. İlk açılış deneyimi
   DONDURULDU.

### M8.10 — İlk açılış tutorial'ı + ilk gün kuralı

Dal `task/035-first-run-tutorial`. Kanonik doküman
[docs/TUTORIAL_SYSTEM.md](docs/TUTORIAL_SYSTEM.md).

**Neden bu tasarım.** Onboarding dikişi M8.9-02'de hazırlanmıştı ama
tutorial'ın kendisi yoktu; Level 1'de duran "sürükle • bırak" ipucu ise
onboarded oyuncuya da çıkıyordu. İki sistem yan yana yaşayamayacağı için
eski ipucu KALDIRILDI (`gameplay_hud.tutorial` widget'ı ve
`GameBoard._setup_tutorial/_place_tutorial/_dismiss_tutorial` silindi;
harness'lerdeki `_dismiss_tutorial()` çağrıları temizlendi).

**Sahte fizik yok.** Tutorial gerçek `GameBoard` + gerçek `Dumpling` +
gerçek `_resolve_merge` üstünde çalışıyor. T2 doğrudan doğurulmuyor: iki T1
gerçekten bırakılıyor ve adım ancak `GameState.merge_performed` geldiğinde
ilerliyor. Öğretim kuyruğu (`[T1, T1]`) `DropBag` RNG'sine dokunmuyor
(kuyruk bitince torba devralıyor; torba round başına yeni, yani tutorial'dan
sonra hiç çekilmemiş oluyor). İki bırakma yardımı tutorial'a özel: ilk drop
kabın ortasında ±%24 banda CLAMP (önizleme de sınırlı), ikinci drop ilk
T1'in x'ine SNAP (önizleme serbest, hizalama bırakma anında + cyan kılavuz
çizgisi). Merge 3 sn içinde gelmezse adım güvenle yeniden kuruluyor —
oyuncu takılı kalmıyor.

**Sorumluluk sınırı.** Board ürün onboarding'ini bilmiyor: yalnız pasif
dikişler sunuyor (`setup_tutorial_queue`, `set_tutorial_input_locked`,
`set_tutorial_paused`, `set_tutorial_drop_clamp/snap`, spot dikdörtgenleri).
Tutorial pause'u fail-pending / refill-pending / menü dondurmasından AYRI
bayrak; karşılıklı koruma var ve `_finish()` üçünü de temizliyor. Tutorial
açıkken Mola ve Ayarlar açılmıyor (oyun içi Geri butonu tutorial'ın kendi
onayını açıyor), Android geri "DEVAM ET / ATLA" gösteriyor — monetize edilmiş
Ana Sayfa'ya onboarding false iken ASLA düşülmüyor.

**Kalıcılık.** Yeni `Onboarding` servisi (tek yetkili nokta) + kayıt alanı
`onboarding_completed_day`. `SaveManager.complete_onboarding(day_key)` iki
alanı ve `last_seen_day_key`'i TEK `save_game()` ile yazıyor; idempotent
(ikinci çağrıda diske yazma DA yok). Eski kayıtta tamamlanma günü
UYDURULMUYOR — boş kalıyor ve "yerleşik oyuncu, bastırma yok" demek. Yarıda
kapanırsa onboarding false kalıyor ve tutorial baştan başlıyor (adım adım
kalıcılık bilinçli olarak YOK).

**İlk gün kuralı.** Tek kapı `Onboarding.daily_rewards_unlocked()`; kontrol
UI'da değil MODELDE (üç transaction + `popup_due` + giriş ödülü içinde).
Tamamlanma gününde günlük sistemin tamamı kapalı, telafi yok; ertesi yerel
günde sıfırdan (seri 1, +15, tek pencere, tam kotalar). Saat geri alma
korumasıyla tutarlı: B gününe geçtikten sonra A'ya dönmek yeniden
kilitlemiyor.

**Monetizasyon.** UMP/rıza akışı onboarding'e kadar hiç başlamıyor
(`_maybe_start_consent`); şart kaldırılmadı, yalnız ertelendi. Tutorial'dan
doğan Level 1 round'unun ORTASINDA banner yuvası açılmıyor — `Main` geçici
(kayda yazılmayan) bir erteleme bayrağı tutuyor ve ilk güvenli geçişte
(`_show_tab` / `_start_level`) açıyor. Bu sırada bulunan bir hata da
düzeltildi: `_consent_attempts` başarıda sıfırlandığı için "rıza başladı mı"
sorusuna cevap veremiyordu (ikinci `request_consent_update` izni geçici
olarak kaybettiriyordu) → ayrı `_consent_started` bayrağı.

**Testler (ilk geçerli koşu).** `tutorial_test` 149/149, `daily_rewards_test`
179/179, `monetization_test` 207/207, `interstitial_test` 60/60. Görsel QA:
`tools/tutorial_shots.tscn` 3 boyut × 10 durum, her adımda "kart hedefi
örtmüyor" ölçümü.

**A36 cihaz kapısı (M8.10.1, 2026-09-22): GEÇTİ.** SM-A366B / Android 16 /
1080×2340; aynı ağaçtan üretim biçimli TEST-reklam APK'sı + ayrı QA paketi.
Gerçek dokunuşla ilk açılış → gerçek T1+T1 → T2 merge'i → coach mark'lar →
tamamlanma; tamamlanmada diske yalnız iki alan + `last_seen_day_key`; round
ortasında banner yuvası 0 ve UMP 0; kabuğa dönüşte UMP 0 → 16 ve banner
göründü; aynı gün günlük tam bastırma, ertesi gün +15/seri 1/tek pencere,
saat geri alınca ikinci ödül yok; yarıda kapanma WELCOME'dan baştan; ATLA ve
Android geri kanonik yoldan; mevcut/eski oyuncu tutorial görmedi; logcat
temiz, orphan 0, PSS 475 MB; **owner görsel kontrolü PASS (5/5)**. Cihazda
runtime defekti YOK. Owner telefon kaydı byte-identical geri kondu.
Kanıt: `build/qa_m8.10.1/DEVICE_GATE_NOTES.md`.

**Bir olay kaydedildi (üretim kodu DEĞİL, araç kullanımı):** geri yükleme
yolu doğrulanırken `run-as PKG sh -c 'cat /sdcard/… > files/…'` denendi;
`run-as` /sdcard'ı okuyamadığı için yönlendirme hedefi okuma başarısız
olmadan önce SIFIRLADI ve owner telefon kaydı 0 bayta düştü. Doğrulanmış
yedekten anında geri yüklendi (md5 eşleşti, veri kaybı yok). Kalan tüm
yazmalar stdin + `base64 -d` ile yapıldı. Kural artık notlarda.

**Açık:** tutorial metinleri yalnız Türkçe; üretim engelleri (UMP
sarmalayıcı + #120, COPPA/TFCD/TFUA, gerçek AdMob kimlikleri) değişmedi —
tutorial kapısının geçmesi bunları kapatmaz.

### M9 — Android export

**M9-01 — production release hazırlığı (kod tarafı) TAMAM (2026-09-22, dal
`task/036-production-release-readiness`, base `5a3a0f0`, telefon/ADB yok; M9-01.1 A36
kapısıyla birlikte 2026-09-24'te main'e ff-only alındı — aşağıda).** Ne yapıldı ve neden:

- **Eklenti UMP boşluğu (ÜRETİM ENGELİ A/B) kodda kapandı.** Denetim:
  vendored v6.0 AAR'ı `javap` ile açıldı — `can_request_ads` /
  `get_privacy_options_requirement_status` / `show_privacy_options_form` yok,
  `ConsentConfiguration` `instanceof Integer` (#120). Upstream v7.0 ve `main`
  da üç çağrıyı sunmuyor (yalnız #120 düzeltilmiş; v7.0 Godot 4.7 hedefli).
  Karar: v6.0'a **minimum yama** (3 dosya, +73/−2) ve upstream derleme
  betikleriyle yeniden derleme. Deterministiklik kanıtı: yamasız v6.0 bu
  makinede derlenince `classes.jar`/`R.txt`/`res` upstream release AAR'larıyla
  birebir (fark yalnız AGP'nin Windows'ta CRLF yazdığı manifest satır sonları);
  yamalı derleme üç bağımsız koşuda BYTE-IDENTICAL. `tools/admob_plugin/`
  (yama, `build_patched_plugin.sh baseline|verify|install`,
  `aar_equivalence.py`), `addons/AdmobPlugin/VERSION.md`.
- **Rıza semantiği:** izin kararı resmî `canRequestAds()` (SDK başlatma + her
  yükleme öncesi yeniden), güncelleme hatasında önceki oturumun rızası korunur
  (`ERROR_WITH_PREVIOUS_STATE`), gizlilik seçenekleri resmî durum/form;
  eklenti yamasızsa uyarılı M8.9 türetmesi. M8.9 geri çekilme / talep üzerine
  tazeleme / M8.10 erteleme latch'i aynen.
- **Kimlik seçimi build türüne bağlandı** (eskiden elle çevrilen `is_real`):
  debug build yalnız Google test kimlikleri (canlı birim imkânsız), release
  build dört gerçek kimlik + `is_real=true` (biçim, yayıncı, tekrar, Google
  örneği kontrolleri), aksi hâlde fail-closed. Debug coğrafyası yalnız debug
  build (üç kilit); EEA / NOT_EEA QA kancaları `tools/ads_device`.
- **Kitle dikişi** `android_export.cfg [Audience]` — karar YOK, değerler M8.9
  (TFCD/TFUA gönderilmez, G). Tahmin edilmedi: docs/monetization/AUDIENCE_DECISION.md.
  *(Sonra: owner kararı 2026-09-25 — `general_13_plus`, aşağıda.)*
- **Release kapısı** — Godot 4.6.3'te export eklentisi export'u veto edemiyor
  (`_get_export_option_warning` yalnız mesaj ekler; kaynaktan doğrulandı),
  bu yüzden: (1) pipeline `tools/release/release_android.sh` export'tan ÖNCE
  `release_check.tscn` ile reddeder, (2) `addons/squishy_release` Godot release
  export'unu çözülemeyen, kendini anlatan bir Gradle bağımlılığıyla bilerek
  düşürür (doğrulandı: 21 sn, AAB yok), (3) runtime release build geçersiz
  yapılandırmada reklamı hiç başlatmaz. Tek doğrulayıcı
  `tools/release/release_readiness.gd`. İsteğe bağlı İMZASIZ `NOT_FOR_UPLOAD`
  release biçimli AAB modu (hat doğrulaması).
- **Tek sürüm kaynağı:** versionName = `application/config/version` (0.8.5;
  presetler `version/name` boş), versionCode = project.godot
  `squishy/release/android_version_code` (1); paket kimliği kararı
  `squishy/release/android_package_id` (BOŞ = owner kararı bekliyor);
  gizlilik politikası URL'i `squishy/privacy/policy_url` (Ayarlar'da satır,
  URL verilene kadar gizli).
- **Yerel presetler** (gitignore'lu, `preset.0` "Android" BAYT BAYT aynı
  bırakıldı, yedek `build/qa_m9-01/presets/`): "Android Release AAB" (imzalı;
  anahtar yalnız `GODOT_ANDROID_KEYSTORE_RELEASE_*` ortam değişkenlerinden) +
  "Android AAB NOT FOR UPLOAD" (imzasız); ikisi de editör-yalnız eklentileri
  export dışı tutuyor.
- **Testler:** `release_config_test` 106 (yeni), `monetization_test` 222 → 248;
  tam regresyon: tutorial 199, daily 179, interstitial 60, audio 117, feedback
  129, shell 147, ui_smoke 74, result_ui 226, revive_refill_ui 266, economy 100,
  refill 119, revive 120, skin 30, home_ui 208, map_ui 127, shop_ui 213,
  collection_ui 164, secondary_modal 100, ui_foundation 165, bot L3 2/2 —
  0 SCRIPT ERROR, owner masaüstü kaydı byte-identical (859 B, md5 47f9027d…).
- **Çıktılar** (`build/release/`, yerel): TEST-reklam debug APK
  `squishy_merge_0.8.5_vc1_testads_debug.apk` (102,3 MB — Gradle debug
  `.so`'ları strip'siz; Google test kimlikleri manifest + yapılandırmada,
  sızıntı 0; yalnız editör-eklenti betikleri paketli çünkü owner'ın `preset.0`
  exclude listesi değiştirilmedi) + `NOT_FOR_UPLOAD_…_unsigned.aab` (47,7 MB,
  imzasız, arm64, targetSdk 36, `allowBackup=false`, sızıntı 0). **Upload-ready
  AAB üretilmedi** — kapı BLOCKED (paket kimliği, AdMob kimlikleri, kitle,
  gizlilik URL'i, upload anahtarı). Liste: docs/ANDROID_RELEASE_CHECKLIST.md,
  veri envanteri docs/DATA_SAFETY_INVENTORY.md.

**M9-01.1 — UMP / gizlilik cihaz kapısı (2026-09-23): Samsung A36 GEÇTİ, runtime
değişmedi.** İkinci oturumda A36 (SM-A366B / Android 16) bağlıydı. `368c60d` çalışma
zamanıyla ayrı QA paketi (`…squishymerge.qa`, Google test kimlikleri); QA harness'ına
tek ekleme `tools/ads_device.gd` soğuk açılış seçeneği (`user://qa_boot.txt` = `[fresh]
[geo=…]`) — her coğrafya / onboarding yolu YENİ süreçte, Mobile Ads SDK hiç
başlatılmamışken ölçüldü (`pm clear` = UMP sıfırlama). Neden böyle: süreç içi `remake`
SDK'yı önceki adımdan başlatılmış bırakıyordu; "form çözülmeden SDK başlamaz" ancak temiz
süreçte kanıtlanabilir. Sonuç: yamalı AAR'ın üç JNI çağrısı çalıştı; #120 (`Setting debug
geography to: 4` / `1`, geçersiz 0 — Java test modunda cihazın hash'ini kendisi ekliyor);
NOT_EEA → NOT_REQUIRED + `canRequestAds` true + SDK + test reklamları; EEA → Google formu,
form açıkken `canRequestAds` false + eklentide `initialize()` 0 + `load_*` 0, "Consent" →
OBTAINED / true / REQUIRED → ancak sonra SDK; Ayarlar → "Gizlilik seçenekleri — Aç" →
yerel `showPrivacyOptionsForm` → "Do not consent" → callback tam bir kez, SDK OBTAINED +
true (sınırlı reklam) → yönetici SDK'yı izledi; "Gizlilik politikası" satırı gizli;
soğuk açılışta yeni oyuncu + EEA: tutorial (gerçek T1+T1 → T2) ve tutorial'dan doğan Level
1 boyunca 0 rıza çağrısı, yuva 0, geometri aynı; ilk güvenli kabukta (Harita) tam bir
başlatma; sonra 4 kabuk geçişi + arka plan/öne dönüş: ikinci başlatma yok, tek AdView,
düğüm sabit, orphan 0. Logcat (6 QA süreci) temiz. Kurulumdan hemen sonra telefon ekran
zaman aşımıyla kilitlendi — girdi durdu, owner açana kadar salt-okunur beklendi.
Owner'ın üretim paketine dokunulmadı. Ayrıntı PRIVACY_CONSENT §7,
`build/qa_m9-01.1/A36_DEVICE_GATE.md`.

İlk deneme (aynı gün): Samsung A36 oturum boyunca adb'de görünmedi; gerçek cihaz kanıtı
çalıştırılamadı (emülatör owner kuralı gereği yerine geçmez). Ek kanıt olarak Pixel_8 emülatöründe (Android 16)
yamalı AAR, üç yeni JNI çağrısı, #120, NOT_EEA / EEA formu, gizlilik seçenekleri formu
(tek callback) ve onboarding ertelemesi doğrulandı; Vulkan'lı QA build'i x86_64
emülatörde ARM çevirisiyle çizemediği için emülatöre özel GL Compatibility varyantı
kullanıldı. Politika dokümanları düzeltildi (TFAT, koşullu 12 test kullanıcısı, 30 Eylül
bölgesel doğrulama dalgası). Masaüstü regresyon yeşil; release kapısı yalnız
OWNER/CONFIG. Ayrıntı PRIVACY_CONSENT §7, `build/qa_m9-01.1/DEVICE_GATE_NOTES.md`.

**Main entegrasyonu (2026-09-24): M9-01 + M9-01.1 main'e ff-only alındı — ikisi de
KAPANDI.** `5a3a0f0` → A36 doğrulanmış ağaç `2fd8a72` (4 commit: 93bff62, 48c9672,
368c60d, 2fd8a72; merge / squash / rebase yok); `main^{tree}` ==
`task/036^{tree}` — main, A36 kapısını ve masaüstü kapısını geçen ağacın ta kendisi
(çalışma zamanı 93bff62'den beri değişmedi). Bu yüzden A36 kapısı yinelenmedi. Entegre
main'de: release_config 106, monetization 248, tutorial 199, daily_rewards 179,
interstitial 60 + tam regresyon (16 suite) + bot L3 2/2 — 0 FAIL, 0 SCRIPT ERROR; owner
masaüstü kaydı byte-identical. Release kapısı BLOCKED yalnız OWNER/CONFIG (CODE 0 ·
OWNER 10 · CONFIG 1), `aab` reddedildi (AAB üretilmedi). Kilitler aynen: Godot 4.6.3,
GMA 24.9.0, UMP 3.2.0, yamalı v6.0 AAR'ları (sha256 e3ac9a6b… / 90d35992…), debug =
yalnız Google test kimlikleri, release = fail-closed; TFAT / GMA güncellemesi teknik borç
olarak duruyor *(Sonra: TASK/042 — üretim GMA 25.3.0 / UMP 4.0.0 + TFAT, varsayılan
UNSPECIFIED; dalda, main'e alınması owner onayı bekliyor)*. Dal `task/036` korunuyor;
`task/037` (shell_shots) ayrı, sonra. Kanıt `build/qa_m9-integration/` (yerel).

**Kalıcı paket kimliği (owner kararı, 2026-09-24; dal `task/038-final-package-id`, main
`96e71c0` üzerine).** Üretim / Play = `com.obappstudio.squishymerge` — project.godot
`squishy/release/android_package_id` + yerel "Android Release AAB" / "Android AAB NOT FOR
UPLOAD" presetleri. QA / test = `com.obappstudio.squishymerge.qa` — debug TEST-reklam
preset'i ("Android") ve cihaz harness paketleri. Neden: owner kuralı "QA/test paketleri
üretimle asla çakışmaz"; aynı kimlikli debug-imzalı bir APK, Play'den kurulmuş üretim
sürümüyle aynı cihazda imza çakışması verir. Kapı (`ReleaseReadiness`): `.qa` kimliği
release'te engel (kanonik → OWNER, preset → CONFIG), üretim kimliğiyle debug export'u
raporda UYARI (debug build'i düşürmez). Runtime paket kimliğini okumaz — gameplay /
ekonomi / reklam davranışı değişmedi. `release_config_test` 106 → 112; kapı BLOCKED —
CODE 0 · OWNER 9 · CONFIG 0. Pipeline kanıtı: TEST-reklam debug APK manifest paketi
`com.obappstudio.squishymerge.qa`, İMZASIZ NOT_FOR_UPLOAD AAB `com.obappstudio.squishymerge`
(ikisi de tarama PASS; `build/qa_m9-package-id/`, yerel). Owner'ın A36'sındaki eski
`com.example.squishymerge` kurulumu (kendi kaydıyla) dokunulmadı; yeni kimlikler ayrı
uygulama olarak kurulur. Eski `build/qa_*/device` QA betikleri `com.example…` varsayar —
yeniden kullanılırsa paket adı güncellenmeli.

**Hedef kitle kararı (owner kararı, 2026-09-25 — FİNAL; dal `task/039-target-audience`,
main `3bc6377` üzerine).** Squishy Merge 13+ genel kitleye yönelik bir casual oyun; 13 yaş
altı çocuklar için tasarlanmadı ve onlara pazarlanmaz. Play hedef yaş grupları 13–15 /
16–17 / 18+ seçilir; 5 ve altı / 6–8 / 9–12 seçilmez. Repoda kayıt: `android_export.cfg
[Audience] decision = general_13_plus` + AUDIENCE_DECISION §0. Neden yalnız bu alan: seçenek
A'nın kodu M9-01'den beri hazır; TFCD / TFUA (`unspecified`, gönderilmez) ve en yüksek reklam
derecesi (G) karar tarafından DEĞİŞTİRİLMEDİ — reklam istekleri M8.9'dan beri aynı. Yaş
ekranı, 13 altına özel reklam mantığı, Families yeniden tasarımı ve GMA / TFAT geçişi
YAPILMADI (GMA 24.9.0 / UMP 3.2.0 aynen). Mağaza kuralı: "çocuklar için / çocuk oyunu /
yürümeye başlayan çocuklar için / okul öncesi" yok, 13 altına pazarlama yok; kawaii sanat
kalır. Runtime kodu değişmedi (`decision` yalnız kapıda ve `AdConfig.describe()` log
satırında okunuyor). Play Console'a hiçbir şey girilmedi.

**Politika düzeltmesi (aynı gün, main'e alınmadan önce, `task/039` ikinci commit).** İlk
commit'teki (`4d3268c`) iki sonuç fazla kesindi ve düzeltildi: (1) "13 altı grup seçilmedi →
Families uygulanmaz" DENEMEZ — Google'ın hedef kitle sayfasına göre 13–15 ve 16–17 bazı
yerlerde çocuk sayılabilir ve 21 yaş altını hedefleyen uygulama yerel hukuku değerlendirmeli;
dağıtılan bölgelere göre Families / çocuk gizliliği / reklam yükümlülükleri değerlendirilir.
(2) TFAT yalnız "sonraki teknik borç" DEĞİL: GMA 24.9.0 TFAT `TEEN` gönderemez, `TEEN`'in
eski TFCD / TFUA'da karşılığı yok ve `unspecified` TEEN demek değil — 13–17 genç reklam
işlemi / yargı bölgesi uyum stratejisi üretim yayınından önce çözülmesi gereken AÇIK bir
release-uyum kararı. Stratejiler (A: TEEN gönderebilen GMA / eklenti yolu, B: yaş / yaş bandı
düzeneği, C: owner açıkça seçerse ileride başka ürün konumu, D: gerçek yayın bölgeleri için
UNSPECIFIED'in yeterli olduğuna karar veren hukuki inceleme) AUDIENCE_DECISION §2.2'de
belgelendi, hiçbiri seçilmedi / uygulanmadı. Ürün kitlesi kararı KAPALI kaldı. Kapı
(`ReleaseReadiness`): genel "kitle kararı yok" satırı yok (A kararı rapora bilgi notu —
etiketlerin TEEN olmadığını söylüyor); 13–17'yi de hedefleyen kitlede (general_13_plus,
mixed_audience) ayrı `[OWNER] UYUM:` satırı — hiçbir TFCD / TFUA / derece değeri onu
kaldırmaz, bugün yapılandırmayla kapanmaz (`teen_ad_treatment_resolved = false`); karar
boşalırsa OWNER, karma / çocuk yazılırsa CODE (fail-closed). `release_config_test` 112 →
118 → 123; kapı BLOCKED — CODE 0 · OWNER 9 · CONFIG 0; `aab` reddedildi. Yaş ekranı, GMA
yükseltmesi, reklam değişikliği YOK; runtime kodu yine değişmedi.

**TASK/040 — dünya geneli 13+ genç reklam işlemi fizibilitesi (2026-09-25; dal
`task/040-global-teen-compliance`, main `4ef7793` üzerine; main'e alınması owner onayı
bekliyor).** Owner kararları: dünya geneli dağıtım, 13+ ürün kitlesi (kapalı). Resmî
kaynaklar (Play hedef kitle / Families / Play Age Signals şartları ve politikası, AdMob TFAT,
GMA + UMP sürüm notları, godot-admob) okundu: TEEN = kişiselleştirilmiş reklam + yeniden
pazarlama kapalı + gençlere reklam sunma korumaları; ilk TEEN-yetenekli sürüm GMA 25.3.0
(ikili javap ile doğrulandı: 24.9.0–25.2.0'da sınıf yok); TFCD/TFUA TRUE → CHILD, TEEN'in
karşılığı yok; Age Signals verisi reklam / pazarlama / profilleme / analitik için KULLANILAMAZ
(mimari kısıt, testle kilitli). godot-admob v7.0 Godot 4.7 istiyor ve TFAT içermiyor →
Godot 4.6.3'te tek yol vendored v6.0 yaması. Spike: `tools/admob_plugin/0002-spike-gma25-
age-restricted-treatment.patch` *(TASK/041'de `0003-…` olarak yeniden adlandırıldı ve üretim
0002'nin üstüne taşındı)* (GMA 25.3.0 + UMP 4.0.0, TFAT, başlatma öncesi yapılandırma,
TFAT_DIAG tanı dikişi) + `build_patched_plugin.sh spike` (deterministik; addons'a KURMAZ) +
`spike_qa_export.sh` (yalnız QA paketi, üretim dosyaları SHA-256 ile geri konur) + ads_device
`teen` / `tfat` / `tfat_diag` *(Sonra: TASK/042 spike yamasını, `spike` modunu ve
`spike_qa_*` araçlarını kaldırdı; yetenek üretim yaması
`0003-gma25-age-restricted-treatment.patch`'e taşındı, dalda)*. Samsung A36 kapısı GEÇTİ:
TEEN MobileAds başlatılmadan önce ve her reklam yüklemesinde; UMP 4.0.0 EEA formu, canRequestAds kapısı, gizlilik seçenekleri
(tek geri çağrı), banner / ödüllü / geçiş, arka plan / ön plan, orphan 0, logcat temiz;
NOT_EEA koşusunda UNSPECIFIED ≠ TEEN gösterildi. **Yeni bulgu:** Godot 4.6 Dictionary
int'lerini Long, dizileri Object[] geçiriyor; v6.0 AdmobConfiguration'ın `(int)` /
`(String[])` dönüşümleri ClassCastException atıyor → üretim eklentisi RequestConfiguration'ı
HİÇ uygulamıyor (derece G etkin değil; M9 logları da doğruluyor). Spike'ta düzeltildi, üretim
AAR'ı değişmedi → kapı CODE engeli (`KNOWN_PLUGIN_DEFECTS`) *(sonra kapandı: TASK/041, aşağıda)*. Stratejiler A (herkes için TEEN)
/ B (uygulamanın yaş bandı) / C (UNSPECIFIED + hukuki belirleme) karar tablosuyla belgelendi,
D (eski TRUE etiketleri) reddedildi, E (18+) seçilmedi; teknik öneri A'nın yolu (en basit, en
düşük risk) — hukuki belirleme ve iş dengesi owner'da. `release_config_test` 123 → 130 (denetim) → 132 (spike);
monetization 248, interstitial 60, daily_rewards 179, tutorial 199 (yeşil); kapı BLOCKED —
CODE 1 · OWNER 9 · CONFIG 0. Ayrıntı docs/monetization/GLOBAL_TEEN_AD_TREATMENT.md.

**TASK/041 — üretim RequestConfiguration dönüşüm düzeltmesi (2026-09-27; dal
`task/041-fix-request-configuration`, main `ee01841` üzerine; main'e alınması owner onayı
bekliyor).** Yalnız TASK/040'ın CODE bulgusu; TEEN / GMA 25 geçişi / yaş ekranı YOK. Üretim
yaması `tools/admob_plugin/0002-fix-request-configuration-value-types.patch` (yalnız Java,
GMA 24.9.0 yolu): `AdmobConfiguration` int'leri `instanceof Number` + `intValue()`,
`test_device_ids`'i `Object[]` üzerinde döngüyle (yalnız boş olmayan `String`), `is_real` /
`first_party_id_enabled` / dereceyi tip denetimiyle okur; okunamayan değer loglanır ve o ayar
atlanır; `set_request_configuration()` istisnayı yakalayıp loglar ve SDK'dan geri okuyup tek
`applied …` satırı basar. Değerler aynı (G, TFCD / TFUA -1, kişiselleştirme DEFAULT, test
cihazları yalnız `is_real=false`). Spike `0003`'e taşındı (dönüşüm düzeltmesi tekrarlanmıyor)
*(Sonra: TASK/042 spike'ı kaldırdı; `0003` artık üretim GMA 25.3 / TFAT yaması)*.
Derleme: iki temiz derleme (mevcut + sıfırdan klon) kurulumdan ÖNCE bayt-aynı (debug
`40ae0592…`, release `14c745e9…`), `install` + `verify` aynı baytlar; yalnız
`AdmobConfiguration` / `AdmobPlugin` sınıfları değişti. Kapı: `PATCHED_RELEASE_AAR_SHA256`
düzeltilmiş AAR'ı onaylar, eski SHA `KNOWN_PLUGIN_DEFECTS`'te kalır → CODE 0 · OWNER 9 ·
CONFIG 0; 13–17 UYUM engeli açık. `release_config_test` 132 → 150; monetization 248,
interstitial 60, daily_rewards 179, tutorial 199 (yeşil). Samsung A36 kapısı GEÇTİ (QA
paketi, `7e1e378` APK'sı, GMA 24.9.0 / UMP 3.2.0 dex kimlikleriyle, TFAT yok): her süreçte
`applied max_ad_content_rating=G … test_device_ids=3` ilk yüklemeden önce, SDK'nın test
cihazı ipucu 0, UMP EEA / NOT_EEA / gizlilik seçenekleri (tek geri çağrı), banner (tek
AdView) / ödüllü (ödül bir kez, yeniden yükleme, 60 sn bekleme) / geçiş (round sonu molası,
Result bir kez), arka plan / ön plan (aynı süreç, tek init), orphan 0, logcat temiz; QA paketi
kaldırıldı, owner'ın paketi dokunulmadı. Ayrıntı docs/monetization/ADS_SYSTEM.md §15.

**TASK/042 — üretim AdMob yığını GMA 25.3'e (2026-09-27; dal `task/042-gma25-production`,
main `cbdcb8f` üzerine; `83b86a9` kod + A36 kapısı / doküman kaydı, push edildi; main'e
alınması owner onayı bekliyor).** TASK/040'ın GMA 25.3 / TFAT yolu üretime; kullanıcıya
görünen monetizasyon davranışı, derece G, TFCD / TFUA ve `general_13_plus` DEĞİŞMEDİ; yaş
bilgisi, Play Age Signals (reklamda asla) ve yaş bandı yönlendirmesi YOK. Üretim yaması
`tools/admob_plugin/0003-gma25-age-restricted-treatment.patch` (0001 + 0002'nin üstüne, 0002
donmuş, değişmedi): `playads` 24.9.0 → 25.3.0 (UMP 4.0.0 `play-services-ads-api:25.3.0`
üzerinden geçişli, ayrı geçersiz kılma yok); yeni `age_restricted_treatment` anahtarı (CHILD /
TEEN → `setAgeRestrictedTreatment()`, UNSPECIFIED → `null` = SDK varsayılanı; bilinmeyen değer
loglanır, uygulanmaz); `get_applied_request_configuration()` geri okuması; `initialize()`
başlatma öncesi yapılandırmayı loglar; debug test-cihazı yolu reklam kimliğini artık loglamaz;
facade `age_restricted_treatment` (varsayılan UNSPECIFIED). Runtime:
`MonetizationManager.DEFAULT_AGE_RESTRICTED_TREATMENT` = UNSPECIFIED (herkes için);
`AdmobBackend` yapılandırmayı `MobileAds.initialize()`'dan ÖNCE bir kez uygular, geri okur,
{yaş işlemi, derece, TFCD, TFUA} uyuşmazsa ya da geri okuma yoksa SDK'yı BAŞLATMAZ
(fail-closed: yeniden deneme / yükleme yok, oturum reklamsız); SDK yapılandırıldıktan sonra
farklı yaş işlemi reddedilir (kilit). Derleme: iki temiz derleme (mevcut + sıfırdan GitHub
klonu) kurulumdan ÖNCE bayt-aynı (debug `a78acb22…`, release `f5a563a7…`), `install` +
`verify` aynı baytlar; betik çözülmüş GMA / UMP sürümlerini denetler; `javac` 11 kullanımdan
kalkma uyarısı (hata yok). Spike araçları (`0003-spike-…`, `spike` modu, `spike_qa_*`)
kaldırıldı; `ads_device` `teen` / `tfat` artık üretim API'siyle, yalnız QA teşhisi. Kapı:
onaylı AAR `f5a563a7…`; TASK/041'in `14c745e9…`'u `SUPERSEDED_RELEASE_AARS`'ta, kusurlu M9
`90d35992…` `KNOWN_PLUGIN_DEFECTS`'te (ikisi de gelirse CODE); GMA 25.3.0 + facade TFAT API
zorunlu; `teen_ad_treatment_resolved = false` → CODE 0 · OWNER 9 · CONFIG 0, `aab`
reddedildi. `release_config_test` 150 → 182; monetization 248 → 256, interstitial 60,
daily_rewards 179, tutorial 199 (yeşil, SCRIPT ERROR 0). Çekişmeli inceleme (4 mercek + bulgu
başına şüpheci): 7 düşük bulgu — 2'si gerçek (QA TEEN kanıtı başlatma öncesi sırayı
kanıtlamıyordu; CHILD bytecode denetimi boştu), 5'i ulaşılamaz / kasıtlı; yedisi de ele alındı
(yaş işlemi kilidi, SDK-reddedildi uç durumu, native başlatma öncesi satırıyla kanıt, daha sıkı
bytecode / sürüm denetimleri). Samsung A36 kapısı GEÇTİ (QA paketi, `83b86a9` APK'sı, dex
GMA 25.3.0 / ads-api 25.3.0 / UMP 4.0.0): EEA'da rızadan önce init / yükleme 0, sonra
`applied … UNSPECIFIED` → başlatma öncesi geri okuma → yüklemeler; NOT_EEA, gizlilik
seçenekleri (tek geri çağrı), banner / ödüllü / geçiş, arka plan / ön plan (tek init), orphan
0; üretim yolunda her süreçte UNSPECIFIED; yalnız QA TEEN başlatmadan önce uygulanıp geri
okundu, sonraki değişiklik reddedildi (kilit); varsayılan yol logcat temiz; QA paketi
kaldırıldı, üretim paketi hiç kurulmadı, owner'ın paketi dokunulmadı. 13–17 UYUM engeli AÇIK;
owner yönü (2026-09-27): TASK/043 yaş bandı yönlendirmesi (13–17 → TEEN, 18+ → olağan rıza
denetimli yetişkin yolu, UNSPECIFIED) — başlamadı, engeli kendiliğinden kapatmaz. Kanıt
`build/qa_042/` (yerel); ayrıntı docs/monetization/ADS_SYSTEM.md.

**TASK/043 — nötr yaş ekranı + yaş bandı reklam yönlendirmesi (2026-09-27; dal
`task/043-age-band-routing`, main `249a6e1` üzerine; main'e alınması owner onayı bekliyor).**
Owner iş kararı: dünya geneli, ürün kitlesi 13+; 13–17 reklam alabilir (TFAT TEEN + en yüksek
derece T), 18+ olağan yetişkin yolu (UNSPECIFIED + MA), 13 altı ve bilinmeyen yaş → reklam
SDK'sı başlamaz, UMP yok, reklam yok. Resmî Google kaynakları yeniden okundu (Play hedef kitle /
nötr yaş ekranı / Families / Data safety / Uygunsuz reklamlar / Age Signals şartları; AdMob
TFAT / derece / RequestConfiguration / UMP) — hukuki sonuç çıkarılmadı. Kod: `AgeGate` (saf
takvim yaşı + geçişler + tablo), `SaveManager` (yalnız `age_ad_band` + `next_age_transition_date`,
eski kayıt → UNKNOWN), nötr panel + kısıt ekranı, Main (İLK güvenli kabukta sorar; tutorial /
round ortası ASLA; günlük pencere yaştan sonra; Ayarlar → Yaş bilgisi), `MonetizationManager`
(rota → geri doğrulama → attach → UMP → init öncesi yeniden doğrulama → yapılandırma + geri
okuma → init; SDK sonrası bant değişimi oturumu reklamsız yapar, sonraki soğuk açılış yeni
bantla), `AdmobBackend` derece kilidi, `[Audience] max_ad_content_rating` kaldırıldı, owner
kayıtları (`teen_ad_treatment`, `app_content_rating`, `jurisdiction_age_review`). Kapı: genç
işlemi engeli owner kaydı + kod tablosuyla kalkar; yeni OWNER / UYUM: içerik derecesi ↔ T / MA,
yargı bölgesi değerlendirmesi; CODE: tablo sapması; CONFIG: preset yedeklemesi açık. Çekişmeli
salt-okunur inceleme (7 mercek): HIGH yok; onaylanan MEDIUM'lar (yoldaki rıza formu oturum
kapanınca, QA harness'ın attach'siz getter'ları, banner yuvası sonrası yeniden yerleşim,
tepelik, alan düzeltme, "kaydedildi" metni nötrlüğü, gizlilik metinleri) ve LOW'lar düzeltildi
(çözüm tablosu `build/qa_043/review/RESOLUTION.md`). Testler: `age_gate_test` 137,
`age_ad_routing_test` 112, `release_config_test` 201, monetization 257, interstitial 60,
daily_rewards 179, tutorial 200, secondary_modal_ui 100 + tam regresyon (23 suite) + bot L3 2/2. **Samsung A36 kapısı GEÇTİ**
(yalnız QA paketi, commit `b0e69f0`'ın APK'sı): A bilinmeyen yaş → zorunlu nötr ekran, sıfır SDK /
UMP çağrısı; B sentetik 15 yaş EEA → rıza formu → TEEN + T init öncesi, banner / ödüllü / geçiş; C
sentetik 36 yaş NOT_EEA → UNSPECIFIED + MA; D sentetik 10 yaş → kısıt ekranı, sıfır SDK (soğuk
açılış dahil); E Ayarlar'dan iki yön → oturum reklamsız, aktif SDK'da işlem değişmedi, sonraki
soğuk açılış yeni rota; F tam 18. yaş günü (QA saat dikişi) → SDK'dan önce ADULT; 9 / 9 log
temiz (sentetik tarih izi 0); QA paketi kaldırıldı, owner'ın paketi dokunulmadı. Kapıdan sonra
owner stratejisi kaydedildi → CODE 0 · OWNER 10 · CONFIG 0. Ayrıntı: AGE_BAND_ROUTING.md §11.

**Ortam neredeyse hazır** (§2'deki tabloya bakın). Godot, export
template'leri, Android SDK, NDK, JDK 17 ve debug keystore mevcut.
**M8.9-01'den itibaren export Gradle build ister** (`gradle_build/
use_gradle_build=true`, `android/build/` şablonu `--install-android-build-
template` ile; her makinede ayrı).

**Yapılacaklar (M9 ilk listesi — M9-01 durumu satır sonlarında):**

1. **`export_presets.cfg` oluştur** (Android preset). Dosya gitignore'lu,
   yani her makinede ayrı kurulacak.
2. **`exclude_filter` ayarla:** `tools/*, _visual_source/*`
   — bu olmadan AAB'ye ~73 MB gereksiz veri girer.
3. **Adaptive icon'ları bağla:**

   | preset alanı | dosya |
   |---|---|
   | `launcher_icons/adaptive_background_432x432` | `res://assets/visual/icon/adaptive_background_432.png` |
   | `launcher_icons/adaptive_foreground_432x432` | `res://assets/visual/icon/adaptive_foreground_432.png` |
   | `launcher_icons/main_192x192` | `res://assets/visual/icon/launcher_main_192.png` |

4. **`project.godot`'taki `config/icon`'u değiştir** — hâlâ Godot robotu.
   (M9-01 notu: yalnız masaüstü/editör ikonu; Android launcher/adaptive
   ikonları presetten geliyor ve doğrulandı.)
5. **Release/upload keystore oluştur.** Şu an sadece debug var.
   **Şifre asla dosyaya/commit'e yazılmayacak**, owner'ın yerel makinesinde
   kalacak (`*.keystore`, `*.jks`, `keystore.properties` zaten gitignore'lu).
   (M9-01: bilerek OLUŞTURULMADI — owner adımı, komut ve kurallar
   docs/ANDROID_RELEASE_CHECKLIST.md §4; pipeline ortam değişkeni bekliyor.)
6. **Debug APK al, gerçek cihazda/emulatörde aç.** Crash olmamalı.
7. Dokunmatik girdiyi gerçek cihazda doğrula — bot girdi yolunu hiç
   kullanmıyor (`_set_aim`'i doğrudan çağırıyor), yani **sürükle-bırak
   gerçek parmakla hiç otomatik test edilmedi.**
8. Uzun ekran (9:19.5+) ve çentikli cihazlarda düzeni kontrol et (§7 #9).
9. APK/AAB boyutunu ölç; gerekirse `map_background` lossy import (§7 #8).

### TASK/044 — Player Meta V1 — ✅ TAMAM, main'de (2026-09-28)

*(Kapandı: Samsung A36 yerel kapısı GEÇTİ — §4.20; owner onayıyla ff-only `327dd60 →
239f2e7`. Aşağıdaki maddeler kapı ÖNCESİ listeydi: owner'ın masaüstü kaydı salt okunur
doğrulandı; telefondaki `com.example` kaydı owner talimatıyla açılmadı.)*

- Samsung A36: Koleksiyon albümü + detay + değiştirme adımı, Profil (üç durum,
  kaydırma, dişli → Ayarlar), Ana Sayfa avatarı, oyun içi ayarlar / mola.
- Owner'ın gerçek (eski `equipped_skin`'li) kaydıyla açılış: sahiplik aynen, vitrin
  başında eski favori, gameplay kanonik; masaüstü kaydı bulutta YOKTU — doğrulanmadı.
- Owner-local `export_presets.cfg` / telefon paketi bulutta doğrulanamadı.
- Sonra owner onayıyla main'e ff-only.

### TASK/045 — Player Progression V1 — ✅ TAMAM, main'de (2026-09-28)

*(Kapandı: Samsung A36 yerel kapısı GEÇTİ — bulgu yok, düzeltme commit'i yok; owner onayıyla
ff-only `115252c → d4c8548`. Aşağıdaki maddeler kapı ÖNCESİ listeydi: owner'ın masaüstü
kaydı salt okunur doğrulandı (sessiz göç, dosya değişmedi); cihazda yalnız QA paketi.)*

*(Bulut kapısı geçti — §4.21. Owner'ın yapacağı, bulutta doğrulanamayan:)*

- Masaüstü (Godot 4.6.3): tam regresyon + `progression_shots` (owner kaydı her çıkışta
  bayt-aynı geri konur; `--headless` ile çalışmaz).
- Samsung A36 (yalnız QA paketi): Profil seviye satırı / BAŞARIMLAR / iki pencere (kaydırma,
  geri, karartma, hızlı çift dokunuş), unvan seçimi + yeniden açılışta kalıcılık, gerçek
  round'larda sonuç şeridi (seviye atlama sesi / titreşimi), tam boy Başarımlar penceresinin
  kurdele / X'i durum çubuğunun altında, banner yok.
- Owner'ın gerçek (TASK/045 öncesi) kaydıyla ilk açılış: XP / seviye / başarımlar
  gerçeklerden sessizce kurulur (kutlama yok), kayıt ancak ilk doğal yazmada değişir.
- Sonra owner onayıyla main'e ff-only.

### TASK/046 — Günlük / Haftalık Görevler V1 — dalda, A36 kapısı bekliyor (2026-09-29)

*(Sonra — 2026-09-30: ✅ Samsung A36 yerel kapısı GEÇTİ; TASK/046.1 ile birlikte owner onayıyla
ff-only main'e alındı `56106ef → b90bc3c`. RESULT_DELAY için ayrı görev kararı owner'da.)*

*(Masaüstü doğrulama tamam — §4.24; `task/046-daily-weekly-missions`, main DEĞİŞMEDİ.
Owner'ın yapacağı / onaylayacağı:)*

- Samsung A36 yerel kapısı (yalnız QA paketi `…squishymerge.qa`): gerçek round'larla günlük /
  haftalık ilerleme + otomatik Hamur (tek / çok görev hapı), GÖREVLER girişi ve penceresi
  (güvenli alan, geri / X / karartma, girişe ve X'e hızlı çift dokunuş, yatışma sonrası ilk
  dokunuş, banner yuvası), kayıt kurtarma, TASK/043–045.2 korumaları.
- Önceden var olan RESULT_DELAY bulgusu (§4.24) için ayrı görev isteyip istemediği. *(→ TASK/048 olarak yapıldı —
  main'de `b9ae345`, 2026-10-02, §4.28.)*
- Sonra owner onayıyla main'e ff-only.

### Gelecek görevler (BAŞLAMADI — kod yok)

- ~~**TASK/045** — Oyuncu Seviyesi + XP + Başarımlar + Unvanlar (+ düzenlenebilir
  takma ad; Profil'in kimlik kartı buna yer bırakır, sahte yer tutucu yok).~~ → ✅ main'de
  (yukarıda, §4.21); owner brief'i düzenlenebilir takma adı KAPSAM DIŞI bıraktı
  ("Oyuncu" kalır).
- ~~**TASK/046** — Günlük / Haftalık Görevler (sıradaki).~~ → ✅ **main'de** (§4.24; masaüstü +
  Samsung A36 kapısı GEÇTİ; TASK/046.1 ile birlikte ff-only `56106ef → b90bc3c`, 2026-09-30).
- **TASK/046.1** — yaş ekranı 13+ UX yeniden tasarımı → ✅ **main'de** (§4.25; A36 kapısı GEÇTİ,
  cihaz bulgusu `98d209e`; açık uyum riski owner / hukukta).
- **TASK/046.2** — ACTION_CANCEL bırakma koruması (TASK/047 önkoşulu) → ✅ **main'de** (§4.26;
  masaüstü + Samsung A36 kapısı GEÇTİ; owner onayıyla ff-only `afc10be → 6d3dbca`, 2026-10-01).
- ~~**TASK/047** — Günlük Merge Challenge — BAŞLAMADI; sözleşmesi tasarlanmamıştı.~~ → owner onaylı
  kilitli brifle uygulandı → ✅ **main'de** (§4.27, GAME_DESIGN §5.11; masaüstü + Samsung A36 kapısı +
  hedefli monoton gün kapısı GEÇTİ; owner onayıyla ff-only `6d3dbca → aa6f867`, 2026-10-02; dal
  `task/047-daily-merge-challenge` duruyor).
- **TASK/048** — normal RESULT_DELAY eski sonuç yarışı koruması (normal + çapraz kip) + son engel (geçiş reklamı
  fırlatma aralığı) → ✅ **main'de** (§4.28; masaüstü + Samsung A36 kapıları GEÇTİ; owner onayıyla ff-only `848797a →
  b9ae345`, 2026-10-02; dal `task/048-result-delay-race-guard` duruyor).
- **TASK/049** — round bitişi pencere sahipliği (mola / stok 0 refill penceresi kesinleşmede eylemsiz kapanır; sonuç
  ve geçiş reklamı artık onların altında açılmaz) → ✅ **main'de** (§4.29; masaüstü + Samsung A36 kapıları + final
  kabul GEÇTİ — kontrollü kanonik tam masaüstü kapısı 44 / 44 temiz; owner onayıyla ff-only `25860df → f6cd072`,
  2026-10-03; dal `task/049-round-finish-modal-ownership` duruyor).
- **TASK/050** — meydan okuma bitişi pencere sahipliği (aynı karede merge meydan okumayı açık molada bitirince mola
  kesinleşmede eylemsiz kapanır; meydan okuma sonucu artık molanın altında açılmaz) → ✅ **main'de** (§4.30; masaüstü +
  Samsung A36 kapıları GEÇTİ — kontrollü kanonik tam masaüstü kapısı 45 / 45 temiz; owner onayıyla ff-only `c543cd1 →
  8f9e259`, 2026-10-03; dal `task/050-daily-challenge-terminal-modal-ownership` duruyor).
- **TASK/051** — round başlangıcında dokunuş sahipliği (`_start_level` mevcut 300 ms yatışmayı kurar; `GameBoard`
  basışı kendisine ulaşmamış dizinin sürüklemesini / bırakışını işlemez; hızlı ikinci / basılı / değişimi atlatan
  parmak yeni board'da parça bırakmaz) → ✅ **main'de** (§4.31; masaüstü + Samsung A36 kapıları GEÇTİ — kontrollü
  kanonik tam masaüstü kapısı 46 / 46 temiz; owner onayıyla ff-only `1293eb2 → 4bae821`, 2026-10-04; dal
  `task/051-start-level-touch-settle` duruyor).
- **TASK/052** — tam ekran mola kurtarma (token'lı tam ekran kirası; SDK geri çağrıları yetkili, bayat uygulama molası
  yalnız örtülmeme kanıtıyla biter, ödül asla kurtarmayla verilmez) + gelir odaklı zorunlu geçiş politikası
  (`AdPolicy`: 2 kesinleşen normal round + 300 aktif sn, önce 900 sn; ödüllü kotalar değişmedi, app-open ertelendi) →
  ✅ **main'de** (§4.32; masaüstü + Samsung A36 kapıları GEÇTİ — kontrollü tam masaüstü kapısı 49 / 49 temiz; owner
  onayıyla ff-only `1d2fb28 → c7e3ccc`, 2026-10-04; dal `task/052-fullscreen-break-recovery-monetization` duruyor).
- **TASK/053** — Ayarlar / terminal sonuç sahipliği (terminal temizlik açık Ayarlar'ı da kapatır; kesinleşen round'un
  board'u ekrandayken Ayarlar açılmaz; HUD dişlisi yalnız açılışta dondurur; gizlenen Ayarlar eylem üretmez) → ✅
  **main'de** (§4.33; masaüstü + Samsung A36 kapıları GEÇTİ — kontrollü tam masaüstü kapısı 50 / 50 temiz; owner
  onayıyla ff-only `5b7a727 → 275c537`, 2026-10-05; dal `task/053-settings-terminal-ownership` duruyor).
- **TASK/054** — Koleksiyon basılı dokunuş + Android GERİ (pozitif dokunuş sahipliği: eylem yalnız ekrandaki düğmenin
  gerçek, iptal edilmemiş bırakışıyla; gizlenen / odak kaybındaki basılı düğmenin basışı biter; X / karartma iptalde
  kapatmaz) → ✅ **main'de** (§4.34; masaüstü + Samsung A36 kapıları GEÇTİ — son tam masaüstü kapısı 51 / 51 temiz, 0
  FAIL; ilk koşunun açığa çıkardığı önceden var olan `age_gate_test` tarih fikstürü hatası yalnız-test düzeltmesiyle
  giderildi; owner onayıyla ff-only `6a4a2b2 → 88c8570`, 2026-10-05; dal `task/054-collection-hold-android-back`
  duruyor).
- **TASK/055** — genel GUI ACTION_CANCEL (`GestureGuard`: sonuç doğuran GUI kontrolleri iptal edilen / bayat / geçersiz
  kılınan dokunuşta eylem üretmez; karartmalar iptalde kapatmaz) → ✅ **main'de** (§4.35; masaüstü + Samsung A36 kapıları
  GEÇTİ — kontrollü tam masaüstü kapısı 52 / 52 temiz, 0 FAIL; owner onayıyla ff-only `60f8b71 → e0c1a71`, 2026-10-06;
  dal `task/055-gui-action-cancel` duruyor).
- **TASK/056** — HUD hedef kartı T5 kırpması `Büyük Dumpl…` (skor hedefi ad satırından başlık satırına; ad 20 px'ten
  en az 16 px'e sınırlı sığdırma) → ✅ **main'de** (§4.36; masaüstü + Samsung A36 kapıları GEÇTİ — kontrollü tam
  masaüstü kapısı 53 / 53 temiz, 0 FAIL; owner onayıyla ff-only `a8bf454 → ee2778a`, 2026-10-06; dal
  `task/056-t5-target-card-truncation` duruyor).
- **TASK/057** — Squishy UI System V3 + küresel gezinme kabuğu (mevcut `UiTokens` / `UiType` / `UiKit` katmanının
  evrimi; tek candy-madalyon simge ailesi, oyun benzeri seçili durum, hub geri okları kaldırıldı) → ✅ **main'de**
  (§4.37; owner / ChatGPT görsel onayı APPROVED; masaüstü + gerçek Samsung A36 görsel kapıları GEÇTİ — kontrollü tam
  masaüstü kapısı 55 / 55 temiz, 0 FAIL; owner onayıyla ff-only `d5237bf → 84964af`, 2026-10-07; dal
  `task/057-ui-system-v3-global-nav` duruyor).
- **TASK/058** — Ana Sayfa V3 (kompakt GÜNLÜK | MEYDAN, TEXT-LIGHT / ICON-FIRST Ana Sayfa, Günlük ilk gün kilidi "YARIN") →
  ✅ **main'de** (§4.38; owner görsel onayı APPROVED — yalnız Ana Sayfa; masaüstü tam kapısı 56 / 56 temiz, 0 FAIL + gerçek
  Samsung A36 GEÇTİ, entegrasyondan önce; owner onayıyla ff-only `28a5bf1 → 7025bd4` (2026-10-08; merge commit / rebase / squash / cherry-pick / force push YOK; dal `task/058-home-v3` = `7025bd4` duruyor)).
- **Sıradaki adım (güncel):** **TASK/059 Harita V3** — yeni bir Claude oturumunda, owner başlatınca (BAŞLAMADI). Sonraki
  sahiplik: 059 Harita · 060 ödüllü güçler · 061 Görevler ödül alma / devir · 062 Mağaza / Başlangıç Paketi · 063 Meydan
  Okuma · 064 kalan cila. Release PAUSED.
- *(Tarihsel — TASK/056 sonrası, 2026-10-06:)* **Sıradaki görev:** owner seçer — TASK/057 oluşturulmadı; otomatik bir
  sonraki ürün düzeltme görevi tanımlı değil.
  Bilinen, izlenen açık ürün maddesi: 0 (ürünün hatasız olduğu iddia edilmez) — T5 hedef kartı kırpması `Büyük Dumpl…`
  (§4.27) → TASK/056 ile kapatıldı — main'de `ee2778a`, §4.36; kendiliğinden sıradaki görev seçilmez (Koleksiyon
  kartı + GERİ → TASK/054 ile kapatıldı —
  main'de `88c8570`, §4.34; genel GUI ACTION_CANCEL → TASK/055 ile kapatıldı — main'de `e0c1a71`, §4.35). TASK/052 takip
  gözlemleri yalnız not (görev DEĞİL): trafik sonrası elde tutma / ARPDAU incelemesi, isteğe bağlı daha güçlü ilk gün
  koruması A/B testi, native yetim yeniden yükleme temizliği ve banner iş parçacığı yarışı incelemesi, yayından önce
  TEEN / uyum yeniden incelemesi, mediation / bidding / hesap tarafı iyileştirme, App Open yalnız gerçek bir yükleme /
  bekleme yüzeyi olursa (ADS_SYSTEM §18.5 / §18.7 / §19). *(Mola üstünde sonuç → TASK/049 ile kapatıldı — main'de
  `f6cd072`. Meydan okumanın aynı karede merge ile molada bitmesi → TASK/050 ile kapatıldı — main'de `8f9e259`, §4.30.
  `_start_level` yatışması / çift dokunuş / basılı parmak → TASK/051 ile kapatıldı — main'de `4bae821`, §4.31. Hiç
  bitmeyen tam ekran reklam molasında çıkış kapısı → TASK/052 ile kapatıldı — main'de `c7e3ccc`, §4.32. Erteleme ya da
  sonuç / reklam beklemesinde Ayarlar → TASK/053 ile kapatıldı — main'de `275c537`, §4.33. Basılı Koleksiyon kartı +
  GERİ sentetik bırakışı → TASK/054 ile kapatıldı — main'de `88c8570`, §4.34. Genel GUI ACTION_CANCEL (iptal edilen /
  bayat GUI eylemleri, karartma iptali, güç yuvası, Mağaza SATIN AL iptal harcaması) → TASK/055 ile kapatıldı — main'de
  `e0c1a71`, §4.35.)*
- ~~**Kararlılık (öneri — TASK/045 engeli değil):** atomik kayıt (`save_game()` yerinde kesip
  yazıyor; geçici dosya + yedekten kurtarma) · güç hedefleme bırakış-düşürme (Büyütücü ve
  Bomba hedef dokunuşunun bırakışı bekleyen parçayı da düşürebilir) · Koleksiyon detayı
  otomatik günlük pencere kapısında değil (TASK/044 artığı).~~ → ✅ **TASK/045.1 ile main'de**
  (§4.22; A36 kapısı GEÇTİ, `017f2dc → 5b1f952`).
- ~~**TASK/045.2** — girdi odağı cilası (öneri, BAŞLAMADI)~~ → ✅ **main'de** (§4.23; bulut +
  Samsung A36 kapısı GEÇTİ, `e474fb3 → a32ee2d`). Önceki not: oyun içi Ayarlar dişlisi → Android
  geri ile kapatınca ilk tahta dokunuşunun bırakışı kayboluyor (ikinci dokunuş normal; A36'da
  3/3; KAPAT ve karartma yolları sorunsuz). TASK/045.1 öncesinden — TASK/044'ün 300 ms
  yatışması dişlinin kendi dokunuş bırakışını yutuyor (§4.22 A36 kapısı notu).

### M10 — Play Store submission

**🔴 Blokaj:** Google Play Developer hesabı henüz açılmadı / kimlik
doğrulaması bekliyor. Bu repo işinden bağımsız, owner tarafından paralel
yürütülmeli.

**Eksik olanların net listesi:**

| # | ne | durum |
|---|---|---|
| 1 | Play Console hesabı + kimlik doğrulama (25 USD tek seferlik) | ❌ |
| 2 | Uygulama kaydı, paket adı kesinleştirme (`com.<owner>.squishymerge` gibi) | ❌ |
| 3 | **Play App Signing** kurulumu + upload keystore | ❌ |
| 4 | İmzalı **AAB** | ❌ (M9'a bağlı) |
| 5 | Mağaza listesi: başlık, kısa/uzun açıklama | ❌ |
| 6 | **Feature graphic** (1024×500) | ❌ |
| 7 | **Telefon ekran görüntüleri** (en az 2, 16:9-9:16) — `screenshot_runner.gd` üretebilir ama mağaza için elle seçilmeli | ❌ |
| 8 | Uygulama ikonu (512×512 PNG, mağaza için ayrı) | ❌ |
| 9 | **Gizlilik politikası URL'i** — Play zorunlu tutuyor. Oyun veri toplamıyor (backend yok, analitik yok) ama yine de bir sayfa gerekiyor. | ❌ |
| 10 | Data safety formu | ❌ |
| 11 | İçerik derecelendirme anketi (IARC) | ❌ |
| 12 | Hedef kitle + içerik beyanı — karar ✅ (2026-09-25: 13+ → 13–15 / 16–17 / 18+); konsol formu owner'da | ❌ |
| 13 | Kapalı test track'i + en az 12 test kullanıcısı / 14 gün (yalnız 13 Kasım 2023 sonrası açılmış KİŞİSEL hesaplar için Google'ın şartı; hesabın durumu Play Console'da kontrol edilir) | ❌ |

> **Not:** Google, 2023 sonrası açılan bireysel geliştirici hesapları için
> production'a çıkmadan önce **kapalı testte 12 test kullanıcısıyla 14 gün**
> şartı arıyor. Başarı ölçütü zaten "kapalı test track'inde canlı build"
> olduğu için bu v1 hedefiyle uyumlu — ama takvim planlanırken hesaba
> katılmalı.

---

## 9. Yeni geliştirici için hızlı başlangıç

1. **Önce `CLAUDE.md`'yi oku** — özellikle Godot sürüm uyarısını.
2. Projeyi **4.6.3** ile aç. `git diff project.godot` boş kalmalı.
3. `PROJECT_CONTEXT.md` → güncel durum ve blokajlar.
4. `GAME_DESIGN.md` → kilitli sayılar. **Değiştirmeden önce owner'a sor.**
5. `assets/visual/CREDITS.md` → asset'lerin nasıl üretildiği, hangi
   teknik tuzakların ölçülerek çözüldüğü.

**Çalışma kuralları (CLAUDE.md'den, kısaca):**

- `git add .` **KULLANMA** — dosyaları açıkça isimlendirerek stage et.
- Force push yok, local geçmişi yok etme.
- `main` üzerinde direkt çalışılabilir (tek geliştirici).
- Commit formatı: `[M<no>] <kısa açıklama>`
- Milestone bitince `DEVLOG.md`'ye **tek satır** ekle.
- Final sanat üretmeye çalışma — owner kendi asset'lerini veriyor.
- Otomatik test framework'ü kurma.
- Milestone'u "bitti" demeden önce GAME_DESIGN §9 checklist'ini
  **gerçekten çalıştır.**

**Faydalı komutlar:**

Ekran görüntüsü üret (pencereli çalışır, `--headless` ile ÇALIŞMAZ):

```bash
godot --path . res://tools/screenshot_test.tscn -- <cikti_klasoru>
```

Dar/uzun telefon oranında kontrol:

```bash
godot --path . res://tools/screenshot_test.tscn -- <cikti_klasoru> 540x1170
```

Owner'ın görsellerini yeniden işle (kırpma, küçültme, ikon parçalama):

```bash
godot --headless --path . --script res://tools/make_owner_sprites.gd
```

Denge ölçümü (headless bot, gerçek fizik). `<level>`: 1-10, ya da `0` =
sonsuz mod. `<kosu>`: koşu sayısı — örnek, level 10'u 30 kez oyna:

```bash
godot --headless --audio-driver Dummy --path . res://tools/bot_test.tscn -- 10 30
```

Yıldız eşiklerini yeniden üret (merge puanları değiştiyse ZORUNLU):

```bash
python tools/star_thresholds.py
```
