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
godot --headless --path . --script res://tools/make_owner_sprites.gd
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
boşluk). Hem `make_owner_sprites.gd` hem `dumpling_visual.gd` aynı
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

## UI art turu — owner asset'leri (9 dosya)

Owner'ın ChatGPT ile ürettiği dokuz görsel. Kaynaklar
`_visual_source/chatgpt_ui/` altında (gitignore'lu); repoda yalnızca
küçültülmüş çıktılar var. Dönüşüm tekrarlanabilir:

```
godot --headless --path . --script res://tools/make_owner_sprites.gd
```

| dosya | kaynak | boyut | nerede |
|---|---|---|---|
| `ui/map_background.png` | `map_background.png` (941×1672) | 720×1280 | Harita sekmesi zemini |
| `ui/logo_lockup.png` | `logo_lockup.png` (2172×724) | 1024×154 | Ana sayfa başlığı |
| `ui/skin_locked_silhouette.png` | `skin_locked_silhouette.png` (1254×1254) | 213×173 | Koleksiyon + mağaza, kilitli skin |
| `ui/danger_stripe.png` | `danger_stripe.png` (2172×724) | 1440×160 | Taşma çizgisi |
| `ui/badge_starburst.png` | `badge_starburst.png` (1254×1254) | 263×249 | "+N" ve "xN" arkası |
| `ui/banner_new.png` | `banner_new.png` (2172×724) | 720×191 | "Yeni skin: X" arkası |
| `ui/tutorial_pose.png` | `tutorial_pose.png` (1254×1254) | 350×293 | Level 1 ipucu |
| `icon/adaptive_background_432.png` | `icon_bg_layer.png` (887×887) | 432×432 | Android adaptive icon |
| `icon/adaptive_foreground_432.png` | `icon_fg_layer.png` (887×887) | 432×432 | Android adaptive icon |

Hedef boyutlar ekrandaki en büyük kullanımın ~2 katı (yüksek DPI payı),
karakter sprite'larıyla aynı mantık. Hiçbiri büyütülmüyor; araç büyütme
gerekirse uyarı basıyor.

### Harita zemini

Kaynağın en/boy oranı 0.5628, viewport'unki (720×1280) 0.5625 — %0.05 fark,
o yüzden kırpma olmadan tam ekrana oturuyor. Ölçüldüğü hâliyle **tamamen
opak**, alfa kanalı yok; kırpma adımı bu dosyada atlanıyor (içerik zaten
tuvalin tamamı).

`level_select.tscn` katman sırası: koyu `ColorRect` (cihaz oranı farklıysa
letterbox zemini) → `MapBackground` (`STRETCH_KEEP_ASPECT_COVERED`, yani
oran ne olursa olsun ekranı dolduruyor, taşan kenar kırpılıyor) → **`Scrim`**
→ level düğümleri.

Scrim (`Color(0.1, 0.08, 0.13, 0.42)`) sonradan eklendi: zemin çok parlak ve
kalabalık, üstündeki beyaz etiketler ("Sonsuz mod rekoru", yıldız satırları)
scrim'siz okunmuyordu. Zeminin okunurluğu bozulmadan yazı kontrastı geri
geldi.

Zeminde çizili bir yol var ama **düğümler yolu takip etmiyor** — mevcut grid
olduğu gibi duruyor, zemin şimdilik dekoratif (owner'ın talimatı). Gerçek yol
takibi GAME_DESIGN §5.5'te ve hâlâ yapılmadı.

### Tehlike şeridi — tile DEĞİL, tek parça

Bu dosya **piksel-mükemmel seamless değil**: sol ve sağ kenar sütunları
arasındaki ortalama RGBA farkı 0.16, en kötü satırda 1.20 (0 = kusursuz).
Tile modunda her tekrarda görünür bir dikiş çıkardı.

`game_board.gd::_draw_overflow_stripe()` bu yüzden `draw_texture_rect` ile
**tek parça** çiziyor ve kap genişliğine geriyor. Kap genişliği zaten level'a
göre değişken (600 / sonsuz modda 720), yani tek parça germe hem gerekli hem
yeterliydi.

Yükseklik genişlikten türetiliyor (`width * tex_h / tex_w`), sabit değil:
oran zorlanırsa şeritteki yuvarlak yıldızlar ovale dönüyor.

Şerit **her zaman görünür** (fail çizgisi gizlenemez) ama opaklığı taşma
tehlikesinde `0.55 → 1.0` arasında nabız atıyor. Eskiden buradaki görsel
kesikli kırmızı bir çizgi + çizginin altında kırmızı bir banttı; ikisi de
kaldırıldı. Duvarların kırmızıya boyanması (`_draw_danger`) DEĞİŞMEDİ.

Şerit `GameBoard::_draw()` içinde, `DumplingLayer` ise child node — yani
şerit parçaların **arkasında** kalıyor, yığın onun üstüne biniyor.

### Rozet ve banner: `show_behind_parent`

Hem skor/combo rozeti hem "yeni skin" banner'ı, arkasında durdukları
etiketin **çocuğu** ve `show_behind_parent = true`. Böylece etiketin
dönüşümünü ve `modulate`'ini (pop tween'i, kart reveal fade'i) bedavaya
miras alıyorlar; kardeş düğüm olsalardı her layout değişiminde elle
hizalanmaları gerekirdi.

**Rozet konumu ayarlandı.** İlk denemede rozet etiket dikdörtgeninin
merkezine oturtulmuştu; iki sorun çıktı: (1) `ScorePop` etiketi sola
hizalıydı, yani metin dikdörtgenin merkezinde değildi ve rozet metni
ıskalıyordu; (2) 190 px'lik rozet, ekranın tepesindeki 44 px'lik etikette
ekran dışına taşıyordu. Çözüm: `ScorePop` merkeze hizalandı, aşağı
kaydırıldı (y 64 → 78) ve rozet 120×114'e küçültüldü. `ComboLabel` zaten
merkezde ve ekranın ortasındaydı, orada değişiklik gerekmedi.

Combo rozeti metinle birlikte açılıp kapanıyor (`_set_combo_text`) — yoksa
zincir bitip yazı silindiğinde ekranda boş bir rozet kalıyordu.

### "Yeni!" banner'ı — MarginContainer gerekiyor

Banner'ın iki ucunda kurdele kuyrukları var; yazının oturabileceği düz plaka
ortadaki ~%74. İlk denemede banner doğrudan etikete bağlanmıştı ve iki şey
birden bozuldu: yazı kuyrukların altında kesildi ("Yeni skin: Sade" iki
uçtan da kırpıldı), banner da soldaki sandık görselinin ve üstteki rarity
satırının üstüne bindi.

Çözüm (`round_result.gd::_wrap_in_banner`): etiket bir `MarginContainer`'a
sarılıyor, banner o payın dışına taşıyor. Pay layout'ta **gerçekten yer
kapladığı** için banner artık komşularının üstüne binmiyor. Yatay pay 42 px
— plaka kenar payı banner genişliğinin ~%13'ü olduğundan `P ≥ 0.176 × yazı
genişliği` gerekiyor.

Banner gövdesi açık pembe, tema yazısı beyaz: banner'lı satırda yazı rengi
koyu mora (`#5c2a52`) çevriliyor, yoksa okunmuyor.

Banner **yalnızca gerçekten yeni bir skin açıldığında** çıkıyor
(`reward.is_skin_reward()`). Hamur ödülünün ya da "zaten vardı → N Hamur"
satırının arkasında "yeni!" banner'ı yanlış bilgi olurdu.

### Kilitli skin silueti

`skin_swatch.gd` artık kilitli skin'de düz gri daire yerine bu görseli
çiziyor (en/boy korunarak kutuya sığdırılıyor). "?" işareti görselin içinde
çizili. Rarity halkası kaldı (alpha 0.35) — hangi rarity'nin kilitli olduğu
görünmeye devam etsin.

**Açılmış** skin hâlâ placeholder: skin tint'inde dolu bir daire. Skin başına
ayrı görseller owner'dan gelmedi; silüet tek dosya olduğu için önce o
entegre edildi.

Bu turda `collection_album.gd` ve `shop_screen.gd` içindeki `LOCKED_COLOR`
sabitleri silindi — silüet kendi rengiyle geldiği için tint uygulanmıyor,
sabitler ölü koda dönmüştü.

### Tutorial pozu

Görsel `game_board.gd::_setup_tutorial` içinde kullanılıyor: yalnızca level
1'de, kabın ağzı ile taşma çizgisi arasında, hafif salınan bir poz +
"sürükle • bırak" yazısı; ilk bırakışta sönerek kayboluyor.

**Bu ipucu bu turda yazıldı** — asset geldiğinde kodda da spec'te de yoktu.
Owner onayıyla kalıcı hâle geldi ve GAME_DESIGN.md §1.1 olarak spec'e girdi.

Konum sabit koordinat değil, kap geometrisinden hesaplanıyor: kap genişliği
ve oynanabilir yükseklik level'a göre değişiyor, ipucu de onunla birlikte
kaymalı.

### Android adaptive icon — iki kaynak sorunu düzeltildi

Godot'un Android export preset'i 432×432 bekliyor. Ham katmanlar doğrudan
kullanılamıyordu; `make_owner_sprites.gd::_process_icons()` iki şey
düzeltiyor:

**1. Arka plan katmanı kare değildi.** Kaynak dairesel: pikselin %25'i
tamamen şeffaf, köşeler boş. Android arka plan katmanını kırpıp kendi
maskesini uyguluyor — şeffaf köşe bırakılırsa kare/squircle maskeli
launcher'da ikonun köşeleri delik görünür. Daire artık, kendi dış kenarından
örneklenmiş opak bir karenin (`#e7bcd4`) üstünde duruyor. Dolgu rengi
merkezden değil kenardan örnekleniyor: köşeler sanatın kendi rengiyle devam
etsin, rastgele bir zemin üstünde duran daire gibi görünmesin.

**2. Önplan güvenli alanı aşıyordu.** Adaptive icon'da tuvalin yalnızca
ortadaki %66'sı her launcher maskesinde görünür. Kaynakta içerik tuvalin
%92'sini kaplıyordu, yani taç ve parıltılar çoğu cihazda kesilecekti.
İçerik %66'ya küçültülüp ortalandı.

Ayrıca iki katmanın düz kompoziti `icon/launcher_main_192.png` olarak
üretiliyor (tek kare launcher ikonu). Proje hâlâ Godot'un varsayılan robot
ikonuyla (`icon.svg`) geldiği için M9'da bu kullanılabilir — **owner
onayına bağlı, istenmezse silinebilir.**

Export preset'i M9'da kurulacak; bağlanacak alanlar PROJECT_CONTEXT.md'nin
"M9 için hatırlatmalar" bölümünde yazılı.

## Değiştirirken
Dosya **isimlerini koru**. Kod bu isimlere `dumpling_visual.gd` sabitleri ve
`ui_theme.tres` üzerinden bağlı; aynı isimle üzerine yazarsan kodda hiçbir
değişiklik gerekmez.

Karakter sprite'larını değiştirirken: tint uygulanmıyor, yani sprite kendi
son rengiyle gelmeli. Yeni sprite'ları `_visual_source/chatgpt_characters/`
altına aynı isimlerle koyup `make_owner_sprites.gd`'yi çalıştırmak
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
