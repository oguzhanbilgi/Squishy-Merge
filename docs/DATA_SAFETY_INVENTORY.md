# DATA_SAFETY_INVENTORY.md — Play "Data safety" girdileri (M9-01)

> **Bu bir ENVANTER, Play Console'a verilecek nihai cevaplar DEĞİL.** Yalnız
> kodun ve bağımlılıkların gerçekten yaptığı yazıldı. Google'ın SDK beyanları
> Google'ın kendi sayfasından (2026-09-22) özetlendi; doğrulanamayan her şey
> **UNVERIFIED** işaretli. Formu owner Play Console'da doldurur
> ([ANDROID_RELEASE_CHECKLIST.md](ANDROID_RELEASE_CHECKLIST.md) §D). Hiçbir şey
> gönderilmedi.

## 1. Özet

| kaynak | veri cihazdan çıkıyor mu | alan | kanıt |
|---|---|---|---|
| Oyunun yerel kaydı | **HAYIR** | yalnız cihaz | §2, kod taraması |
| Google Mobile Ads SDK (`play-services-ads` 24.9.0) | **EVET** (üçüncü taraf SDK) | Google | §3, Google beyanı |
| UMP SDK (`user-messaging-platform` 3.2.0) | EVET (rıza yapılandırması / kaydı) — ayrıntı **UNVERIFIED** | Google | §4 |
| Analitik | **YOK** | — | §5 |
| Hesap / giriş / sunucu / bulut kayıt | **YOK** | — | §5 |
| Crash raporlama SDK'sı | **YOK** | — | §5 |
| Uygulama içi satın alma / Billing | **YOK** | — | §5 |

## 2. Oyunun kendi verisi (kod gerçeği)

- **Dosya:** `user://squishy_merge_save.json` → Android'de uygulamanın özel iç
  depolaması. Tek yazan `scripts/autoload/save_manager.gd` (başka hiçbir
  betik `FileAccess ... WRITE` açmıyor).
- **İçerik:** oyun ilerlemesi (açılan en yüksek level, level yıldızları, sonsuz
  mod rekoru, toplam merge), oyun içi para (Hamur), açılan/takılı skin'ler,
  güç stokları ve başlangıç hediyesi bayrağı, ödüllü refill günü/sayacı,
  günlük giriş serisi + son giriş tarihi, günlük ödül kotaları ve gün
  anahtarları (`YYYY-MM-DD`, cihazın yerel takvimi), ses/titreşim ayarları,
  onboarding (tutorial) tamamlanma bayrağı ve günü. **Kişisel veri yok** (ad,
  e-posta, telefon, konum, kişi listesi, fotoğraf yok).
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
| Reklam kimliği beyanı | uygulama reklam kimliğini kullanıyor (GMA, `AD_ID` izni) | Play "Advertising ID" formu — kitle kararına bağlı (AUDIENCE_DECISION) |
| "Contains ads" | **Evet** (banner, ödüllü, geçiş) | Play "Ads" beyanı |
| Hesap oluşturma | Yok | — |
