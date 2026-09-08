# assets/visual — görsel asset'ler

**Dumpling karakterleri owner'ın kendi asset'leri** (aşağıya bakın).
Kalan dosyalar (UI, efekt parçacıkları, yıldızlar) **CC0** kaynaklardan
gelen placeholder'lardır; ticari kullanımda serbest, atıf zorunlu değil.

Kaynak paketler:
- Shape Characters — https://kenney.nl/assets/shape-characters
  (**artık kullanılmıyor** — M8'de owner'ın karakterleriyle değiştirildi)
- UI Pack — https://kenney.nl/assets/ui-pack (artık sadece yıldızlar)
- Particle Pack — https://kenney.nl/assets/particle-pack

Kenney dışı kaynak:
- **Wenrexa — "Assets FREE: UI Casual Game Interface"** (CC0)
  https://wenrexa.itch.io/uimobile-free · `WenrexaUIMobileN4_OnlyPng.zip`
  (226 PNG). Lisans pakete dosya olarak eklenmemiş; CC0 bilgisi itch.io
  ürün sayfasındaki "Asset license" alanından geliyor.

Kaynak zip'ler `_visual_source/` altında duruyor (gitignore'lu).

## Dumpling (8 tier) — owner asset'leri

| dosya | kaynak | ekran boyutu |
|---|---|---|
| `dumpling_tier1.png` | `tier1_mini.png` | 143×115 |
| `dumpling_tier2.png` | `tier2_kucuk.png` | 145×113 |
| `dumpling_tier3.png` | `tier3_dumpling.png` | 268×245 |
| `dumpling_tier4.png` | `tier4_siskin.png` | 287×229 |
| `dumpling_tier5.png` | `tier5_buyuk.png` | 291×225 |
| `dumpling_tier6.png` | `tier6_dev.png` | 572×459 |
| `dumpling_tier7.png` | `tier7_jumbo.png` | 575×456 |
| `dumpling_tier8.png` | `tier8_kral.png` | 532×492 |

