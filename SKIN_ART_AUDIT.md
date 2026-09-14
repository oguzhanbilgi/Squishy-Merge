# SKIN_ART_AUDIT.md — skin sanatı ve gameplay render durumu

**Son güncelleme:** 2026-09-14 (M8.5-17: tier kimliği korunan karışım) · İlk audit: 2026-09-09 (M8.5-02).

> ## STATUS: final preview art complete / production gameplay skin pipeline complete
>
> M8.5-02'deki **"20 skin placeholder hue-shift verisidir"** ifadesi
> ARTIK GEÇERSİZ. Bu turda:
>
> | ne | durum |
> |---|---|
> | Koleksiyon / mağaza / vitrin önizlemeleri | **FİNAL** — owner'ın 20 önizleme sanatı, `assets/visual/skins/previews/skin_<rarity>_<ad>.png` |
> | Gameplay skin render'ı | **PRODUCTION** — gövde maskesi + seçici recolor + deterministik desen + rarity malzemesi (`assets/visual/skins/skin_body.gdshader`) |
> | `resources/skins/*.tres` | **FİNAL VERİ** — `tools/make_skin_resources.py` tablosundan üretilen 20 render profili (renk/desen/malzeme); id'ler değişmedi |
> | Eski `skin_tint.gdshader` + `tint` alanı | **SİLİNDİ** |
> | Epic/Legendary'nin önizlemedeki özel ifade/aksesuarları gameplay'de | **YOK, bilinçli** — aşağıda "Bilinen sınır" |

## 1. Final önizleme sanatı

- Kaynak: owner'ın ChatGPT partisi, `_visual_source/squishy_merge_final_skins_named.zip`
  (arşiv, repoda). Runtime kopyaları `assets/visual/skins/previews/`
  (1254×1254 RGBA, saydam zemin, dosya adı = `skin_<rarity>_<ad>`).
- Import: `process/size_limit=512` + `mipmaps/generate=true` (`.import`
  dosyaları repoda). 20 dokunun VRAM'i ~20 MB yerine ~5 MB; kartta 64–150
  px'e küçülürken mipmap'li filtre (`SkinSwatch` → `TEXTURE_FILTER_LINEAR_WITH_MIPMAPS`).
  Kaynak PNG'ler değiştirilmedi.
- Bağlantı: `SkinData.preview_texture` (ext_resource, .tres içinde).
  `SkinSwatch` sahip olunan skin'de bunu çizer (aspect-fit, `KEEP_ASPECT_CENTERED`),
  kilitlide silüet + kilit, varsayılanda orijinal tier-3 dumpling.
  Koleksiyon kartı, vitrin ve mağaza satırı aynı bileşen.
- **Kilitli görünürlük (polish):** mağaza satırı ve koleksiyon vitrini
  kilitli skin'i de **gerçek sanatıyla** gösterir (`setup(entry, true)`:
  hafif soluk + kilit rozeti) — oyuncu 900 Hamur'a ne aldığını görsün.
  Koleksiyon grid kartı silüet kalır (keşif hissi).
- Doğrulama: `tools/skin_test.gd` — 20 doku yükleniyor (≥256 px), 20'si
  farklı dosya, ad/rarity/id tablosu sabit, fiyatlar 50/150/400/900.

## 2. Gameplay render mimarisi

Tier sprite'ları (8 karakter, kendi silueti/yüzü/aksesuarı) **temel kalır**.
Skin yalnızca hamur gövdesini boyar ve desenler. 20×8 = 160 sprite ÜRETİLMEDİ.

```
SkinData (.tres profili)  ──►  SkinVisual._material_for(skin, tier)
                                    │  ShaderMaterial (skin_body.gdshader)
                                    │   - body_mask  = generated/body_mask_tier{tier}.png
                                    │   - body/shade/highlight/pattern*/gloss/pearl/sparkle
                                    ▼
DumplingVisual._refresh_skin() → sprite.material   (+ Legendary: SkinAura çocuğu)
```

### 2.1 Gövde maskeleri (`assets/visual/skins/generated/body_mask_tier1..8.png`)

`python tools/make_skin_masks.py [--debug <klasör>]` üretir; 8 gri maske,
tier dokusuyla aynı boyut, aynı UV. Beyaz = gövde, siyah = korunur.

