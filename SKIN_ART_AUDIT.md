# SKIN_ART_AUDIT.md — 20 placeholder skin'in durumu

**Tarih:** 2026-09-09 (M8.5-02) · **Amaç:** mevcut skin verisinin ne kadar
placeholder olduğunu objektif olarak ortaya koymak, karar için veri üretmek.
**Bu turda hiçbir isim veya renk değiştirilmedi.**

> ## STATUS: functional equip complete / final skin art pending
>
> **Current 20 skins are placeholder data; final skin art/rendering pending.**
>
> Bu, owner'ın M8.5-02 sonunda verdiği açık karardır. Aşağıdakilerin
> **hiçbiri final/production sanat olarak kilitlenmemiştir:**
>
> | ne | durum |
> |---|---|
> | `resources/skins/*.tres` içindeki 20 `tint` değeri | **placeholder veri** — prosedürel üretilmiş, isimlerle uyumsuz |
> | Gameplay skin renderer'ı (`skin_visual.gd` + `skin_tint.gdshader`) | **teknik proof-of-concept** — değiştirilebilir abstraction, final render tekniği değil |
> | Koleksiyon/mağaza kartlarındaki renkli daire önizlemeleri (`skin_swatch.gd`) | **placeholder** — final skin asset'i değil |
> | `SkinVisual.STRENGTH = 0.45` | geçici kalibrasyon, ekran görüntüsüyle seçildi |
>
> **Kilitli olan tek şey altyapıdır:** kayıt formatı (`equipped_skin`), equip
> API'si, koleksiyon seçim akışı ve renderer'ın *arayüzü*
> (`SkinVisual.apply/clear`). Sanat turu bunları değiştirmeden yalnızca
> render katmanını ve veriyi güncelleyebilir.
>
> **Değiştirilmeyecek olan:** 8 orijinal dumpling texture'ı
> (`assets/visual/dumpling_tier1..8.png`) ve kendi renkleri. Skin katmanı
> bunların ÜSTÜNE çalışır, onları kalıcı olarak değiştirmez.

## Kısa cevap

**Bu 20 skin mevcut hâlleriyle final mağaza içeriği olmaya görsel olarak
YETERLİ DEĞİL.** Sistem çalışıyor, veri çalışmıyor.

## Bulgu 1 — Renkler prosedürel üretilmiş, isimlerle ilgisi yok

20 skin'in tint'i tek bir **sabit 49.3° hue spirali**. Rarity sınırlarında
bile kesintiye uğramıyor: Common 345.3° ile biter, Rare 34.6° ile başlar
(345.3 + 49.3 mod 360). Doygunluk ve parlaklık rarity başına sabit.

| rarity | hue adımı | saturation | value |
|---|---|---|---|
| Common (8) | 49.3° | 0.350 | 0.980 |
| Rare (6) | 49.3° | 0.470 | 0.940 |
| Epic (4) | 49.3° | 0.590 | 0.900 |
| Legendary (2) | 49.3° | 0.710 | 0.860 |

Yani renkler bir renk çarkından otomatik dağıtılmış; hiçbiri malzemeye
bakılarak seçilmemiş.

## Bulgu 2 — Tam envanter

