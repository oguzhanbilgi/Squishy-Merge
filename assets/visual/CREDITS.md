# assets/visual — placeholder görseller

Bu klasördeki tüm `.png` dosyaları **Kenney.nl** paketlerinden alınmış
**CC0 (Creative Commons Zero)** placeholder görsellerdir. Ticari kullanımda
serbesttir, atıf zorunlu değildir.

Kaynak paketler:
- Shape Characters — https://kenney.nl/assets/shape-characters
- UI Pack — https://kenney.nl/assets/ui-pack

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

## UI

| dosya | kaynak | kullanım |
|---|---|---|
| `ui/ui_button_normal.png` | UI Pack — `PNG/Blue/Default/button_rectangle_depth_gloss.png` | Buton: normal (+ hover/focus, modulate ile açılmış) |
| `ui/ui_button_pressed.png` | UI Pack — `PNG/Blue/Default/button_rectangle_gloss.png` | Buton: basılı (derinlik bandı yok → içeri basılmış okunuyor) |
| `ui/ui_button_disabled.png` | UI Pack — `PNG/Grey/Default/button_rectangle_depth_gloss.png` | Buton: kilitli level / kapalı sonsuz mod |
| `ui/ui_panel.png` | UI Pack — `PNG/Grey/Default/button_square_depth_flat.png` | Panel / PanelContainer (pakette ayrı panel sprite'ı yok) |
| `ui/ui_star_filled.png` | UI Pack — `PNG/Yellow/Default/star.png` | Round sonucu: kazanılan yıldız |
| `ui/ui_star_empty.png` | UI Pack — `PNG/Grey/Default/star_outline.png` | Round sonucu: kazanılmayan yıldız (soluk) |

Bunlar `assets/visual/ui_theme.tres` içinde `StyleBoxTexture` olarak 9-patch
kuruluyor. Tema dört ekrana bağlı: level seçim, round sonucu, koleksiyon
albümü, günlük ödül popup'ı. Kodda üretilen butonlar/panel'ler de temayı
ebeveynden miras aldığı için ayrıca elden geçirilmedi.

Yıldızlar `round_result.gd` içinde `TextureRect` olarak kuruluyor; eskiden
`★`/`☆` metin karakteriydi. Dolu yıldız zaten sarı olduğu için tint
uygulanmıyor, boş olan sadece soluklaştırılıyor. Tek tek açılan reveal
animasyonu (`_reveal_stars`) değişmedi — hâlâ `scale` tween'i.

## Değiştirirken
Dosya **isimlerini koru**. Kod bu isimlere `dumpling_visual.gd` sabitleri ve
`ui_theme.tres` üzerinden bağlı; aynı isimle üzerine yazarsan kodda hiçbir
değişiklik gerekmez.

Kendi gövde sprite'ını koyarken: gövde **nötr gri** olmalı (tint palet'ten
gelecek). Renkli bir gövde koyarsan `dumpling_visual.gd` içindeki
`_body.modulate` satırını kaldırman gerekir.

9-patch kenar payları texture boyutuna bağlı — buton/panel sprite'ının
ölçüsünü değiştirirsen `ui_theme.tres` içindeki `texture_margin_*`
değerlerini de güncelle.