Yöntem: opak piksel ∧ ton gövde merkezine yakın (tier başına merkez +
tolerans) ∧ V ≥ 0.40 (kontur/göz/ağız dışarıda) ∪ beyaz parlamalar; ardından
aynı tondaki aksesuar/yanaklar için elle **dışlama elipsleri** (tier 2 ve 7
yanak — gövdeyle aynı pembe; tier 6 yıldız; tier 7 fiyonk), tier 3 yaprak
doygunlukla ayrılıyor, tier 8 taç ve tier 5 fiyonk tonla ayrılıyor. Küçük
delikler kapatılır, kenar 1 px yumuşatılır. `--debug` kontrol karelerinde
kırmızı = korunan alan; sekiz tier'da göz/ağız/yanak/aksesuar korunduğu
görüldü.

### 2.2 Shader (`skin_body.gdshader`)

1. Gövde pikselinin **luminansı** okunur — gölge/ışık dağılımı sprite'ın.
2. Luminansa göre `shade_color → body_color → highlight_color` ile skin
   rengi hesaplanır; **M8.5-17:** bu renk tier'ın kendi gövde rengiyle
   `tint_strength` oranında karıştırılır (`tier_blend`: ton kayması ≤ ~32°,
   uzak tonlarda ton çekimi yok, doygunluk kısmen tier'dan) — **skin tier'ı
   değiştirir, yerine geçmez**; 8 tier her skinde ayırt edilir. Rarity
   varsayılanları 0.30 / 0.35 / 0.40 / 0.50 (Gökkuşağı 0.40, Sade 0 →
   materyal takılmaz). `gloss` orta-üst tonlara ek parlama.
3. Desen ailesi (`pattern_type`, 11 aile: NONE / SPECKLE / FLECK / RING /
   MARBLE / SWIRL / CRYSTAL / STREAK / WAVE / IRIDESCENT / METAL) hücre
   tabanlı hash veya sin alanlarıyla, **sprite UV'sinde** (parçayla döner
   ve ezilir, ekranda kaymaz). `detail_scale` tier'a göre: küçük parçada
   daha az ama daha büyük hücre (tier 1'de 4 px'lik benek okunmuyordu).
