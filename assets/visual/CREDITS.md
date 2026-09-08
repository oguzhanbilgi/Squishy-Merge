# assets/visual — placeholder görseller

Bu klasördeki tüm `.png` dosyaları **Kenney.nl** paketlerinden alınmış
**CC0 (Creative Commons Zero)** placeholder görsellerdir. Ticari kullanımda
serbesttir, atıf zorunlu değildir.

Kaynak paketler:
- Shape Characters — https://kenney.nl/assets/shape-characters
- UI Pack — https://kenney.nl/assets/ui-pack (artık sadece yıldızlar)
- Particle Pack — https://kenney.nl/assets/particle-pack

Kenney dışı kaynak:
- **Wenrexa — "Assets FREE: UI Casual Game Interface"** (CC0)
  https://wenrexa.itch.io/uimobile-free · `WenrexaUIMobileN4_OnlyPng.zip`
  (226 PNG). Lisans pakete dosya olarak eklenmemiş; CC0 bilgisi itch.io
  ürün sayfasındaki "Asset license" alanından geliyor.

Kaynak zip'ler `_visual_source/` altında duruyor (gitignore'lu).

## Dumpling (8 tier)

| dosya | kaynak | kullanım |
|---|---|---|
| `dumpling_body.png` | Shape Characters — `PNG/Double/yellow_body_circle.png` (nötr griye çevrildi) | 8 tier'ın ortak gövdesi |
| `dumpling_face.png` | Shape Characters — `PNG/Double/face_l.png` (olduğu gibi) | 8 tier'ın ortak yüzü |

**Tier'a göre renk texture'da değil, kodda.** Gövde nötr gri; renk
`TierConfig.TIERS[...].color` paletinden `modulate` ile geliyor
(`scripts/game/dumpling_visual.gd`). Yani 8 ayrı gövde dosyası yok, tek dosya
8 kez farklı tint'le çiziliyor — palet değişince görsel de değişir, dosya
değiştirmek gerekmez.

`dumpling_body.png` neden dönüştürüldü: Kenney gövdeleri sabit renkli
(mavi/sarı/pembe...). Renkli bir gövdeyi tint'lemek paleti kirletirdi. Gövde
luminansa çevrilip baskın dolgu tonu beyaza normalize edildi; parlaklık/gölge
gradyanı korundu. Dönüşüm `tools/make_placeholder_sprites.gd` ile
tekrarlanabilir:

```
godot --headless --path . --script res://tools/make_placeholder_sprites.gd
```

Yüz tint'lenmez (koyu lacivert sabit), bu yüzden olduğu gibi kopyalandı.
v1 için tek yüz ifadesi kullanılıyor — 8 ayrı ifade bilinçli olarak yok.

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

Kendi gövde sprite'ını koyarken: gövde **nötr gri** olmalı (tint palet'ten
gelecek). Renkli bir gövde koyarsan `dumpling_visual.gd` içindeki
`_body.modulate` satırını kaldırman gerekir.

9-patch kenar payları texture boyutuna bağlı — buton/panel sprite'ının
ölçüsünü değiştirirsen `ui_theme.tres` içindeki `texture_margin_*`
değerlerini de güncelle. Panelin `texture_margin_top` (76) ve
`content_margin_top` (88) değerleri başlık çubuğunun yüksekliğine göre
ölçülmüştür; başlıksız bir panel koyarsan ikisini de küçültmelisin.