Bu sekiz karakter **owner tarafından ChatGPT ile üretildi** (M8). Kaynak
dosyalar `_visual_source/chatgpt_characters/` altında duruyor (gitignore'lu);
repoda yalnızca küçültülmüş çıktılar var. Aynı şey sandık görselleri için de
geçerli (`_visual_source/chatgpt_ui/`, aşağıya bakın).

Kaynaklar 1254×1254 ve dosya başına ~900 KB geliyordu (toplam ~7 MB).
Ekranda en büyük tier bile 200 px olduğu için içerik sınırlarına kırpılıp
küçültülüyorlar (toplam ~1.1 MB). Dönüşüm tekrarlanabilir:

```
godot --headless --path . --script res://tools/make_character_sprites.gd
```

### Önemli farklar (eski Kenney kurulumuna göre)

**Tint YOK.** Sprite'lar kendi renkleriyle geliyor; `modulate` uygulanmıyor.
Eski kurulum nötr gri tek bir gövdeyi `TierConfig` paletiyle tint'liyordu.

**Ayrı yüz katmanı YOK.** Yüz sprite'ın içine gömülü. `dumpling_face.png`
artık hiçbir yerden referans verilmiyor.

**Parlama overlay'i YOK.** Sprite'ların kendi spekuler parlamaları var;
`fx/dumpling_gloss.png` üstlerine uygulanırsa çift parlama olurdu. Dosya
duruyor ama kullanılmıyor.

**`TierConfig.TIERS[...].color` artık gövde rengi değil** — yalnızca merge
parçacıklarının ve efektlerin rengi. Değerler sprite'lardan örneklendi
(araç baskın tonu raporluyor). Örneklenmeseydi mavi tier 8'in üstünde
kırmızı parçacık patlardı.

### Ölçek: sprite'lar dairesel değil

Karakterlerin en/boy oranı ~1.08-1.29 (geniş ve basık), fizik gövdesi ise
`CircleShape2D`. Ölçek, **görselin geometrik ortalamasını çapa eşitliyor**:

- yalnızca genişliğe göre ölçeklense parçalar dikey boşlukla dururdu
- yalnızca yüksekliğe göre ölçeklense yatayda taşıp üst üste binerdi

Geometrik ortalama ikisinin hatasını bölüyor (~%12 yatay taşma, ~%11 dikey
boşluk). Hem `make_character_sprites.gd` hem `dumpling_visual.gd` aynı
formülü kullanıyor. Tam doğru çözüm collider'ı elips/kapsül yapmak olurdu
ama bu M8'deki tüm denge ölçümlerini geçersiz kılardı.

### Sandık görselleri — owner asset'leri

| dosya | kaynak | boyut |
|---|---|---|
| `ui/chest_closed.png` | `chest_closed.png` (1004×986) | 258×254 |
| `ui/chest_open.png` | `chest_open.png` (1065×1014) | 262×250 |

Bambu buharda pişirici (dim sum steamer) temalı, owner'ın ChatGPT ile
ürettiği iki görsel. Kaynaklar ~1.4 MB'lık 1240 px dosyalardı; karakterlerle
aynı araçla kırpılıp küçültüldüler:

```
godot --headless --path . --script res://tools/make_owner_sprites.gd
```

**Reveal akışı** (`scripts/ui/reward_gem.gd`): kart belirdiğinde KAPALI
sandık görünür → `CHEST_OPEN_DELAY` (0.35 sn) sonra kapak "sıçrayarak"
açılır (0.88 → texture değişimi → 1.18 → 1.0 scale pop) → rarity katmanları
(parıltı/çerçeve/ışın/parçacık) sandığın üstünde ve çevresinde açılır.

M3'te bu sadece "kart belirir"di. M8'de rarity katmanları eklendi ama
efektler düz renkli bir kutunun üstünde oynuyordu; artık gerçek sandığın
üstünde oynuyorlar. **Rarity kademesi (RARITY_FX tablosu) değişmedi** —
yalnızca hangi görselin üstüne bindiği değişti.

`chest_open.png`'in kendi içinde de altın bir parıltı ve yıldızlar çizili.
Bu, rarity katmanlarıyla çakışmıyor (onlar rarity renginde ve sandığın
dışında halka/ışın olarak duruyor) ama Common ile Legendary arasındaki fark
eskisinden daha az belirgin: sandık görseli her rarity'de aynı. Ayırt
ediciliği artırmak istenirse sandığa hafif bir rarity tint'i eklenebilir —
owner kararı, şimdilik yapılmadı.

### Dönüş: sprite kısmen serbest

Gövde fizikte serbest dönmeye devam ediyor (M1 kilitli kararı) ama yüz
sprite'ın içinde gömülü olduğu için, gövdeyle tam dönerse karakter baş aşağı
kalıyor.

Önce tam ters dönüş denendi (sprite dimdik): yüz okunuyordu ama yığın
robotik ve cansız görünüyordu. Şimdiki hâl: sprite gövdeyi **±20°'ye kadar
takip ediyor**, sonra sabitleniyor. Küçük eğilmeler görünüyor, baş aşağı
dönüş görünmüyor.

Geçiş `lerp_angle` ile yumuşatılıyor: gövde 180°'yi geçerken hedef açı
+20°'den −20°'ye atlıyor, doğrudan atansa görünür bir sıçrama olurdu.
Sabitler `dumpling_visual.gd` içinde (`MAX_TILT`, `TILT_SPEED`).
Fizik davranışı hiç değişmedi.

**Kenar kontrolü (M8):** ChatGPT çıktılarında sık görülen beyaz kenar
halosu (fringing) arandı, **bulunmadı**. Sekiz dosyada da yarı saydam kenar
bandının luminansı gövde ortalamasından 0.05-0.11 *daha düşük* — bu saydam
zemine karşı normal alfa yumuşatmasının imzası; halo olsaydı fark pozitif
çıkardı.

## UI — Wenrexa paketi (M8'de değiştirildi)

| dosya | kaynak | kullanım |
|---|---|---|
| `ui/wenrexa_button.png` | Wenrexa — `PNG/Button11.png` (kırpıldı 308×87 → 286×66) | Buton: normal/hover/pressed/disabled |
| `ui/wenrexa_panel.png` | Wenrexa — `PNG/Msg17.png` (kırpıldı 500×389 → 490×379) | Diyalog paneli (koyu gövde + camgöbeği başlık çubuğu) |
| `ui/ui_star_filled.png` | Kenney UI Pack — `PNG/Yellow/Default/star.png` | Round sonucu: kazanılan yıldız |
| `ui/ui_star_empty.png` | Kenney UI Pack — `PNG/Grey/Default/star_outline.png` | Round sonucu: kazanılmayan yıldız (soluk) |

**Neden kırpıldı:** kaynak PNG'lerde görünür grafiğin etrafında geniş şeffaf
dolgu var (Button11'de buton 87 px'lik tuvalde sadece y=18..70 arasında).
9-patch payları bu dolguyu da esnetir, butonun görünür yüksekliği Control
dikdörtgeninden küçük kalırdı. Dönüşüm tekrarlanabilir:

```
godot --headless --path . --script res://tools/make_ui_sprites.gd
```

### Renk seçimi gerekçesi

Pakette beş renk var: kırmızı `#d26667`, turuncu `#d39b59`, yeşil `#6dbe5b`,
mor `#967ee0`, camgöbeği `#58c4dd`. **Camgöbeği seçildi:**

1. Beşinin en açığı (luminans ~175; diğerleri 125-166), yani dumpling
   paletinin pastel registerine en yakın olan.
2. Hue'su (~192°) tier paletinde yalnızca `bae1ff` (tier 4) ile komşu —
   diğer renkler tier'ların yoğun olduğu sıcak bölgeye (24-52°) veya
   pembe/kırmızı kümesine (349-356°) düşüyordu. UI chrome'unun bir parçayla
   aynı tonda olma ihtimali böylece en düşük.
3. 8 tier'ın 5'i sıcak; serin UI + sıcak parçalar doğal figür/zemin ayrımı
   veriyor, parçalar odakta kalıyor.

**Bu paket koyu bir temadır** — Msg panelleri koyu gövdeli (#31-#5f aralığı),
butonlar doygun aksan. Oyunun arka planı zaten koyu gri olduğu için eski açık
Kenney panelinden daha uyumlu; panel üstündeki beyaz etiketler de artık
yüksek kontrastta.

### Durumlar

Pakette butonun ayrı basılı/kilitli varyantı yok, hepsi aynı "kabarık" tasarım.
Durumlar `ui_theme.tres` içinde tek texture üzerinden türetiliyor:

| durum | yöntem |
|---|---|
| normal | düz texture |
| hover | `modulate_color` 1.14 (açılır) |
| pressed | `modulate_color` 0.78-0.85 + content margin aşağı kaydırılır (içeri basılmış okunur) |
| disabled | `modulate_color` gri/soluk |
| focus | ayrı `StyleBoxFlat`: şeffaf zemin + açık camgöbeği çerçeve (normalin ÜSTÜNE çizilir) |

Buton yazısı koyu lacivert (`#17333f` civarı) — açık camgöbeği zeminde
beyazdan çok daha okunur.

### CardPanel varyantı

Diyalog paneli başlık çubuklu ve 88 px üst content payına sahip; sandık ödül
kartı gibi liste öğelerinde bu yanlış duruyordu. Tema `CardPanel` type
variation'ı tanımlıyor (sade koyu `StyleBoxFlat`), `round_result.gd` kartı
buna bağlıyor.

### Eski Kenney UI dosyaları

`ui/ui_button_normal.png`, `ui_button_pressed.png`, `ui_button_disabled.png`,
`ui/ui_panel.png` **silinmedi** — artık hiçbir yerden referans verilmiyorlar
ama owner geri dönmek isterse `ui_theme.tres` içindeki iki `ext_resource`
yolunu değiştirmek yeterli. Yıldızlar hâlâ Kenney; bu turda değiştirilmedi.

## Efektler (fx/) — M8 juice pası

| dosya | kaynak | kullanım |
|---|---|---|
| `fx/fx_dot.png` | Particle Pack — `PNG (Transparent)/circle_01.png` (512→128) | Merge patlaması + arka plan bokeh'i |
| `fx/fx_sparkle.png` | Particle Pack — `PNG (Transparent)/star_04.png` (512→128) | Tier 5+ merge parıltısı, sandık parçacıkları |
| `fx/fx_burst.png` | Particle Pack — `PNG (Transparent)/star_08.png` (512→256) | Sandık açılışı ışık patlaması |
| `fx/fx_ring.png` | Particle Pack — `PNG (Transparent)/circle_05.png` (512→128) | Sandık ödülünde rarity çerçevesi |
| `fx/dumpling_gloss.png` | **kodda çizildi** (Kenney değil) | Dumpling'in sol-üst parlama overlay'i |

Kaynaklar 512×512 geliyor; ekranda hiçbiri o boyutta görünmediği için
küçültülüyorlar (hem APK boyutu hem overdraw). Dönüşüm tekrarlanabilir:

```
godot --headless --path . --script res://tools/make_fx_sprites.gd
```

`dumpling_gloss.png` pakette yok — gövde eğrisine oturan bir highlight
bulunmadığı için parametrik olarak çiziliyor (elips merkezi, yarıçapları,
eğim ve gövde kenarına maskeleme `tools/make_fx_sprites.gd` içinde sabitler).
Owner kendi gövde sprite'ını koyarsa highlight oradan yeniden ayarlanabilir.

Parlama **tint'lenmez** (beyaz, `GLOSS_ALPHA` = 0.45) ve yüz gibi ters
döndürülür: gövde serbest dönerken ışık kaynağı sabit kalmalı, yoksa
highlight parçayla birlikte dönüp "ışık" okunmasını kaybediyor.
Çizim sırası gövde → parlama → yüz; parlama yüzün üstünde olsaydı ifadeyi
yıkardı.

### Sandık ödül görseli (rarity katmanları)

Ödül kartındaki düz renkli kare, ödül anını sönük bırakıyordu. Yerine
rarity'e göre açılan katmanlı bir görsel geldi (`round_result.gd`,
`RARITY_FX` tablosu):

| rarity | parıltı | çerçeve | ışın | parçacık | nabız |
|---|---|---|---|---|---|
| Common | çok soluk | soluk | — | — | — |
| Rare | orta | belirgin | — | 7 | hafif |
| Epic | güçlü | güçlü | soluk, dönen | 13 | orta |
| Legendary | en güçlü | tam | belirgin, hızlı dönen | 20 | belirgin |

Açılış patlaması (`_burst_at`) da aynı ölçekte: Common küçük ve soluk,
Legendary büyük ve parlak. Teselli ödülü rarity'sine bakılmaksızın her zaman
en sönük katmanı kullanır — kaybedilen round'un tesellisi legendary gibi
parlamamalı.

Dönen/nabız atan tween'ler `bind_node` ile kendi düğümlerine bağlı: kart
silinince tween de ölüyor, ekran görünmezken boşuna çalışmıyor.

## Değiştirirken
Dosya **isimlerini koru**. Kod bu isimlere `dumpling_visual.gd` sabitleri ve
`ui_theme.tres` üzerinden bağlı; aynı isimle üzerine yazarsan kodda hiçbir
değişiklik gerekmez.

Karakter sprite'larını değiştirirken: tint uygulanmıyor, yani sprite kendi
son rengiyle gelmeli. Yeni sprite'ları `_visual_source/chatgpt_characters/`
altına aynı isimlerle koyup `make_character_sprites.gd`'yi çalıştırmak
yeterli — kırpma, küçültme ve baskın renk raporu otomatik. Rapor edilen
renkleri `tier_config.gd`'deki `color` alanlarına yazmayı unutma (parçacık
renkleri oradan geliyor).

En/boy oranı çok farklı bir sprite koyarsan (örn. kare veya dikey) yukarıdaki
geometrik ortalama uzlaşması bozulur; o durumda `dumpling_visual.gd::setup`
içindeki ölçek formülüne bakman gerekir.

9-patch kenar payları texture boyutuna bağlı — buton/panel sprite'ının
ölçüsünü değiştirirsen `ui_theme.tres` içindeki `texture_margin_*`
değerlerini de güncelle. Panelin `texture_margin_top` (76) ve
`content_margin_top` (88) değerleri başlık çubuğunun yüksekliğine göre
ölçülmüştür; başlıksız bir panel koyarsan ikisini de küçültmelisin.
