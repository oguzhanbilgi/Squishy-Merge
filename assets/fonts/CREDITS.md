# assets/fonts — tipografi

İki font ailesi, dört statik ağırlık. İkisi de **SIL Open Font License 1.1**
(ticari kullanım serbest, gömme serbest, yeniden satış yasak; lisans
metinleri bu klasörde). Rollerin nerede kullanıldığı:
`scripts/ui/ui_type.gd` ve `assets/visual/ui_theme.tres`.

| dosya | aile / ağırlık | usWeightClass | kaynak (fonts.gstatic.com, statik TTF) | SHA-256 |
|---|---|---|---|---|
| `Baloo2-Bold.ttf` | Baloo 2 Bold | 700 | `s/baloo2/v23/wXK0E3kTposypRydzVT08TS3JnAmtdj9yqpv.ttf` | `99a6754d…6f62a` |
| `Baloo2-ExtraBold.ttf` | Baloo 2 ExtraBold | 800 | `s/baloo2/v23/wXK0E3kTposypRydzVT08TS3JnAmtdiayqpv.ttf` | `db932b36…2d7e2` |
| `Nunito-SemiBold.ttf` | Nunito SemiBold | 600 | `s/nunito/v32/XRXI3I6Li01BKofiOc5wtlZ2di8HDGUmRTM.ttf` | `1506fc96…23091` |
| `Nunito-Bold.ttf` | Nunito Bold | 700 | `s/nunito/v32/XRXI3I6Li01BKofiOc5wtlZ2di8HDFwmRTM.ttf` | `1a025dfc…b1dc` |

Tam SHA-256 değerleri: `sha256sum *.ttf` ile yeniden üretilebilir; buradaki
kısaltmalar yalnızca dosyanın hangi indirme olduğunu teyit etmek için.

## Kaynak ve lisans doğrulaması

- **Baloo 2** — Telif: Copyright 2019 The Baloo 2 Project Authors
  (https://github.com/EkType/Baloo2). Lisans: OFL 1.1 → `OFL-Baloo2.txt`
  (google/fonts `ofl/baloo2/OFL.txt` kopyası). Sürüm 1.700.
- **Nunito** — Telif: Copyright 2014 The Nunito Project Authors
  (https://github.com/googlefonts/nunito). Lisans: OFL 1.1 →
  `OFL-Nunito.txt` (google/fonts `ofl/nunito/OFL.txt` kopyası). Sürüm 3.602.

Neden google/fonts deposundan değil de fonts.gstatic.com'dan: depo iki
aileyi de **yalnızca variable font** olarak tutuyor (`Baloo2[wght].ttf`,
`Nunito[wght].ttf`). Godot variable font'u destekliyor ama karar statik
TTF'ti (owner, M8.5-09: "variable-font complexity eklemeye gerek yok").
Google Fonts CSS API'si eski bir user-agent'a **aynı upstream'den türetilmiş
resmi statik örnekleri** TTF olarak veriyor — indirme yolu buydu:

```
curl -A "Mozilla/5.0" "https://fonts.googleapis.com/css2?family=Baloo+2:wght@700;800&family=Nunito:wght@600;700"
```

Rastgele bir mirror KULLANILMADI. Dosyaların `name` tablosu (aile, alt aile,
sürüm, lisans URL'si) ve `OS/2 usWeightClass` değerleri indirme sonrası
okunup yukarıdaki tabloyla eşleştirildi.

## Glyph kapsamı

`tools/type_probe.gd` her açılışta doğruluyor (`font.has_char()`):

- **Türkçe Latin Extended** — İ ı Ş ş Ğ ğ Ç ç Ö ö Ü ü: dört dosyada da TAM.
- **UI işaretleri** — × · • … —: dört dosyada da var.
- **YOK olanlar** (ve bu yüzden M8.5-09'da UI metninden çıkarılanlar):
  ★ ☆ (U+2605/2606), ✓ (U+2713), ● ○ (U+25CF/25CB), ✸ ▲ ⌫ (eski güç
  işaretleri). Godot'un `allow_system_fallback` ayarı açık olduğu için bu
  karakterler masaüstünde **yine de bir şey çiziyordu** — sistemin başka
  bir fontundan. Yani "çalışıyor gibi" görünen ama üründe başka bir yazı
  tipine düşen bir tuzak; Android'de hangi fontun geleceği belirsiz.
  Yıldızlar `ui/icon_star_*.png` asset'ine, ✓ düz metne, ●○ renkli •'ya
  çevrildi.

## Boyut notu

Baloo 2 dosyaları 418 KB (Devanagari de içeriyor; subset yapılmadı — bu
makinede fontTools yok ve dosyalar bilerek upstream ile bayt bayt aynı
tutuldu ki tablo SHA'ları doğrulanabilsin). Toplam font yükü ~1.09 MB;
oyunun görsel asset'leri (~7 MB) yanında kabul edilebilir. İki OFL metni
de Reserved Font Name bildirmiyor; ileride Latin subset'i alınırsa yalnızca
bu tablo ve SHA'lar güncellenmeli.