4. `pearl` (sedef, luminans+konum tabanlı ton döngüsü), `sparkle`
   (hücre başına faz kaydırmalı, TIME ile nabız atan glint'ler).
5. Sonuç `mix(src, body, mask)`; maske dışı piksel dokunulmaz.

Rastgelelik: `hash1/hash2` (deterministik), `TIME`. **Global RNG yok**
(`tools/skin_test.gd` "skin kozmetiği global RNG'yi tüketmiyor").

Godot 4 notu: fragment'taki `COLOR` = doku × modulate. Doku kendimiz
okunduğu için modulate `vertex()`'ten varying ile taşınıyor; `src * COLOR`
dokuyu ikinci kez çarpıyordu — **eski hue-shift'in "hiç görünmemesinin"
asıl sebebi buydu**, sadece zayıf tint değil.

### 2.3 Rarity katmanı

| rarity | gövde | malzeme | efekt |
|---|---|---|---|
| Common | renk + desen | gloss ≤ 0.35 | yok |
| Rare | renk + desen | gloss 0.15–0.4, Deniz Tuzu pearl 0.25 | yok (kristal glint statik+hafif twinkle) |
| Epic | renk + desen | gloss 0.5–0.6 | `sparkle` 0.3–0.4 (gövde içinde, animasyonlu) |
| Legendary | METAL / IRIDESCENT | gloss 0.6–0.9, pearl 0.2–0.7 | sparkle 0.6–0.7 + **aura** (`skin_aura.gdshader`, sprite'ın arkasında 6 kollu yumuşak parıltı, TIME ile nefes) |

Aura: `SkinVisual.attach_fx` sprite'a `SkinAura` çocuğu ekler
(`show_behind_parent`, sprite ile ölçeklenir/eğilir), paylaşılan
GradientTexture2D + tek materyal; parçacık yok, script yok. Skin değişince
/ varsayılana dönünce kaldırılır (test: "epic'e geçince aura kalktı",
"varsayılana dönüş: materyal ve aura yok").

Fizik, collider, CONTACT_FIT, squash/stretch, merge/skor: DOKUNULMADI.
Merge hayaleti materyali kopyalar (test: "ghost skin materyalini taşıyor").

### 2.4 Materyal paylaşımı / performans

(skin, tier) çifti başına bir ShaderMaterial (`SkinVisual._materials`);
bir round'da tek skin aktif → en fazla 8 materyal, aynı tier'daki tüm
parçalar aynı materyal. Ek doku örneği 1 (maske) + hücre döngüsü 3×3;
tier 8 (~130 px) ekranda en fazla birkaç tane. Android ölçümü M9'da.

## 3. 20 skin gameplay kimliği (`tools/make_skin_resources.py`)

| skin | gövde | desen |
|---|---|---|
| Sade | sıcak fildişi krem | — |
| Susamlı | fildişi/bej | siyah + açık susam benekleri (SPECKLE) |
| Kepekli | buğday/kepek bej | ince kahve kepek parçaları (FLECK) |
| Havuçlu | pastel havuç turuncusu | koyu turuncu parçalar (FLECK) |
| Yeşil Soğan | soluk taze yeşil | yeşil soğan halkaları (RING) |
| Mısır | mısır sarısı | altın mısır taneleri (FLECK) |
| Peynirli | kremsi peynir sarısı | düz, tereyağ parlaması (gloss) |
| Sarımsaklı | kavrulmuş sarımsak beji | seyrek kızarmış benek (SPECKLE) |
| Karabiber | biber beji / taupe | koyu biber benekleri (SPECKLE, yoğun) |
| Kırmızı Biber | paprika / mercan | kırmızı biber parçaları (FLECK) |
| Mantar | mantar taupe / karamel | yumuşak toprak mermeri (MARBLE) |
| Ispanak | ıspanak yeşili | koyu yaprak parçaları (FLECK) |
| Deniz Tuzu | aqua / buz camgöbeği | kristal glint'ler (CRYSTAL) + sedef |
| Zencefil | altın amber | sıcak girdap (SWIRL) |
| Acı Sos | biber turuncusu / kırmızı | sos çizgileri + parçalar (STREAK), gloss, sparkle |
| Yosun | derin deniz yeşili | dalga + kabarcık (WAVE), sparkle |
| Kakao | sütlü kakao | çikolata mermeri (MARBLE), gloss, sparkle |
| Safran | safran sarısı / amber | iplik girdabı (SWIRL), sparkle |
| Altın Hamur | cilalı altın | metalik bant + tane (METAL), pearl, sparkle, altın aura |
| Gökkuşağı | pastel sedef | yanardöner ton geçişi (IRIDESCENT), pearl, sparkle, lavanta aura |

QA kareleri: `tools/skin_gallery.gd` (rarity başına tier 1/4/8 + final
önizleme yan yana; tier 1 ×3 okunurluk; tier 8 detay; 8 skin için gerçek
gameplay merge anı). Kontrol edilen: yüz/yanak/aksesuar boyanmıyor, 20 skin
birbirinden ayrılıyor, tier 1'de renk kimliği okunuyor (desen küçük ama
var), aura kompakt, merge/parçacık/combo uyumlu.

## 4. Bilinen sınır (dürüst)

- **Epic/Legendary önizlemelerindeki özel ifade ve aksesuarlar** (Acı Sos'un
  biberi, Yosun'un incisi/kabarcıkları, Kakao'nun çikolata parçası, Safran'ın
  çiçeği, Altın Hamur'un tacı, Gökkuşağı'nın yıldız tacı) yalnızca
  **koleksiyon/mağaza önizlemesinde** var. Gameplay'de tier'ın kendi yüzü ve
  aksesuarı korunur; skin kimliği renk + malzeme + desen + rarity efektiyle
  taşınır. Bunları 8 tier'a taşımak **tier başına overlay art** (6 skin × 8
  tier = 48 küçük aksesuar parçası) ister — placeholder ile taklit edilmedi.
  Owner isterse ayrı bir art turu; sistem tarafında `SkinVisual.attach_fx`
  bu overlay'in takılacağı nokta.
- Tier 1 (~40 px) parçada desenler renk kadar okunmuyor (Susamlı/Karabiber
  benekleri görünüyor, Mantar/Kakao mermeri yalnızca ton olarak). Tasarım
  gereği: küçük parçada kimlik = renk.
- Maskeler dokuya göre kalibre; tier dokuları değişirse
  `make_skin_masks.py` yeniden çalıştırılmalı ve `--debug` ile bakılmalı.
- Android performans ölçümü (aura + shader, 35 parça) M9'da yapılacak.

## 5. Kapsam dışı (bu turda yapılmadı)

Yeni skin, fiyat/ekonomi değişikliği, kayıt formatı değişikliği, gameplay
UI/harita/tipografi yeniden tasarımı, M9 Android/AdMob/Billing.