| id | display_name | rarity | tint (hex) | görünen renk | beklenen | eşleşme |
|---|---|---|---|---|---|---|
| `common_01` | Sade | Common | `faa2a2` | pembe-kırmızı | krem/hamur | ❌ |
| `common_02` | Susamlı | Common | `faeaa2` | soluk sarı | krem/bej | ✅ |
| `common_03` | Kepekli | Common | `c2faa2` | sarı-yeşil | kahve | ❌ |
| `common_04` | Havuçlu | Common | `a2facb` | nane yeşili | **turuncu** | ❌ |
| `common_05` | Yeşil Soğan | Common | `a2e1fa` | açık mavi | **yeşil** | ❌ |
| `common_06` | Mısır | Common | `aca2fa` | mor | sarı | ❌ |
| `common_07` | Peynirli | Common | `f4a2fa` | macenta | sarı | ❌ |
| `common_08` | Sarımsaklı | Common | `faa2b8` | pembe | beyaz/krem | ❌ |
| `rare_01` | Karabiber | Rare | `f0c07f` | açık ten | **siyah/koyu** | ❌ |
| `rare_02` | Kırmızı Biber | Rare | `c3f07f` | sarı-yeşil | **kırmızı** | ❌❌ |
| `rare_03` | Mantar | Rare | `7ff098` | yeşil | kahve/bej | ❌ |
| `rare_04` | Ispanak | Rare | `7febf0` | camgöbeği | koyu yeşil | ❌ |
| `rare_05` | Deniz Tuzu | Rare | `7f8ef0` | mavi-mor | beyaz | ❌ |
| `rare_06` | Zencefil | Rare | `cc7ff0` | mor | bej/tan | ❌ |
| `epic_01` | Acı Sos | Epic | `e65ea1` | pembe | kırmızı | ⚠️ |
| `epic_02` | Yosun | Epic | `e68b5e` | turuncu | koyu yeşil | ❌ |
| `epic_03` | Kakao | Epic | `d1e65e` | sarı-yeşil | kahve | ❌ |
| `epic_04` | Safran | Epic | `62e65e` | yeşil | koyu altın | ❌ |
| `legendary_01` | Altın Hamur | Legendary | `3fdbbb` | turkuaz | **altın** | ❌❌ |
| `legendary_02` | Gökkuşağı | Legendary | `3f7bdb` | tek renk mavi | **çok renkli** | ❌❌ |

**Sonuç: 1 uyumlu (Susamlı), 1 kısmen (Acı Sos), 18 uyumsuz.**

### En savunulamaz üçü

Bu üç isim rengi **doğrudan söylüyor**, dolayısıyla oyuncu hatayı anında
görür:

1. **Kırmızı Biber** → sarı-yeşil
2. **Altın Hamur** → turkuaz
3. **Gökkuşağı** → tek renk mavi (tek `tint` alanıyla yapısal olarak
   imkânsız; çok renkli bir skin ayrı bir teknik gerektirir)

## Bulgu 3 — Gameplay'de nasıl görünüyor

QA çekimi: 8 tier × (varsayılan + 4 rarity), tier'lar eşit boyuta normalize
edilmiş hâlde karşılaştırıldı (`tools/screenshot_runner.gd::_shot_skins`).

**Teknik olarak iyi** — `SkinVisual` katmanı istenen korumaları sağlıyor:
- yüz, göz, ağız ve konturlar dört rarity'de de tam okunuyor ✅
- spekuler parlamalar ve gövde shading'i korunuyor ✅
- düz flat recolor yok, tier'lar hâlâ birbirinden ayırt edilebiliyor ✅

**Ürün olarak zayıf:**
- **Common skin neredeyse görünmüyor.** "Sade" satırı varsayılan satırdan
  ayırt edilemiyor. Oyuncu kazandığı/satın aldığı ödülün etkisini göremiyor.
- Güç artırılırsa (`SkinVisual.STRENGTH`) Common görünür hâle gelir ama
  tier'lar tek renge yakınsar ve renkler **zaten yanlış** olduğu için sorun
  çözülmez, büyür.

## Karar seçenekleri (owner)

Bu turda hiçbiri uygulanmadı.

| # | seçenek | maliyet | not |
|---|---|---|---|
| A | 20 tint'i isimlere göre elle yeniden seç | düşük (20 satır `.tres`) | En hızlı düzeltme. Sistem hazır, sadece veri değişir. Gökkuşağı yine çözülmez. |
| B | İsimleri mevcut renklere uydur | düşük | Renk çarkı ürünü isimler yaratır ("Mor Dumpling"), tematik kaybı var. |
| C | Skin başına gerçek sprite/desen | yüksek | 20 skin × 8 tier = 160 asset. v1 için gerçekçi değil. |
| D | Desen/aksesuar katmanı (tek asset, tier'dan bağımsız) | orta | Renk yerine "susam serpme", "taç" gibi katmanlar. Daha okunur ödül hissi. |

**Öneri:** kısa vadede **A** (isimlere uygun tint'ler) + `SkinVisual.STRENGTH`
yeniden kalibrasyonu. Bu, mevcut equip altyapısına hiç dokunmadan yapılabilir
— `SkinVisual` tam da bu yüzden ayrı bir katman.

## Bu audit'in kapsamı dışında

- Skin isimlerini/renklerini sessizce yeniden tasarlamak
- Yeni skin eklemek
- Fiyat/ekonomi değişikliği
