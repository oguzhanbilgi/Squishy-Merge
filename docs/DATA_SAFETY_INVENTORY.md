# DATA_SAFETY_INVENTORY.md — Play "Data safety" girdileri (M9-01; TASK/043 yaş bandı eklendi)

> **Bu bir ENVANTER, Play Console'a verilecek nihai cevaplar DEĞİL.** Yalnız
> kodun ve bağımlılıkların gerçekten yaptığı yazıldı. Google'ın SDK beyanları
> Google'ın kendi sayfasından (2026-09-22) özetlendi; doğrulanamayan her şey
> **UNVERIFIED** işaretli. Formu owner Play Console'da doldurur
> ([ANDROID_RELEASE_CHECKLIST.md](ANDROID_RELEASE_CHECKLIST.md) §D). Hiçbir şey
> gönderilmedi.

## 1. Özet

| kaynak | veri cihazdan çıkıyor mu | alan | kanıt |
|---|---|---|---|
| Oyunun yerel kaydı (TASK/043: yaş bandı + geçiş günü dahil; doğum tarihi YOK) | **HAYIR** | yalnız cihaz | §2, kod taraması |
| Google Mobile Ads SDK (`play-services-ads` 24.9.0 — *TASK/042'den beri 25.3.0*) | **EVET** (üçüncü taraf SDK) | Google | §3, Google beyanı |
| UMP SDK (`user-messaging-platform` 3.2.0 — *TASK/042'den beri 4.0.0*) | EVET (rıza yapılandırması / kaydı) — ayrıntı **UNVERIFIED** | Google | §4 |
| Analitik | **YOK** | — | §5 |
| Hesap / giriş / sunucu / bulut kayıt | **YOK** | — | §5 |
| Crash raporlama SDK'sı | **YOK** | — | §5 |
| Uygulama içi satın alma / Billing | **YOK** | — | §5 |

## 2. Oyunun kendi verisi (kod gerçeği)

- **Dosya:** `user://squishy_merge_save.json` → Android'de uygulamanın özel iç
  depolaması. Tek yazan `scripts/autoload/save_manager.gd`; disk işlemi
  TASK/045.1'den beri onun yardımcısı `scripts/autoload/save_file.gd`'de (başka
  hiçbir üretim betiği kayıt için `FileAccess ... WRITE` açmıyor). Çökmeye
  dayanıklı yazma aynı klasörde işlem süresince `squishy_merge_save.json.tmp` kullanır
  (başarıdan sonra kalmaz) ve bir önceki kaydı `squishy_merge_save.json.bak` olarak
  tutar (aynı içerik türü, yeni veri türü YOK; yalnız cihazda, kanonik kayıt bozulursa
  kurtarma için).
- **İçerik:** oyun ilerlemesi (açılan en yüksek level, level yıldızları, sonsuz
  mod rekoru, toplam merge; TASK/044: oynanan tur sayısı, oluşturulan en yüksek
  tier), oyun içi para (Hamur), sahip olunan koleksiyon parçaları (Squishy; alan
  adı tarihsel `unlocked_skins`) ve profil vitrini (en fazla 3 parça kimliği —
  eski kayıttaki `equipped_skin` bir kez vitrine taşınıp silinir),
  güç stokları ve başlangıç hediyesi bayrağı, ödüllü refill günü/sayacı,
  günlük giriş serisi + son giriş tarihi, günlük ödül kotaları ve gün
  anahtarları (`YYYY-MM-DD`, cihazın yerel takvimi), ses/titreşim ayarları,
  onboarding (tutorial) tamamlanma bayrağı ve günü. **Kişisel veri yok** (ad,
  e-posta, telefon, konum, kişi listesi, fotoğraf yok). TASK/044 Profil: görünen
  ad sabit "Oyuncu" (kullanıcıdan ad / takma ad ALINMAZ, saklanmaz); avatar yalnız
  bir koleksiyon parçası — kamera / galeri / dosya erişimi ve izin YOK.
  TASK/045 Oyuncu İlerlemesi: kümülatif oyun içi XP (`player_xp`; seviye saklanmaz,
  türetilir), açılan başarım kimlikleri (`unlocked_achievements`), seçili unvan kimliği
  (`selected_title_id`, sabit katalogdan — serbest metin DEĞİL) ve şema sürümü
  (`player_meta_version`). Hepsi yalnız cihazdaki oyun kaydında; sunucu / hesap / skor
  tablosu / paylaşım YOK, reklam veya analitiğe gönderilmez.
  TASK/046 Günlük / Haftalık Görevler (dalda): `missions` — şema sürümü, içinde bulunulan gün
  ve haftanın pazartesisi (`YYYY-MM-DD`, cihazın yerel takvimi; GÜNLÜK ÖDÜLLER'in gün
  anahtarıyla aynı kaynak), sabit katalogdaki altı görevin sayaçları ve ödülü verilmiş görev
  kimlikleri. Yalnız oyun içi sayaç — kişisel veri / serbest metin yok; sunucu / hesap /
  paylaşım YOK, reklam veya analitiğe gönderilmez.
- **Yaş bandı (TASK/043, [monetization/AGE_BAND_ROUTING.md](monetization/AGE_BAND_ROUTING.md)):**
  nötr yaş ekranında girilen **doğum tarihi SAKLANMAZ** ve cihazdan çıkmaz (yalnız
  bellekte sınıflandırılıp atılır). Kayda yalnız türetilmiş durum yazılır:
  `age_ad_band` (UNKNOWN / UNDER_13 / TEEN / ADULT) ve UNDER_13 / TEEN için
  `next_age_transition_date` (13. / 18. yaş günü, `YYYY-MM-DD`; ADULT'ta boş). Dürüst not:
  UNDER_13 / TEEN bandında bu geçiş günü doğum tarihine matematiksel olarak eşdeğerdir
  (geçiş − 13 / 18 yıl); yalnız cihazdaki kayıtta durur, ADULT olunca silinir (TASK/045.1:
  kaydın bir önceki kuşak kopyası `.bak` de o kayıtta atılır).
  **TASK/046.1 (2026-09-30, dal — main'e alınmadı):** yaş ekranı yalnız 13+ doğum tarihi
  seçtirir; normal giriş artık `UNDER_13` YAZMAZ — yeni kayıtlarda bant yalnız UNKNOWN / TEEN /
  ADULT, geçiş günü yalnız TEEN'de (18. yaş günü). TASK/043 döneminden kalan `UNDER_13` + 13.
  yaş günü açılışta TEK yazmayla `UNKNOWN` + boş tarihe çevrilir ve `.bak` kopyası atılır (reklam
  yok, yaş yeniden sorulur; TEEN / ADULT'a çevrilmez, ilerleme durur) — doğum gününe eşdeğer eski
  tarih cihazdaki kayıtta da kalmaz. Ham doğum tarihi yine yalnız panel belleğinde (seçim
  ızgarası; ızgara kapanınca seçenekler de silinir), kayda / loga / ağa GİTMEZ.
- **Ağ:** oyun kodu hiçbir sunucuya bağlanmaz — `scripts/` ve `scenes/`
  altında `HTTPRequest` / `HTTPClient` / `WebSocket` / TCP-UDP kullanımı YOK
  (M9-01 taraması). Tek dış bağlantı: Ayarlar'daki "Gizlilik politikası"
  satırı (M9-01, URL verilene kadar gizli) sistem tarayıcısını açar.
- **Olay dikişleri** `AdEvents` (son 200) ve `TutorialEvents` (son 100)
  yalnız BELLEKTE; sağlayıcı yok, diske yazılmaz, ağa gönderilmez.
- **Yedekleme:** presetlerde `user_data_backup/allow=false` → manifest
  `android:allowBackup` kapalı (M9-01 çıktılarında doğrulanacak alan:
  checklist §A). Kayıt Google bulut yedeğine girmez.
- **Silme:** uygulamayı kaldırmak kaydı siler
  (`package/retain_data_on_uninstall=false`). Uygulama içinde "verimi sil"
  düğmesi yok (sunucu tarafında silinecek veri de yok).

## 3. Google Mobile Ads SDK (üçüncü taraf, AdMob)

- **Sürüm:** `play-services-ads` **24.9.0** (eklenti v6.0'ın bağımlılığı;
  Google'ın "legacy / maintenance mode" hattı, destek 2027-06-30'a kadar).
- **Google'ın resmî Play veri beyanı** (developers.google.com/admob/android/privacy/play-data-disclosure,
  2026-09-21 güncellemesi) **yalnız en yeni sürümü (25.5.0) anlatıyor**;
  24.9.0 için ayrı beyan yok. 24.9.0 ile farklar **UNVERIFIED** — Google en
  yeni sürümü kullanmayı öneriyor (SDK güncellemesi eklentiye bağlı, bu
  milestone'un kapsamı dışı).
- Beyana göre SDK **otomatik olarak toplar ve paylaşır** (reklam, analitik,
  dolandırıcılık önleme / güvenlik amaçlarıyla):
  - IP adresi (genel konumu tahmin için kullanılabilir),
  - ürün etkileşimleri (uygulama açılışları, dokunuşlar, video izlenmeleri),
  - teşhis verisi (açılış süresi, donma oranı, enerji kullanımı),
  - cihaz ya da diğer kimlikler (reklam kimliği, app set ID, varsa hesap kimlikleri).
- Aktarımda şifreli (TLS). Reklam kimliği toplama manifestten kaldırılarak
  ya da sınırlı reklamlarla durdurulabilir.
- Bu maddelerin Play formundaki hangi kategoriye düştüğü (ör. IP →
  "Yaklaşık konum" mu) **UNVERIFIED** — owner Google'ın rehberiyle karar verir.
- **Manifest izinleri** (M9-01 çıktılarından, `aapt2`): `INTERNET`,
  `ACCESS_NETWORK_STATE`, `AD_ID` + `com.google.android.gms.permission.AD_ID`,
  `ACCESS_ADSERVICES_AD_ID` / `_ATTRIBUTION` / `_TOPICS` (Android Privacy
  Sandbox), `WAKE_LOCK`, `FOREGROUND_SERVICE` (GMA'nın geçişli bağımlılıkları:
  `play-services-measurement-sdk-api`, `androidx.work`), paket adıyla
  `…DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` (androidx core). Oyunun kendi
  izni yalnız `VIBRATE`. Konum / kamera / mikrofon / kişiler / depolama izni YOK.

## 4. UMP SDK (Google rıza platformu)

- **Sürüm:** 3.2.0 (GMA'dan geçişli). AB/EEA, İngiltere, İsviçre'de (ve
  yapılandırılırsa ABD eyaletlerinde) rıza mesajını gösterir; kullanıcının
  seçimini cihazda saklar ve mesaj yapılandırmasını Google'dan alır.
- UMP'ye özel ayrı bir Google Play veri beyanı bulunamadı (resmî UMP sayfası
  GMA beyanını gösteriyor) → **UNVERIFIED**; Google reklam veri akışının parçası
  sayılmalı.
- Bizim kodumuz rıza kaydı TUTMAZ (SDK durumu tek gerçek; PRIVACY_CONSENT §1).

## 5. Oyunun YAPMADIKLARI (kodla doğrulandı)

- Analitik SDK'sı (Firebase vb.) YOK — `AdEvents`/`TutorialEvents` sağlayıcısız.
- Crash raporlama SDK'sı YOK (Play Console "Android vitals" Google Play'in
  kendi verisidir, uygulamanın topladığı veri değildir).
- Hesap / giriş / sunucu / bulut kayıt / skor tablosu YOK.
- Uygulama içi satın alma / Play Billing YOK (Güç Paketi hâlâ yalnız tasarım).
- Konum, kişiler, kamera, mikrofon, dosya depolama erişimi YOK.

## 6. Play "Data safety" formu — owner için girdi haritası (CEVAP DEĞİL)

| formun sorusu | bu projedeki gerçek | owner notu |
|---|---|---|
| Uygulama zorunlu veri türlerini topluyor ya da paylaşıyor mu? | Oyun kodu hayır; **Google Mobile Ads SDK evet** (üçüncü taraf SDK verisi beyana dahil edilir) | §3 listesiyle doldur |
| Hangi veri türleri? | §3: IP / etkileşimler / teşhis / cihaz kimlikleri | kategori eşlemesi UNVERIFIED |
| Amaç | reklam, analitik (SDK'nın), dolandırıcılık önleme / güvenlik | Google beyanı |
| Aktarımda şifreli mi? | SDK trafiği TLS (Google beyanı); oyun ağ kullanmıyor | — |
| Kullanıcı silme isteyebilir mi? | oyun verisi yalnız cihazda (kaldırınca silinir); reklam verisi Google'da | ifade owner'ın |
| Toplama isteğe bağlı mı? | EEA/UK/CH'de UMP rızası; diğer bölgelerde reklam için gerekli | owner |
| Doğum tarihi / yaş (TASK/043; TASK/046.1: yalnız 13+ seçim) | Doğum tarihi yalnız cihazda işlenir, saklanmaz, gönderilmez — Google'ın Data safety tanımında yalnız cihazda işlenen veri beyan kapsamı dışında (owner doğrular). AMA yaşa bağlı **reklam işlemi sinyalleri** her reklam isteğiyle Google'a gider: TFAT `TEEN` (13–17) ya da `UNSPECIFIED` (18+) ve en yüksek reklam derecesi `T` / `MA`; 13 altı / bilinmeyen yaşta reklam isteği hiç yok | bu sinyallerin formda (ör. "Diğer kişisel bilgi" / paylaşım) nasıl beyan edileceği **owner kararı — UNVERIFIED**; gizlilik politikası yaş sorusunu ve kullanımını anlatmalı (AGE_BAND_ROUTING §9) |
| Reklam kimliği beyanı | uygulama reklam kimliğini kullanıyor (GMA, `AD_ID` izni) | Play "Advertising ID" formu — ürün kitlesi 13+ (2026-09-25): `AD_ID` izni bugün kalıyor (yalnız çocuklara yönelik kitlede çıkarılırdı, AUDIENCE_DECISION §3); 13–17 genç reklam işlemi / yargı bölgesi uyumu AÇIK (§2.2) ve reklam kimliği kullanımını etkileyebilir; formun cevabı owner'ın |
| "Contains ads" | **Evet** (banner, ödüllü, geçiş) | Play "Ads" beyanı |
| Hesap oluşturma | Yok | — |
