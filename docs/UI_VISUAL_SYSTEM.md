# UI_VISUAL_SYSTEM.md — Squishy Merge production UI sistemi

**Durum:** M8.6-01 ile kuruldu, **kaynak dokümandır** — M8.6-02+ ekran işleri buna uyar.
**Kod kaynağı:** `scripts/ui/ui_tokens.gd` (sayılar) → `tools/make_ui_theme.gd`
(`assets/visual/ui_theme.tres` üretir) → `scripts/ui/ui_kit.gd` (bileşenler).
**Asset kaynağı:** `tools/make_ui_core.py` → `assets/visual/ui/core/**` +
`scripts/ui/ui_core_assets.gd` (üretilir, elle düzenlenmez).
**Galeri:** `tools/ui_system_gallery.tscn` (dev-only, 5 sayfa).
**Test:** `tools/ui_foundation_test.tscn` (164 kontrol), `tools/gameplay_shell_test.tscn` (147, §13), `tools/home_ui_test.tscn` (207, §14), `tools/map_ui_test.tscn` (127, §15), `tools/shop_ui_test.tscn` (212, §16), `tools/collection_ui_test.tscn` (164, §17), `tools/secondary_modal_ui_test.tscn` (102, §19), `tools/result_ui_test.tscn` (226, §20), `tools/revive_refill_ui_test.tscn` (266, §21).

Çakışma kuralı: owner'ın son talimatı > GAME_DESIGN.md > bu doküman > kod.
Bir sayı burada ve `ui_tokens.gd`'de farklıysa **doküman güncellenir, token
kazanır** (token tema üretimine girer, doküman girmez).

---

## 1. Formül (kilitli)

**LayerLab = YAPI, Squishy Merge = KİMLİK.**

| Katman | Kim veriyor | Ne |
|---|---|---|
| Yapı | LayerLab "GUI Pro – Casual Game" (beyaz, 9-slice) | panel/popup gövdesi, kart, liste satırı, buton geometrisi, kaynak pill'i, etiket/rozet gövdeleri, ilerleme rayı, anahtar, generic beyaz picto ikonlar |
| Kimlik | Owner sanatı (`assets/visual/`) | dumpling'ler, skin önizlemeleri, güç ikonları, Hamur, sandık, taç/yıldız/bayrak, kanatlı-kalp tepelik, candy-night zemin, gloss/candy hissi, VFX |
| Ses/ton | Palet + tipografi (§2, §3) | beyaz gövdeler `modulate` ile boyanır; kitte hiçbir renk kullanılmaz |

LayerLab bir temeldir, oyunun kimliği değildir. Bir bileşen "başka bir
paketten gelmiş", "fantezi RPG", "masaüstü", "web dashboard" ya da "ucuz neon
şablon" gibi okunuyorsa reddedilir.

---

## 2. Palet (`UiTokens`)

Tonlar owner asset'lerinden ölçüldü; `UiPalette` (M8.5 kabuğu) ile aynı sayılar.

| Rol | Token | Hex | Kullanım |
|---|---|---|---|
| Dünya | `WORLD_INDIGO` / `WORLD_INDIGO_MID` | `#0d153f` / `#2d2a6c` | zemin, karartma |
| Koyu plaka | `NAVY_PURPLE` / `NAVY_PURPLE_DEEP` | `#2a1f5c` / `#1a1440` | PanelBase, ResourcePill, PanelDark, ilerleme rayı |
| İkincil yüzey | `PLUM` | `#453885` | PanelPurple (HUD plakaları) |
| İçerik yüzeyi | `CREAM` / `CREAM_DEEP` | `#fcf7ec` / `#f1e9dc` | kart, modal, liste satırı |
| Lavanta | `LAVENDER` / `LAVENDER_SURFACE` | `#c694fa` / `#dccbe8` | ikon butonu, ikon kuyusu / ikincil buton |
| Gameplay HUD | `LAVENDER_DEEP` / `LAVENDER_LIGHT` / `TRAY_CREAM` / `GLASS_BLUE` / `GLASS_MUTED` | `#8b72dc` / `#ece3fb` / `#f3e9f9` / `#bfe6ff` / `#d9d4e8` | HUD v3 gövde / açık halka / güç tepsisi / madalyon cam disk / pasif disk (hud_target'tan ölçüldü) |
| Birincil CTA | `CYAN` / `CYAN_DEEP` / `CYAN_MUTED` | `#5eddf9` / `#2f8fd0` / `#8fbfd2` | ButtonPrimary, ButtonCTA, SectionTag; `CYAN_MUTED` = Mağaza "Hamur yetmiyor" SATIN AL'i (ButtonBuyLocked — dokunulabilir, pasif DISABLED'dan ayrık) |
| Satın alma / pozitif | `MINT` / `MINT_DEEP` | `#6ddc8b` / `#2f9e57` | ButtonPurchase, EquippedBadge, ilerleme dolgusu, anahtar açık |
| Vurgu | `PINK` / `PINK_DEEP` | `#f06aa8` / `#c94a86` | HeaderRibbon, ButtonRoundIcon (kapat), NewBadge, ButtonDanger |
| Premium | `GOLD` / `GOLD_BRIGHT` / `GOLD_DEEP` | `#ffd166` / `#fee85f` / `#b8731f` | **yalnız** Legendary, ödül anları, Badge (stok/level), fiyat metni (deep) |
| Pasif | `DISABLED` / `DISABLED_DEEP` | `#a19dba` / `#5c5878` | pasif buton gövdesi (açık, üstündeki koyu yazı ~4.8:1), LockBadge / LabelDisabled |
| Metin (krem üstü) | `TEXT_PRIMARY` / `TEXT_SECONDARY` / `TEXT_TERTIARY` | `#5c2952` / `#7a4a69` / `#a07f95` | başlık / gövde / not |
| Metin (koyu üstü) | `TEXT_ON_DARK` / `TEXT_ON_DARK_MUTED` | beyaz / beyaz %62 | HUD, kurdele |
| Metin (vurgu üstü) | `TEXT_ON_ACCENT` | `#0f2e4d` | cyan/nane/altın buton ve etiket yazısı |
| Fiyat / pozitif / uyarı | `TEXT_PRICE` / `TEXT_POSITIVE` / `TEXT_WARNING` | `#b8731f` / `#2f9e57` / `#d4762b` | LabelPrice / LabelPositive / LabelWarning |
| Rarity | `RARITY_COMMON/RARE/EPIC/LEGENDARY` | `#9aa0a6` / `#4c9be8` / `#a55cd6` / `#f0a92e` | `SkinData.rarity_color` ile aynı (testle kilitli) |

**Altın kuralı:** her şeyi altına boyama. Altın = Legendary, sandık/ödül anı,
level/stok rozeti, fiyat rakamı. Birincil CTA **cyan**, satın alma **nane**.

Gölge: `SHADOW_SOFT` (4 px, α .22) / `SHADOW_NORMAL` (8, .35) / `SHADOW_ELEVATED`
(16, .45) — StyleBoxFlat çizimlerinde; 9-slice gövdeler gölgeyi dokudan taşır.
Parıltı: `GLOW_SUBTLE` (pembe α .35, pencere) / `GLOW_PREMIUM` (altın α .6,
Legendary ödül).

---

## 3. Tipografi (değişmedi — M8.5-09)

| Rol | Font | Boyut | Variation (krem / koyu) |
|---|---|---|---|
| Display | Baloo 2 ExtraBold | 42 | `LabelDisplay` / `LabelDisplayOnDark` |
| Title | Baloo 2 ExtraBold | 32 | `LabelTitle` / `LabelTitleOnDark` |
| Section | Baloo 2 Bold | 24 | `LabelSection` / `LabelSectionOnDark` |
| Section (vurgu üstü) | Baloo 2 Bold | 20 | `LabelSectionOnAccent` (SectionTag içi) |
| Stat | Nunito Bold | 20 / 22 | `LabelStat` / `LabelStatOnDark` (gölgeli) |
| Body | Nunito SemiBold | 19 | `LabelBody` / `LabelBodyOnDark` |
| Caption | Nunito SemiBold | 15 | `LabelCaption` / `LabelCaptionOnDark` |
| Price | Nunito Bold | 21 | `LabelPrice` (koyu altın) |
| Positive / Warning | Nunito Bold | 18 | `LabelPositive` / `LabelWarning` |
| Disabled | Nunito SemiBold | 18 | `LabelDisabled` |
| Badge | Baloo 2 Bold | 16 / 14 | `LabelBadge` / `LabelBadgeOnDark` |
| HUD skor / HUD başlık | Nunito Bold | 30 / 13 / 13 | `LabelHudScore` (gölgeli) / `LabelHudCaption` (beyaz %62) / `LabelHudCaptionDark` (krem üstü ikincil erik) — M8.6-02 |
| Buton | Baloo 2 Bold | 22 | ButtonPrimary/Secondary/Purchase/Danger |
| Kahraman CTA | Baloo 2 ExtraBold | 28 | ButtonCTA |

Kural: **başlık ve CTA Baloo, veri ve gövde Nunito.** M8.5 rolleri (`Display`,
`ScreenTitle`, `Stat`, `HudPrimary`, `SecondaryButton`, `TabButton` …) temada
aynen duruyor; production ekranlar onları kullanmaya devam ediyor.

---

## 4. Boşluk ve ölçü

| Token | Değer |
|---|---|
| `SPACE_XS/SM/MD/LG/XL` | 4 / 8 / 12 / 20 / 32 |
| `RADIUS_SMALL/MEDIUM/LARGE` | 12 / 20 / 28 (StyleBoxFlat için; 9-slice kendi köşesini taşır) |
| `HEIGHT_COMPACT/NORMAL/LARGE/HERO` | 44 / 56 / 72 / 88 — Button01 gövdesi sırasıyla 44 / 58 / 72 / 88 px sabit yükseklik |
| `TOUCH_MIN` | 48 (ikon butonu ≥ 56 önerilir) |
| `ICON_SMALL/MEDIUM/LARGE/HERO` | 24 / 32 / 48 / 72 |

Tasarım tuvali 720 px genişlik (`canvas_items` + `expand`); 540×960 aynı
kompozisyonun 0.75'i, 1080×2340 ise 720×1560'ın 1.5'i. Tüm dokular 720 tuvali
için önceden ölçeklendi (§8).

---

## 5. Panel rolleri

| Variation | Gövde | Renk | Rol |
|---|---|---|---|
| `PanelBase` | `panel_round` | lacivert α .94 | koyu dünyada sade plaka (ayar satırı, liste zemini) |
| `PanelPurple` | `panel_bevel` (+ `UiKit.plate` üst ışığı) | erik | HUD skor/hedef plakası |
| `PanelDark` | `panel_bevel` | koyu lacivert | HUD ikincil plaka, alt sekme zemini adayı |
| `PanelCream` | `popup_body` | krem | geniş içerik yüzeyi (ödül bloğu) |
| `PanelModal` | `popup_body` | krem, üst 56 px boş | pencere gövdesi — `UiKit.modal_frame` kurdele + kapat + parıltı ekler |
| `PanelCard` | `card_large` | krem | mağaza/koleksiyon kartı |
| `PanelElevated` | `card_bevel` | krem | küçük yükseltilmiş kart ("Sıradaki") |
| `PanelListRow` | `list_row` | `CREAM_DEEP` opak | sahip olunan skin satırı, ayar satırı — kartla aynı vanilya ailesi, bir ton geri (alfa ile gri kaçmaz) |
| `PanelHud` | `panel_bevel` (+ `UiKit.plate` üst ışığı) | erik, dar dikey pay (4/10) | gameplay skor / hedef plakası (M8.6-02) |
| `PanelStrip` | `panel_bevel` (+ üst ışık) | erik α .94 | evrim şeridi rafı (M8.6-02) |
| `PanelHudScore` / `PanelTray` / `PanelHudFrame` / `PanelHudCard` | `label_round` ×4 | `LAVENDER_DEEP` / `TRAY_CREAM` / `LAVENDER_DEEP` / krem | HUD v3: skor kapsülü, güç tepsisi, kart çerçevesi, kart gövdesi (§13.3) |
| `PanelMapPlaque` | `badge_round` | krem | Harita düğüm plakası (OYNA / Rekor N / Level 10'u bitir) — §15.2 |
| `PanelShopCard` / `PanelShopCardPower` / `PanelShopCardOwned` | `card_bevel_soft` | krem / `TRAY_CREAM` / `CREAM_DEEP` | Mağaza ürün kartı gövdesi (satılık skin / güç — gameplay güç tepsisinin tonu / sahip olunan skin, bir ton geri) — §16.2, §16.3 |
| `PanelShopSection` | `title_oval` | `LAVENDER_DEEP` | Mağaza bölüm plakası (GÜÇLER / SKİNLER) — `UiKit.section_header`, §16.1 |
| `PanelShopToast` | `title_oval` | pembe (başarıda `MINT` + lacivert yazı override) | Mağaza geri bildirim plakası — §16.4 |
| `PanelCollectionCard` / `PanelCollectionCardLocked` | `card_bevel_soft` | krem / buzlu lavanta-krem (`CREAM_DEEP`→`LAVENDER_SURFACE` %38) | Koleksiyon galeri kartı gövdesi (sahip olunan / kilitli) — `CollectionSkinCard`, §17.3 |

Owner'ın candy paneli (`panel_candy` + kanatlı-kalp tepelik) kimlik katmanıdır:
pencerelerde `modal_frame` iskeletinin **üstüne** tepelik olarak eklenir ya da
iskeletin yerine kullanılır — kitin düz krem gövdesi tek başına kimlik taşımaz.

---

## 6. Buton hiyerarşisi

| Variation | Gövde | Renk / yazı | Ne zaman |
|---|---|---|---|
| `ButtonCTA` | `btn_cta` (88) | cyan / lacivert Baloo EB 28 | ekranda **bir** kahraman eylem: OYNA, DEVAM ET, HARİKA. `UiKit.cta(title, subtitle, icon)` iki satır + picto |
| `ButtonPrimary` | `btn_normal` (58) | cyan / lacivert | kart/satır birincil eylemi (skin SATIN AL, Haritaya Git) |
| `ButtonPurchase` | `btn_normal` | nane / lacivert | Hamur harcayan satın alma, ödül alma |
| `ButtonSecondary` | `btn_normal` | lavanta yüzey / erik | Kapat, Bitir, Vazgeç |
| `ButtonDanger` | `btn_normal` | pembe / beyaz | geri alınamaz (sıfırla, sil) — nadir |
| `ButtonIcon` | `btn_square` | lavanta / beyaz picto | ayarlar, geri, ses |
| `ButtonRoundIcon` | `btn_circle` | pembe / beyaz picto | pencere kapat |
| `ButtonResourceAdd` | `resource_btn` | nane | pill'deki "+" (mağaza kısayolu) |
| `PowerSlot` / `PowerSlotArmed` / `PowerSlotEmpty` | `btn_circle` (80×84 madalyon) | krem / cyan / açık lavanta | gameplay güç slotu — `UiKit.power_slot`, §13.4 |
| `ButtonHud` / `ButtonHudExit` | `btn_square` (56) | `LAVENDER_DEEP` / pembe, picto 34 | gameplay köşe butonları — `UiKit.hud_icon_button`, §13.3 |
| `ButtonFeature` / `ButtonFeatureLocked` | `btn_circle` (96×100 madalyon) | krem / açık lavanta | Ana Sayfa hub madalyonu — `HomeFeatureButton`, §14.2 |
| `ButtonHomeIcon` | `frame_round20` (56, düz plaka = alt dudak) | koyu lavanta | Home "oturmuş" ikon butonu — `UiKit.home_icon_button`, §14.5 |
| `ButtonHomePill` | `label_round` | `LAVENDER_DEEP` | Home level pill'i (altın taç rozeti + SIRADAKİ / Level N) — §14.1 |
| `ButtonHomeAdd` | `btn_circle_flat` (48) | nane | Home pill'inin yuvarlak "+" (koyu nane taban + gloss + picto) — `UiKit.home_pill` |
| `ButtonMapNode` / `ButtonMapNodeLocked` / `ButtonMapEndless` | `btn_circle` (72–116 madalyon) | cyan / açık lavanta / altın | Harita yolculuk düğümü — `MapLevelNode`, §15.2 |
| `ButtonBuyLocked` | `btn_normal` (58; mağazada 64'e gerilir) | soluk cyan `CYAN_MUTED` / lacivert-mor `NAVY_PURPLE` yazı | Mağaza "Hamur yetmiyor" SATIN AL'i — hâlâ satın alma butonu okunur, `disabled` DEĞİL, dokununca geri bildirim (`UiKit.candy_button` + `set_candy_button_variation`), §16.4 |
| *(kaydırılabilir candy buton)* | `UiKit.candy_button` + `make_candy_button_scrollable` (**`MOUSE_FILTER_PASS`**) | — | Mağaza SATIN AL (06.3): basış ScrollContainer'a da ulaşır, butondan başlayan sürükleme kaydırır; kart `NOTIFICATION_SCROLL_BEGIN`'de `release_candy_button` (yazı dudağı + 0.94) — Koleksiyon kartı deseni, §16 |
| *(Koleksiyon kartı)* | `CollectionSkinCard` = stilsiz `Button` (StyleBoxEmpty, **`MOUSE_FILTER_PASS`**) + çocuk katmanlar | — | galeri kartının tamamı dokunma hedefi; PASS: olay ScrollContainer'a da ulaşır (STOP olsa parmak kartın üstündeyken kaydırma hiç başlamazdı); kaydırma başlayınca BaseButton basışı iptal eder (`NOTIFICATION_SCROLL_BEGIN`) ve kart `UiMotion.release` ile 0.94'ten döner, §17.3 |

Durumlar (hepsi temada): **normal**, **hover** (%6 açık), **pressed** (%12
koyu + içerik 3 px aşağı), **disabled** (açık lavanta-gri gövde `#a19dba` +
koyu yazı/ikon `TEXT_DISABLED #33304d`, ≈ 4.8:1 — testle kilitli; cyan/nane
ile karışmaz).

**Dikey hizalama (ölçüldü):** Baloo 2'nin büyük harf mürekkebi Godot'un
satır kutusu merkezinin üstüne düşer ve pill'in görsel merkezi (gölge hariç)
dikdörtgen merkezinin üstündedir. İçerik margin'leri ekran görüntüsünden
piksel sayarak seçildi: 58 px gövde **10/10** (mürekkep merkezi 26.5, pill
26), 88 px CTA **14/16** (42 / 41.5). Yeni bir buton yüksekliği eklenirken
aynı ölçüm tekrarlanır; gözle offset verilmez. Basış hissi `UiMotion.attach_press` (0.94 ölçek + `ui_tap` sesi) —
`UiKit.button/icon_button/cta` bunu otomatik bağlar; ikinci bir animasyon
sistemi YOK. **Aynı-kare koruması (M8.6-06.2 A36 kapısı):** basış ve bırakış
aynı karede işlenirse press-in tween'i henüz adım atmamıştır (scale 1.0 ama
tween canlı); `_press_out` yalnız scale'e bakıp erken dönerse buton 0.94'te
asılı kalırdı (cihazda geri butonu ilk basıştan sonra kalıcı küçük kaldı).
`_press_in` `ui_motion_pressed` meta'sını koyar, `_press_out` bu işaret
varken her zaman yeniden başlatır (`collection_ui_test` aynı-kare tıklama
kontrolü).

Eski dev neon-mavi pill (`Button` varsayılanı) ve M8.5-08 candy pill CTA'sı
(`CandyButton`) **M8.6-10 ile runtime'dan tamamen kalktı** (son kullanıcıları
Devam + Refill idi); her yerde aynı `ButtonCTA`/`ButtonPrimary`/
`ButtonPurchase`/`ButtonSecondary` ailesi. Pasif kahraman CTA:
`UiKit.set_cta_enabled(button, false)` — gövde temadan (DISABLED), iki satır
+ picto `TEXT_DISABLED` (Godot `font_disabled_color` çocuk etiketlere
uygulanmaz; sebep yazısıyla birlikte okunur kalır, basılabilir görünmez).

---

## 7. İkon kuralları

**Generic picto (LayerLab, beyaz, 128 px, `UiKit.icon(role)`):** back, close,
settings, sound_on/off, vibration, info, help, home, shop, collection, map,
check, lock, unlock, plus, minus, arrow_next/prev/up/down, gift, trophy, play,
pause, movie (reklam), refresh, target, goal, calendar, confirm, bell.
Renk `tint` ile; koyu yüzeyde beyaz, cyan/nane üstünde `TEXT_ON_ACCENT`.

**Owner sanatı (asla picto ile değiştirilmez):** Hamur (`icon_dough`), dört güç
ikonu, skin önizlemeleri, dumpling tier'ları, sandık, taç/yıldız/bayrak HUD
rozetleri, kanatlı kalp, logo. `UiKit.art(texture, box)` ile kutulanır.

M8.5-10'daki 14 Free Casual GUI ikonu (`assets/visual/ui/icons/`, `UiPalette.ICON_*`)
**M8.6-10'da repodan kaldırıldı** (tek tüketicisi `UiPalette` idi, o da emekli);
bütün roller LayerLab picto setinden. Unity Asset Store EULA endişesi böylece
kapandı (`assets/visual/CREDITS.md`).

---

## 8. Kaynak pill'i, rozetler, rarity

**ResourcePill** (`UiKit.resource_pill(icon, value, with_add)`): `resource_bar`
koyu lacivert gövde + oyun ikonu 40 px + `LabelStatOnDark` + isteğe bağlı nane
`+`. Değer `UiKit.set_pill_value` ile güncellenir (pop). Dört sekmede aynı pill.

**Rozetler** (`UiKit.badge(text, variation, icon_role)`):

| Variation | Gövde | Renk | Örnek |
|---|---|---|---|
| `Badge` | `badge_round` | altın | stok ×4, level 4 |
| `CountBadge` | `badge_round` | altın, dar | 12/20 |
| `NewBadge` | `badge_round` | pembe | YENİ |
| `LockBadge` | `badge_round` | koyu gri | kilit + "Kilitli" |
| `EquippedBadge` | `frame_round20` | nane | tik + TAKILI |
| `OwnedBadge` | `frame_round20` | açık nane (`MINT`→beyaz %55) | nane tik + SAHİPSİN (mağaza, sahip olunan ama takılı olmayan skin; nane ailesi = "senin") — §16.3 |

**Etiketler:** `HeaderRibbon` (`header_ribbon`, pembe; lavanta/altın `tint`
ile — beyaza indirgenmiş LayerLab kurdelesi), `SectionTag` (`label_trapezoid`,
cyan varsayılan; pembe/nane/altın).

**Rarity:** `RarityCommon/Rare/Epic/Legendary` = trapez etiket (Common %12
koyulaştırılır ki kremde okunsun), `RarityFrameCommon/…/Legendary` = `item_frame`
rarity renginde skin önizleme çerçevesi. Legendary ödülde ek `GLOW_PREMIUM`
(`item_focus`). Tonlar `SkinData.rarity_color` ile birebir (test).
**Oyuncuya görünen rarity adı Türkçe (M8.6-06):** `SkinData.rarity_display_name`
(Yaygın / Nadir / Epik / Efsanevi) ve `rarity_display_upper` (YAYGIN / NADİR /
EPİK / EFSANEVİ — Godot `to_upper` Türkçe İ'yi bilmez, elle); `UiKit.rarity_tag`
bunu yazar (Koleksiyon + Mağaza kartı + Mağaza onayı + Round sonu ödül kartı, M8.6-09).
İç ad `rarity_name` (Common…) variation kimliği ve id öneki olarak
DEĞİŞMEDİ. `ChestReward.title()` de Türkçe büyük harf (TESELLİ / YAYGIN …).

**İlerleme:** `ProgressBarMint` (hedef, koleksiyon), `ProgressBarGold` (premium).
**Anahtar:** `UiKit.switch_toggle(on)` → `UiToggle` + `SwitchOn/SwitchOff`
rayı + LayerLab topuzu; pasifken bütünüyle %55 soluk.

---

## 9. LayerLab USE / MAYBE / REJECT politikası

Ham paket `_visual_source/layerlab_casual_game/` (owner lisanslı, **repoda
değil**, `.gdignore`'lu). Production **hiçbir zaman** `_visual_source/`'a ya da
`unitypackage`'a referans vermez (`ui_foundation_test` tarar). Türetme:
`python tools/make_ui_core.py` (Pillow; Unity `.meta` `spriteBorder` → Godot
9-slice; 1440p parçalar 720 tuvali için 0.5/0.4/0.3 ölçekli).

**USE (promote edildi → `assets/visual/ui/core/`):**
`panels/` popup_body/light/topline/glow, panel_round, panel_bevel(+light),
card_large (CardFrame08), card_bevel (CardFrame03; `card_bevel_soft` = SOFTEN
türevi, HUD v5), card_flat/border
(CardFrame01), list_row, item_frame(+inner), item_circle(+inner), item_focus,
border_round(+thin), frame_round12/20 ·
`buttons/` btn_cta/large/normal/compact (Button01 175/145), btn_bevel(+light,
+soft: SOFTEN türevi — siyah çizgi tint×0.44),
btn_square/sm/flat, btn_circle/flat ·
`labels/` label_round, badge_round, label_trapezoid, label_bubble,
label_ribbon(+light), title_oval ·
`resources/` resource_bar, resource_btn(+light), resource_add ·
`progress/` slider_bg/fill, slider_thin_bg/fill, slider_fill_sm ·
`badges/` alert_dot(+ring) ·
`icons/` 32 beyaz picto.

**MAYBE → kontrollü kabul:** `header_ribbon` (Title_Ribbon renkli → parlaklık
tabanlı beyaza indirgeme, γ 3, modulate ile boyanır), `switch_track/knob`
(beyaz tabanlar), `checkbox_*` (beyaz tabanlar; henüz bir bileşen kullanmıyor).
**MAYBE → alınmadı:** StarGrade (owner yıldızı var), renkli Lock (owner kilidi
var), Level slider rozetleri, bottom-sheet popup'lar (v1'de yok).

**REJECT (asla):** renkli Button01/02/03 varyantları, RPG item/rün/klan/bayrak
ikonları, sandık/coin/gem/pouch ikonları, pass/IAP/ADRemove rozetleri,
altıgen buton/kalkan, Title_Flag, brawler HUD (kill banner, minimap, joystick,
roulette), demo karakterler, Lilita One fontu, Unity prefab/shader/material/
script/anim.

Spike (`task/ui-layerlab-style-spike`, `assets/visual/ui/layerlab_spike/`)
production'a taşınmadı; asset yollarında "spike" kelimesi yok.

---

## 10. Squishy Merge özel geçersiz kılmaları

- **Pencere tepeliği:** kanatlı kalp / karakter tepeliği `modal_frame` üstüne
  ekran tarafında eklenir (`panel_candy_crown`).
- **Candy CTA dokusu:** owner'ın `cta_button_normal` pill'i yalnız M8.5
  ekranlarında; M8.6'da `ButtonCTA` tek CTA'dır. Owner yeni CTA sanatı verirse
  `btn_cta` ile aynı 9-slice geometrisine türetilir, variation adı değişmez.
- **Güç butonu (HUD):** `UiKit.power_slot` — `btn_bevel` + `btn_bevel_light` +
  owner güç ikonu + `Badge` stok rozeti + seçili slotta cyan `item_focus`
  (M8.6-02, bkz. §13.4).
- **Ödül/VFX:** `GLOW_PREMIUM` yalnız Legendary; sandık açılışı owner sanatı.

---

## 11. Responsive ilkeler

- Tüm ölçüler 720 px tuvale göre; `canvas_items` + `expand` yüksekliği serbest
  bırakır. **Dikey kompozisyon iki referansta doğrulanır:** 720×1280 (16:9) ve
  720×1560 (19.5:9, A36).
- 9-slice gövdeler yalnız orta bölgede esner; köşe/bevel piksel sabittir —
  bir gövdeyi minimumunun altına küçültme (Button01 sabit yükseklik; küçük
  rozet için `badge_round`).
- Picto ikonlar 128 px kaynaktan `ICON_*` boyutlarına küçülür (1.5× cihazda
  48–108 px, keskin). Owner sanatı zaten 512 px + mipmap.
- Dokunma hedefi ≥ 48 px; ikon butonu 56–64.
- Krem/koyu kontrast: krem üstünde `TEXT_PRIMARY` (≈ 9:1), koyu üstünde beyaz;
  cyan/nane üstünde lacivert (≈ 7:1). Pasif yazı `TEXT_DISABLED` (`#33304d`)
  açık gri gövdede ≈ 4.8:1 — pasif olduğu belli, telefonda okunur.

---

## 12. Android görsel QA kuralı

Her büyük UI işi (M8.5-17 kapısı): otomatik testler → masaüstü çekimler
(`tools/ui_system_gallery.tscn -- shots <dir>`, 720×1280 / 720×1560 / 540×960 /
1080×2340) → debug APK (`import_etc2_astc` açık, preset `exclude_filter`
`build/*` içerir, `build/.gdignore` var) → `adb install -r` → Samsung SM-A366B'de
başlat → `adb exec-out screencap` → çekimler `build/qa_<görev>/device/`.
Galeri cihazda **geçici** `run/main_scene` değişimiyle açılır; export sonrası
`project.godot` geri alınır (`git diff project.godot` boş). Kontrol listesi:
dokunma hedefi, keskinlik, 9-slice bütünlüğü, font, buton kontrastı, kaynak
pill'i, modal/kart görünümü. Fiziksel kurulum + başlatma olmadan "cihazda
doğrulandı" denmez.

---

## 13. Gameplay Shell (M8.6-02)

**Kod:** `scripts/ui/gameplay_layout.gd` (bölge sözleşmesi + kamera sığdırma),
`scripts/ui/gameplay_hud.gd` (HUD katmanı), `scripts/ui/power_bar.gd`
(`UiKit.power_slot` x4), `scripts/ui/evolution_strip.gd`, `game_board.gd`
`_draw*` (kap kabuğu). **Test:** `tools/gameplay_shell_test.tscn` (146 kontrol).
**Çekim:** `tools/shell_shots.tscn -- <dir> [GxY]` (10 durum × 4 boyut).

### 13.1 Bölge sözleşmesi (responsive)

720 px tuval, yükseklik serbest (16:9 → 1280, 19.5:9 → 1560; 540×960 aynı
kompozisyonun 0.75'i, 1080×2340 1560'ın 1.5'i). Dikeyde dört bölge:

| Bölge | Yükseklik | İçerik |
|---|---|---|
| **HUD** | sabit: `max(SAFE_TOP 10, cihaz üst güvenli pay + 4) + ROW1 62 + 8 + ROW2 96` = 176 (A36 punch-hole: 92 px fiziksel = 61 tuval px → 231) | satır 1: Geri+Ayarlar · Skor · Sıradaki+Çıkış; satır 2: tepsi(2 güç) · Hedef kartı · tepsi(2 güç) |
| **BOARD** | esnek: kalan alanın tamamı | fizik penceresi (kamera ile sığdırılır) |
| **STRIP** | sabit 64 (+8 üst, +10 alt pay); kap BOARD'u doldurmuyorsa kabın tabanına yaklaşır (`hug_strip`) | evrim şeridi |
| **BANNER** | `GameplayLayout.banner_height()` — v1'de **0** | gelecek AdMob banner seam'i |

Üst güvenli pay `GameBoard._detect_safe_top` (`DisplayServer.get_display_safe_area`,
pencere → tuval ölçeği) ile okunur; A36'da punch-hole skor plakasının tam
üstüne düşüyordu (cihaz kapısında yakalandı), HUD payın altına iner, BOARD
küçülür, geri kalan hiçbir şey oynamaz.

Kurallar: kontroller yalnız HUD'da, BOARD ve BANNER'a hiçbir kontrol girmez;
HUD/strip/slot **ölçeklenmez**; fazla dikey alan BOARD'a gider. Banner
geldiğinde `set_banner_height(h)` çağrılır → STRIP ve BOARD yukarı kayar, HUD
yerinde kalır, gameplay yeniden yazılmaz (test: banner 0 ve 100 için çakışma
yok, seam'e kontrol/board girmiyor).

### 13.2 FLOOR_Y / kamera sığdırma

Fizik referans koordinatında kalır (`FLOOR_Y 1180`, `RIM_ABOVE_LINE 420`,
`playable_height 400`, duvar 20, kap genişlikleri — **hiçbiri değişmedi**).
`GameBoard.reference_frame()` = düşürme çizgisinin 60 üstünden taban eteğinin
6 altına, duvar (30) + 12 yan pay. `GameplayLayout.fit_board(frame, board,
view)` zoom = min(en, boy), tavan **1.2**; fazla dikey alanın yarısı kabın
üstüne (düşürme bölgesi), yarısı altına — şerit kabın tabanına yaklaştığı
için alttaki pay en alta (gelecek banner üstüne) toplanır. Girdi `screen_to_world`, HUD'daki
dünya-bağlı öğeler (ipucu) `world_to_screen` ile çevrilir. Sonuç: 720×1280'de
w600 kap zoom ≈ 0.99, 720×1560'ta 1.05 (genişlik sınırı), dar kaplar 1.2;
sonsuz (720) 0.90 — duvarlar ilk kez sonsuz modda da görünür. Alt ölü alan
yok; 1280'de kap tabanı şeridin hemen üstünde.

### 13.3 HUD hiyerarşisi (HUD v5 — `_visual_source/references/gameplay_hud_target/hud_target.png`)

Görsel hedef owner'ın onayladığı mockup; **logo yok** (tek bilinçli fark).
Dekor katmanı kuralı: `PanelContainer` dış dekoru içine alıp minimuma kattığı
için gölge/halka `GameplayHud._deco_back`, tepsi gloss'u + madalyon yuvaları
`_deco_mid` (tepsi üstü / madalyon altı), gloss/yıldız `_deco_front`
kontrollerine `UiKit.hud_attach` ile bağlanır ve plakanın dikdörtgenini izler.

**v4 "candy plate" reçetesi (düz label_round kutu hissi kaldırıldı):** gövde
pişmiş dudaklı sprite (`btn_bevel` çizgi+bevel: skor, kart çerçevesi, köşe
butonları, level rozeti; `card_bevel` yumuşak alt dudak: krem kart, tepsi;
`title_oval` pill: Sıradaki; `frame_round12`: portre; `label_trapezoid`: yüzde
pili) → `hud_shadow` (`popup_glow` bulanık blob, 8 px aşağı) → `hud_rim`
(`card_bevel`/`btn_bevel` 4–5 px açık lavanta / koyu lavanta) → `hud_gloss`
(`btn_bevel_light` üst şerit) → köşe butonlarında `border_round_thin` iç
parlama. Madalyon: dış krem halka 7 px + altın halka 4 px + cam-mavi disk +
tepside `item_circle` yuva; silahlıda `popup_glow` cyan hale.

**v5 yumuşatma (siyah çizgi/sert gölge → candy/plastik):** LayerLab
`btn_bevel`/`card_bevel` sprite'larının pişmiş SİYAH çizgisi modulate ile
boyanmıyordu (çarpan → siyah kalır); `tools/make_ui_core.py SOFTEN` ile
`btn_bevel_soft` / `card_bevel_soft` türetildi: çizgi 0.44 griye kaldırıldı
(tint × 0.44 → erik / koyu altın / koyu gül), dış gölge pikselleri yarı alfa.
HUD gövdeleri bu sürümleri kullanır. `hud_shadow` erik `(0.22, 0.09, 0.36)`,
α .20–.26, yayılım 14 px (siyah .42/10 px değil). `hud_rim` varsayılanı
`frame_round20` (düz beyaz yuvarlak plaka — pişmiş çizgisi yok → temiz açık
lavanta kenar). Tepsi `title_oval` pill: krem üst yüzey, altında 9 px aşağı
taşan `LAVENDER_DEEP` pill (alt derinlik) + 3 px `LAVENDER_LIGHT` kenar —
tek parça organik taban. Skor kapsülünün arkasında geniş, düşük alfa
`LAVENDER_DEEP` `popup_glow` backing + sol üst 14 px / sağ alt 10 px altın
pırıltı. Hedef çerçevesi `LAVENDER_DEEP`→`LAVENDER_LIGHT` %14 (pastel),
çubuk rayı `NAVY_PURPLE` (near-black `NAVY_PURPLE_DEEP` yalnız yüzde pilinde).
Köşe butonu iç parlama α .16, gölge 4 px/α .20. Yerleşim, davranış, board,
şerit, danger, mola akışı DEĞİŞMEDİ.

1. **Skor** — `PanelHudScore` (`btn_bevel_soft` koyu lavanta-mor `LAVENDER_DEEP`)
   + mor backing + `hud_shadow` (6 px, α .26) + `hud_rim` (`LAVENDER_LIGHT` 5 px)
   + üst `hud_gloss` + 2 pırıltı; solda owner yıldızı 40, beyaz "SKOR" + beyaz `LabelHudScore`
   34, sağ uçta 12 px yıldız aksanı. Ekran merkezinde. "+N" pop'u kartın sağ
   omzundan (`score_pop_home`: üst kenarın 12 px üstü) yayla büyüyüp 14 px
   yükselerek 0.6 s'de söner (altın, `LabelSectionOnDark`).
2. **Hedef kartı** — `UiKit.hud_card(back, front, with_stars=true)`:
   `PanelHudFrame` (`label_round` `LAVENDER_DEEP`, 6/6/6/8) içinde `PanelHudCard`
   (`label_round` krem) + gölge + açık halka + gloss + çerçeve kenarlarında
   altın yıldız. İçerik: altın `label_round` level rozeti (taç 30 üstte, Baloo
   24 numara; sonsuzda "SONSUZ" 15) · sütun: "HEDEF"/"REKOR"
   (`LabelHudCaptionDark`, lavanta-mor) → krem-derin pill içinde hedef
   portresi 30 + ad (`LabelSection` Baloo 22, mor) → `ProgressBarHud`
   (`slider_thin_bg` koyu mor ray + `slider_fill_sm` nane, 18 px) sağ ucunda
   "%N" `LabelBadgeOnDark`. Skor hedefi ad satırının sağında 12 px.
3. **Sıradaki** — aynı `hud_card` (150×62): "SIRADAKI" + tier dokusu 38.
   (Mockup'taki konuşma balonu kuyruğu bilinçli olarak yok — kuyruk sağ
   tepsinin üstüne taşıyordu.)
4. **Geri / Ayarlar / Çıkış** — `UiKit.hud_icon_button`: `ButtonHud`
   (`btn_square` `LAVENDER_DEEP`, picto 34) / `ButtonHudExit` (pembe) + gölge
   + açık halka + gloss; 56 px. Çıkış'ta "ÇIKIŞ" yazısı yok (56 px'te
   okunmuyor). Geri/Çıkış → Mola (§13.9), Ayarlar → ayarlar (board donar).
5. **Güç tepsileri** — `PanelTray` (`label_round` `TRAY_CREAM`) + gölge +
   `LAVENDER_DEEP` halka; içinde ikişer madalyon (80×84): `btn_circle` krem
   gövde, altın halka, cam-mavi iç disk (`GLASS_BLUE`; silahlı cyan; stok 0
   `GLASS_MUTED` + açık lavanta gövde, sanat renkli-soluk), sağ üst altın ×N,
   stok 0'da sağ ALT nane "+".
6. Üst karartma: HUD+56 px yumuşak gradyan (`GameplayHud.scrim`).

### 13.4 Güç slotu anatomisi (`UiKit.power_slot`)

80×84 `Button` **madalyon** (erik `PanelTray` içinde ikişer): gövde `btn_circle` (3B basılabilir daire),
variation `PowerSlot` (krem) / `PowerSlotArmed` (cyan) / `PowerSlotEmpty`
(pasif lavanta-gri); arkada 3 px taşan çerçeve halkası (`btn_circle_flat`
lacivert / silahlı cyan-derin / boş pasif-koyu); alt yarıda erik gölge dairesi
(α .16), üst yarıda `item_circle_inner` gloss (α .42); rozet 34×26 sağ üstte; **owner güç
sanatı** 60 px (picto yok); sağ üstte `Badge` altın "×N"; silahlıyken arkada
yumuşak krem `btn_circle_flat` hale (+9 px, α .55 — neon değil); stok 0'da
sanat rengini korur (gri-mavi örtü, α .72), rozet **nane "+"** (dokununca
refill penceresi — davranış aynı);
`set_enabled(false)` → `disabled` + %55. Basış `UiMotion.attach_press`.
Konum: sol ikili hedefli güçler (Bomba, Büyütücü), sağ ikili anında güçler
(Sarsıntı, Temizleyici) — üst oyun alanının iki yanında, hedef plakasının
çevresinde (seçenek B; dört slotluk alt satır (A) kap tabanı + şerit + banner
ile aynı bölgede yarışıyor ve 16:9'da board'u küçültüyordu).

### 13.5 Kap kabuğu (board)

Yalnız çizim, collider yok: dış yumuşak gölge (5 kademe) → çivit iç dolgu α .24 +
tabana koyulaşan gradyan + iç kenar/taban bantları (derinlik) → taşma şeridi
(duvarların **altında**) → bambu duvar 30 px (fizik 20'nin dışına, alana
girmez) + açık kapak şeridi → bambu taban rayı + üst dudak ışığı → **temas
gölgeleri** (tabana oturan her parçanın altında rayın üstüne çizilen yumuşak
elips, `_draw_contact_shadows`, her kare) → tehlike. Candy-night zemin kabın
içinden görünmeye devam eder.

**"Havada duruyor" düzeltmesi (polish):** `board_floor_bamboo.png` 1024×269'un
üst %40'ı ve alt %13'ü saydamdır; doku `FLOOR_Y`'den gerildiğinde görünür ray
~22 px aşağıda başlıyor, parçalar fizik tabanında dururken altlarında koyu
boşluk kalıyordu. Artık yalnız görünür bölge (`FLOOR_TEXTURE_REGION` y 108–235)
`draw_texture_rect_region` ile çizilir ve rayın üst kenarı `FLOOR_Y − 3`
(`FLOOR_OVERLAP`) hizasına oturur: parça silueti rayın dudağına gömülü okunur,
fizik tabanı ve collider değişmez.

### 13.6 Evrim şeridi (`EvolutionStrip`)

`PanelStrip` (erik bevel raf + üst ışık) + 8 hücre, tier sanatı 34→50 px
büyüyerek; ulaşılmamış α .72 (görünür kalır), ulaşılan tam; bu round'un en
yüksek tier'ı yumuşak krem `btn_circle_flat` hale + %15 büyütme (pop ile),
level hedefi altın `alert_dot_ring`. Neon seçim çerçevesi yok, metin yok,
envanter değil. `GameBoard._note_tier` her spawn'da besler.

### 13.7 Tehlike sınırı

Mekanik aynı. Sakin: şerit yarı yükseklikte (`DANGER_STRIPE_HEIGHT_SCALE .5`),
α .20 + eşikte 2 px açık pembe hat — platform değil eşik. Tehlike: nabızla
α 1.0, hat beyaza, duvarların üst yarısı ve çizgi çevresi pembe rim glow
(`_draw_danger`, `WALL_VISUAL` genişliğinde). "Taştı!" / "Hedef tamam!" durum
metni pembe `title_oval` candy plakasında pop'lanır (`GameplayHud.set_status`).
Ek alarm UI yok.

### 13.9 Mola / çıkış akışı

`scenes/ui/pause_menu.tscn` (`PauseMenu`, `UiKit.modal_frame("Mola")`):
**DEVAM ET** (`ButtonCTA`) · **Yeniden Başlat** (`ButtonSecondary`) · **Ana
Menüye Dön** (`ButtonDanger`). Açılış yolları: HUD Geri, HUD Çıkış, Android
geri tuşu (oyun sırasında uygulama ASLA doğrudan kapanmaz; mola açıkken geri
tuşu = Devam Et). Açıkken board `set_menu_paused(true)`. Devam/refill
penceresi açıkken mola açılmaz. "Ana Menüye Dön" round'u terk eder: sonuç
ekranı, ödül ve kayıt akışı çalışmaz, harita sekmesine dönülür.

**Android geri tuşu — motor tuzakları (A36 cihaz kapısı, 2026-09-16):**
`SceneTree.quit_on_go_back` varsayılanı true'dur ve GO_BACK bildirimi
dağıtıldıktan sonra oyunu KAPATIR — bu yüzden `Main._ready` onu kapatır ve
çıkış yalnızca ana sekmede, kapatılacak pencere yokken `get_tree().quit()`
ile yapılır. Ayrıca Godot 4.6 Android tek geri basışında bildirimi iki kez
iletebilir (`android_input_handler.cpp` AKEYCODE_BACK + OnBackPressedDispatcher
→ `GodotLib.back`); `Main._notification` 250 ms debounce ile kopyayı yok
sayar. Sonuç ekranı açıkken geri tuşu yok sayılır (karar bekler).

### 13.8 Gelecek banner seam'i

`GameplayHud.banner_seam` (görünmez Control) = `layout["banner"]`; yüksekliği
`GameplayLayout.banner_height()`. v1: 0. AdMob bağlandığında sağlayıcı
`GameplayLayout.set_banner_height(px)` çağırır ve board `_apply_layout`
yeniden koşar; kontroller seam'e giremez (test kilitli).

---

## 14. Production Home hub (M8.6-03B)

**Karar (owner, 2026-09-16):** M8.6-03 Home (kart yığını + sekme çubuğu)
görsel olarak reddedildi — "cilalı uygulama/dashboard" okunuyordu. Yeni
yön: **casual mobil oyun lobisi** — rakip referansın (`_visual_source/
references/competitor_quality_target/`) bilgi mimarisi ve hub hissi; sanat,
harita, karakter ve marka KOPYALANMAZ. **Home'da harita YOK.**

**Kod:** `scripts/ui/home_screen.gd` (ekran; sahne yalnız zemin + Root),
`scripts/ui/home_feature_button.gd` (`HomeFeatureButton`, tek madalyon
bileşeni), `scripts/ui/bonus_chest_info.gd` (+ `scenes/ui/bonus_chest_info.tscn`),
`UiKit` `safe_top` / `safe_bottom` / `flat_plate` / `home_icon_button` /
`home_pill` / `hero_cta`, `DailyReward.is_claimable()` (yalnız okur),
`DailyRewardPopup.show_status` / `close_popup`, `tab_bar.active_tab()`.
**Tema:** `ButtonFeature`, `ButtonFeatureLocked`, `PanelFeaturePlaque`,
`ButtonHomeIcon`, `PanelHomePill`, `ButtonHomePill`, `ButtonHomeAdd` (GENERATED).
**Sanat:** `assets/visual/ui/hero_mascot.png` (800×778, `tools/make_home_art.py`
— `tutorial_pose.png` 350 px'ti, hero'da bulanıyordu; ipucu dosyası aynı).
**Test:** `tools/home_ui_test.tscn` (207 kontrol; 6 pencere boyutu + A36). **Çekim:**
`tools/home_shots.tscn -- <dir> [GxY] [safe=61]` (10 durum × 4 boyut + A36
payı simülasyonu, kayıt byte'ı geri konur).

### 14.1 Kompozisyon (bölgeler; 720 tuval, yükseklik serbest)

| Bölge | İçerik |
|---|---|
| **ÜST** (`safe_top` + 14) | tek 56 px satır, ortak optik merkez (test ±3 px): sol `home_icon_button` ayarlar (56, §14.5) + `home_pill` seri (owner alev + "N günlük seri"; **yeni oyuncuda "Seri başlasın"**, asla çıplak "0") · sağ `home_pill` Hamur + nane yuvarlak "+" (48, → Mağaza). Pill'ler HUD v5 dili (koyu lavanta `label_round` + açık halka + erik gölge + gloss) — **koyu düz cip değil**. Sol iç pay = sağ iç pay (24). Gelecek premium para birimi için mimari yer var, **şimdi icat edilmedi**. |
| **LOGO** | `logo_lockup` 560 px, üst satırın altında ortada |
| **YAN** | sol sütun: **Günlük** (pembe candy kubbe + gift picto; alınabilirse pembe bildirim noktası, nabız) · **Koleksiyon** (takılı skin önizlemesi, altın `6/20` rozeti, nane ilerleme halkası) — sağ sütun: **Mağaza** (cyan candy kubbe + shop picto) · **Sandık** (owner sandığı, altın `49/75` rozeti, altın halka; ±3 px süzülme). Sütunlar logonun altından başlar, 28 px kenar payı, adım 146 (uzun ekranda büyür — hero'nun yanına yayılır). Etiket plakası `badge_round` (30 px'te tam yuvarlak uç). |
| **HERO** | `hero_mascot` (≤ 600 px, uzun ekranda ≤ 632; tuval genişliğine sığar; üst %22'si sütunların arasına sokulur — dar tepe, alfa duyarlı testle) + lavanta hale + krem sahne ışığı + erik yer gölgesi + tier 3 / tier 6 dumpling (ayak hizasında) + 6 pırıltı + alt bantta 4 pırıltı (bant ≥ 120 px ise). Zemin: `ShellBackdrop` Home'da daha az karartılır (`_tune_backdrop`) — gece kasabası görünür. |
| **OYNA grubu** (alt, 28 + `safe_bottom`; 03B.2) | dikey hiyerarşi, ikisi de **tuval ortasında**: üstte **level pill'i** `ButtonHomePill` 236..284×60 (genişlik içeriğe göre; koyu lavanta pill + açık halka + erik gölge + gloss; sol uçtan 10 px taşan 56 px **altın taç madalyonu**; iki satır: "SIRADAKİ" / "Level 4 ★ 8/30"; sonsuzda yalnız büyük taç, "SONSUZ MOD" / "Rekor 12 480 ★ 30/30") → Harita · 12 px altında `hero_cta` **OYNA 480×96** (tek `ButtonCTA`, Baloo EB 40; halka btn_cta'nın 4 gölge satırına oturur) → Harita. Testle: OYNA merkezi 360 ± 2, pill merkezi ± 3, aralık 8–16, pill OYNA'dan ≥ 100 px dar. |
| **Sekme çubuğu** | YOK — M8.6-06 ile `tab_bar.tscn` tamamen kalktı; Harita / Mağaza / Koleksiyon kendi `ScreenTopBar`'ıyla (geri → Ana Sayfa) döner (bkz. 14.4) |

Uzun ekran (tuval > 1280, `extra`; 03B.1 dağılımı): gök payı +%22, sütun
adımı +%36 (ikinci sıra hero'nun yanına iner, maskot onunla birlikte iner),
OYNA satırı +%18 yukarı, yan dumpling'ler +%26 aşağı (ayak hizasında kalır),
maskot +%12 büyür (≤ 632), alt bantta pırıltılar. Kısa ekran (1280 /
540×960): maskot 600, alt bant ~200 px dünya. Test: 4 tuval + A36 payı (61
px) — butonlar ekranda, ≥ 48×48, çakışma yok (madalyon plakaları dahil),
madalyonlar güvenli alanda, maskotun **opak pikselleriyle** kesişmiyor, OYNA
satırına girmiyor, maskot ≥ 480 px, maskot–OYNA bandı ≤ 420 px, üst satır
üç öğesi ortak merkez ±3 px, sol/sağ pay simetrik.

### 14.2 `HomeFeatureButton` anatomisi

96×100 `Button` (`ButtonFeature`, `btn_circle` krem 3B daire): erik
`hud_shadow` (6 px, α .28) → açık lavanta dış halka (8 px, `btn_circle_flat`)
→ koyu lavanta halka (4 px) → gövde → cam-mavi iç yuva (`item_circle_inner`
`GLASS_BLUE`) + alt derinlik + üst gloss → **owner sanatı** 58 px
(`set_art`) YA DA renkli candy kuyu + beyaz picto (`set_icon(role, tint)`;
owner sanatı olmayan sistemler: Günlük pembe, Mağaza cyan) → sağ üst altın
`Badge` (`set_badge`) → pembe bildirim noktası (`set_notification`; rozet
varsa sol üste kayar) → dış halka üstünde ilerleme yayı (`set_progress(ratio,
tint)`, 6 px, ray `LAVENDER_DEEP` α .55) → altta etiket plakası
(`PanelFeaturePlaque` `title_oval` koyu lavanta + açık kenar, Baloo 14 beyaz,
gövdeden 10 px içeri biner; plaka dokunma almaz). `set_locked(true)`:
`ButtonFeatureLocked`, cam soluk, sanat soluk, kilit rozeti, `disabled`.
Basış `UiMotion.attach_press` (0.94 + yay). Etiket metni büyük harf
ÇAĞIRANDAN gelir (Godot `to_upper` Türkçe İ'yi bilmez: "KOLEKSİYON").

### 14.3 Rotalar ve pencereler

| Kontrol | Rota |
|---|---|
| Ayarlar | `open_settings` (aynı pencere) |
| Günlük | alınabilirse `main._check_daily_reward()` (AYNI claim yolu, `DailyReward`) → ödül penceresi; alınmışsa `show_status(seri)` ("Bugünkü ödülünü aldın", TAMAM). Ekonomi değişmedi. |
| Koleksiyon / Mağaza / Hamur "+" | sekme 2 / 3 / 3 |
| Sandık | `BonusChestInfo` (kural §5.2 75 merge + altın ilerleme + kalan; OYNA → Harita). Sandık VERMEZ, kayda yazmaz. |
| OYNA / level plakası | Harita (mevcut level akışı; doğrudan level başlatma owner kararına açık) |
| Android geri | ayarlar → sandık bilgisi → günlük penceresi kapanır → diğer sekmede Ana Sayfa → Ana Sayfa'da pencere yokken çıkış (M8.6 politikası aynen) |

Home kaydı yalnız OKUR (`home_ui_test`: çizim/yenileme kayıt byte'ını
değiştirmez; `home_screen` / `bonus_chest_info` `save_game`/`add_dough`/
`grant_*` çağırmaz). Sahte buton yok: para/reklam ürünleri (Başlangıç Paketi,
Reklamsız) **yerleştirilmedi** — Play Billing/AdMob yok (GAME_DESIGN §5.7).

### 14.5 "Oturmuş" ikon butonu — HUD v5 köşe butonunun kayıt hatası (03B.1)

Owner: "ayarlar butonu tam oturmuyor". Kök neden (4× kırpma ile ölçüldü):
`hud_icon_button` gövdesi `btn_bevel_soft` 62×77 — son 7 satırı pişmiş
yarı saydam gölge (boyalı gövde 70/77 = %91) ve 9-slice kenarları
(30/37/31/39) 56 px butondan büyük → sprite dikeyde ezilir; düz
`frame_round20` halka dört yanda eşit taştığı için altta ~9 px, üstte 4 px
görünür (buton halkanın içinde "yüzer"); `border_round_thin` iç ışığının ~30
px köşe yarıçapı gövdenin ~14 px köşesiyle uyuşmaz (sağ üstte sapkın yay).
Aynı reçete gameplay HUD v5 köşe butonlarında da var — **cihazda onaylı,
DOKUNULMADI**; ileride owner onayıyla aynı düzeltme oraya taşınabilir.

Home varyantı `UiKit.home_icon_button(role, size)` (`ButtonHomeIcon`):
boyalı sınırı dikdörtgene birebir oturan düz plakalar — erik gölge → açık
lavanta halka (+4) → koyu taban plakası (butonun stylebox'ı; alt 6 px dudak)
→ yüz plakası `LAVENDER_DEEP` → `btn_bevel_light` gloss → beyaz picto (yüz
merkezinde). Basınca yüz + ikon dudağa oturur (4 px) ve UiMotion squash.
`UiKit.flat_plate(sprite, tint)`: NinePatchRect yerine StyleBoxTexture'lı
boş PanelContainer (NinePatchRect patch kenarlarının altına küçülemez).

### 14.4 Sekme çubuğu göçü (KAPANDI — M8.6-06)

Home hub; Harita (M8.6-04), Mağaza (M8.6-05) ve Koleksiyon (M8.6-06, §17)
kendi `ScreenTopBar`'ıyla döner (geri → Home). M8.5-10 alt sekme çubuğu
(`scenes/ui/tab_bar.tscn` + `scripts/ui/tab_bar.gd`) ve `main.gd`'deki
`_tabs` tamamen SİLİNDİ: hiçbir ekranda gizli çubuk yok, dokunma almaz
(`collection_ui_test` main'de `TabBar` düğümü olmadığını ve kaynakta `_tabs`
kalmadığını doğrular). `main._show_tab` adı tarihsel (ekran indeksi).

---

## 15. Production journey map — Harita (M8.6-04)

**Karar:** Home'daki büyük OYNA'nın ilk durağı; owner'ın candy dünyası
(`map_background.png`) KAHRAMAN, üstünde aşağıdan yukarı on level düğümü +
kaledeki Sonsuz Mod madalyonu, aralarında candy patika. Dashboard/kart/grid
DEĞİL. Eski (M8.5-12) düz cipli üst şerit, StyleBoxFlat kare düğümler, gri
kilitli bloblar, tam ekran α .40 karartma ve alt sekme çubuğu KALKTI.

**Kod:** `scripts/ui/level_select.gd` (ekran), `scripts/ui/map_level_node.gd`
(`MapLevelNode`, tek düğüm bileşeni, 5 durum), `scripts/ui/screen_top_bar.gd`
(`ScreenTopBar`, ikincil ekran üst satırı — Mağaza/Koleksiyon de alacak),
`scripts/ui/map_trail.gd` (`MapTrail`, görünüm pası). **Tema:** `ButtonMapNode`,
`ButtonMapNodeLocked`, `ButtonMapEndless`, `PanelMapPlaque` (GENERATED).
**Test:** `tools/map_ui_test.tscn` (127 kontrol; 4 pencere + A36 payı).
**Çekim:** `tools/map_shots.tscn -- <dir> [GxY] [safe=61]` (10 durum × 4 boyut
+ A36 simülasyonu, kayıt byte'ı geri konur). Sanat üretilmedi; yeni asset yok.

### 15.1 Kompozisyon (720 tuval, yükseklik serbest)

| Bölge | İçerik |
|---|---|
| **ÜST** (`ScreenTopBar`: `safe_top` + 14, 56 px satır, 24 px kenar) | sol `home_icon_button("back")` → Ana Sayfa · ortada pembe `HeaderRibbon` "HARİTA" (62 px, Baloo EB 26, erik gölge — pencere kurdelesiyle aynı kimlik) · sağ `home_pill` Hamur + nane "+" (48) → Mağaza. Kurdele ekranda ortalanır; pill büyürse sola kayar (test: kesişme yok). Seri pill'i BİLEREK yok (Home'da var, haritada karar değeri yok). |
| **DÜNYA** | zemin `Rect2(0, safe_top, vw, vh − safe_top)` alanını KEEP_ASPECT_COVERED kaplar (ölçek = max(w/720, h/1280), merkez). Punch-hole yokken eski tam ekran dönüşümle birebir; A36'da dünya 61 px aşağıdan başlar, üstteki bant zeminin en üst 6 satırının dikey gerilmesi (`AtlasTexture`, görünen yatay aralığa hizalı, `flip_v` — bandın alt kenarı doku satırı 0; A36 kapısında aynasız şeritte ince dikiş görüldü ve kapatıldı) + haze. Kenarlarda radyal erik vignette (α .30, merkez temiz), üstte 150 px krem-lavanta haze (α .72 → 0). Karartma YOK. 6 atmosfer pırıltısı (owner yıldızı, sinüs sönüm). |
| **DÜĞÜMLER** | doku uzayı konumları (aşağıda), aynı cover dönüşümü. Perspektif: çap altta 84 → kalede 72 (`DEPTH_MIN` .86); uzun ekranda dünya ölçeğinin yarısı kadar büyür (1560'ta ×1.11). Sıradaki ×1.14. |
| **SONSUZ** | kalede (445,150) 116 px madalyon; altındaki plaka "Rekor N" / "Rekor bekliyor" / "Level 10'u bitir" (kanonik şart metni). |
| **ALT** | sekme çubuğu YOK; dünya (iki maskot, çiçek yatağı) tabana kadar görünür. |

Doku uzayı konumları (M8.5-12'den düzeltildi — 2/4/5 kaldırımdan yolun
üstüne, 8/9/10 aralığı ≥ 104 px): 1 (420,1120) · 2 (322,1030) · 3 (440,940) ·
4 (332,850) · 5 (322,742) · 6 (398,648) · 7 (468,556) · 8 (408,470) ·
9 (480,388) · 10 (440,292) · Sonsuz (445,150). Kaydırma yok: dünya her
oranda sığar, sıradaki düğüm her zaman ekranda.

### 15.2 `MapLevelNode` anatomisi

`Button` (çap d × (d + 4 dudak); `btn_circle` gövde). Arkadan öne: yassı erik
temas gölgesi (`popup_glow` 1.9d × 0.8d, gövdenin %86'sında — düğüm dünyaya
OTURUR) → hale (yalnız odak; krem-cyan / Sonsuz'da altın, nefes) → 2 px erik
kontur (`LAVENDER_DEEP` α .55 — krem halka açık zeminde kaybolmasın) → 6 px
krem halka → 3 px durum halkası (sıradaki/Sonsuz 4 px) → gövde → cam yuva
(`item_circle_inner` %74 çap) → alt gölge + üst gloss → içerik → yıldız sırası
→ owner kilit → plaka (`PanelMapPlaque` krem `badge_round` + `LAVENDER_DEEP`
kenar, gövdeye 8 px biner, dokunma almaz).

| Durum | Gövde | Halka | İçerik | Plaka |
|---|---|---|---|---|
| COMPLETED | cyan | `CYAN_DEEP` | Baloo numara (0.31d, lacivert) + 3 owner yıldızı (0.22d; boş α .55) | — |
| CURRENT | cyan, ×1.14 | **altın** (Home level rozetiyle aynı altın) | numara | "OYNA" |
| LOCKED | `LAVENDER_SURFACE` | `DISABLED` | numara erik α .72, cam `#ebe6f4`, owner pembe kilit sağ üst | — |
| ENDLESS_OPEN | altın (116) | `GOLD_DEEP`, krem cam | owner taç 0.38d + "SONSUZ" (0.13d) + 3 pırıltı | "Rekor 12 480" / "Rekor bekliyor" |
| ENDLESS_LOCKED | lavanta (116) | `DISABLED` | soluk taç + kilit | kilit + "Level 10'u bitir" |

Odak (`set_focused`): sıradaki level; her şey bitmişse açık Sonsuz. Hale
α .58–.88 + %7 ölçek nefes (1.9 s), gövde ≤ %1.5 — yalnız basış/açılış
tween'i çalışmıyorken (`hold_breath`, UiMotion meta tween'i kontrol edilir).
Kilitli dokunuş: `reject()` — kilit 220 ms sallanır + `ui_invalid`; buton
`disabled` DEĞİL ama `level_chosen` yaymaz (testle). Basış `UiMotion.attach_press`
(ses açık düğümde `ui_tap`). Tüm dokunma hedefleri ≥ 72 px.

### 15.3 Patika (`MapTrail`)

Catmull-Rom aynen; 10 px çizgi + 16 px erik gölge (α .40), 24 px aralıklı
5.4 px candy noktalar + beyaz tepe ışığı; tamamlanmış segment şeftali-altın
`(1, .87, .54)` + altın nokta, gelecek beyaz α .86 + lavanta-beyaz nokta.
Düğüm altında kalan uçlar düğüm yarıçapı + 10 px atlanır. Açılış: `lit` 0→1
(0.4 s) → düğüm 0.4→1.15→1.0 pop (0.32 s) → 12 parıltı + `level_unlock`
(~0.7 s, M8.5-12 ile aynı). Tazeleme canlı tween'leri öldürür (serbest
düğüme bağlı callback kalmaz). Ekran girişi: düğüm katmanı 0.18 s solma +
odak düğümü 1.06 pop (`_play_entry`, `call_deferred` — main refresh'ten sonra).

### 15.4 Rotalar

| Kontrol | Rota |
|---|---|
| Geri | `home_requested` → `main._on_home_requested` → Ana Sayfa |
| Android geri | `main._notification`: Harita → Ana Sayfa (açık pencere önce kapanır; gameplay politikası aynen) |
| Hamur "+" | `shop_requested` → Mağaza |
| Sıradaki / tamamlanmış düğüm | `level_chosen(level)` → `main._start_level` (kanonik; tekrar oynama korunur) |
| Kilitli düğüm / kilitli Sonsuz | yalnız geri bildirim, başlamaz |
| Açık Sonsuz | `LevelLibrary.load_endless()` → `level_chosen` (kanonik) |

Harita kaydı yalnız OKUR (`highest_level_unlocked`, `stars_for_level`,
`is_endless_unlocked`, `endless_high_score`, `dough`); `save_game` /
`complete_level` / `record_stars` çağrısı yok (testle). Ekonomi, level
verisi, unlock/yıldız kuralı, fizik, skin, reklam politikası DEĞİŞMEDİ.


---

## 16. Production Mağaza (M8.6-05 / 05.1 cila) — A36 CİHAZ KAPISI GEÇTİ (6baafbd)

**Karar:** eski M8.5-10 mağazası (tam genişlik koyu satırlar, 72 px ikon,
sağda neon pill, alt sekme çubuğu) "ayar listesi / dashboard" okunuyordu.
Yeni yön: **dikey casual-game dükkânı** — ürün sanatı odak, krem candy
kartlar, 2 sütun grid, candy SATIN AL, pembe MAĞAZA kurdelesi. Sahte
monetizasyon YOK (gerçek para, gem, reklamsız, indirim, paket — billing/AdMob
kurulmadı, GAME_DESIGN §5.7.4); yalnız 4 güç + 20 skin, tek para Hamur.

**Kod:** `scripts/ui/shop_screen.gd` (ekran), `scripts/ui/shop_power_card.gd`
(`ShopPowerCard`), `scripts/ui/shop_skin_card.gd` (`ShopSkinCard`),
`ScreenTopBar` (`with_add = false`), `UiKit.candy_button` /
`set_candy_button_variation` / `candy_well` / `section_header` / `inset` /
**`card_face`** / **`seat_modal_close`** (05.1).
**Tema:** `PanelShopCard`, `PanelShopCardPower`, `PanelShopCardOwned`,
`PanelShopSection`, `PanelShopToast`, `OwnedBadge`, `ButtonBuyLocked`
(GENERATED); token `CYAN_MUTED`. **Test:** `tools/shop_ui_test.tscn` (212
kontrol; 4 pencere + A36 payı, SATIN AL üstünden gerçek sürükleme/fling/
dokunuş dizileri, kayıt byte'ı geri konur; bekçi + `_exit_tree` kayıt
güvenlik ağı). **SATIN AL kaydırma geçişi (06.3, dbf9127):** iki kartın SATIN AL
butonu `UiKit.make_candy_button_scrollable` ile `MOUSE_FILTER_PASS` —
Button'ın varsayılan STOP'u basışı butonda durduruyordu, ScrollContainer
basışı hiç görmüyor ve parmak butonun üstündeyken kaydırma başlamıyordu
(A36'da ölçüldü: 0 px). PASS ile olay ScrollContainer'a da ulaşır (Koleksiyon
kartıyla aynı desen); kaydırma başlayınca BaseButton basışı iptal eder
(`pressed` yayılmaz — sürükleme onay açamaz), kart `NOTIFICATION_SCROLL_
BEGIN`'de `UiKit.release_candy_button` ile yazı dudağı + 0.94 ölçeği bırakır.
Temiz dokunuş yine tam bir `pressed` → onay. Cihazda yeniden doğrulandı
(güç/skin SATIN AL: yavaş sürükleme ≈640 / ≈748 px, fling içeriğin sonuna kadar, dokunuş tek
onay). **Çekim:** `tools/shop_shots.tscn -- <dir> [GxY] [safe=61]`
(17 durum × 4 boyut + A36 simülasyonu; 05 için gerçek satın alma yolu
koşar, kayıt sonda AYNEN geri yazılır). Sanat üretilmedi; yeni asset yok.

**05.1 görsel cila (2026-09-17, tek odaklı pas — yeniden tasarım DEĞİL):**
kompozisyon (2 sütun grid, ScreenTopBar, bölüm plakaları, onay akışı) ve
tüm durum/ekonomi kuralları aynen; yalnız malzeme zenginliği ve ürün odağı.
Kart 328×**384** (372'den: içerik büyüdü, ölçüm §16.2). Skin önizlemesi
**164** (140'tan +%17), güç sanatı **96** (88'den +%9), SATIN AL **60**
(64'ten — hâlâ ≥ 48; buton kartı daha az domine eder). Kart yüzü
`UiKit.card_face`: gövdenin ilk çocuğu (içeriğin ALTINDA), `clip_contents`
ile gövde dikdörtgeninde tutulan beyaz düşük-alfa radyal ışık (üst-orta,
ürün sanatının arkası hafif aydınlık; sert kenar yok) + `popup_light`
kavisli üst gloss bandı — krem büyük yüzey düz okunmaz, gövde tonu korunur.
Skin kartında karakterin arkasında rarity renginde düşük-alfa radyal hale
(Common lavanta .14 / Rare .17 / Epic .18 / Legendary altın .24); Rare halka
beyaza %25 (eski %42 soluk kalıyordu), Epic %22; Common/Legendary aynen.
Güç kartı stok rozeti kartın köşesinden **kuyunun sağ üst omzuna** taşındı
(gameplay madalyonunun ×N rozetiyle aynı yer; krem halka 3 px + erik temas
gölgesi). Amaç metni satır aralığı 3. Bölüm plakası 4 px koyu lavanta dudak
(`SECTION_LIP`) + halka dudağı sarar + gloss .38 + küçük parlama noktası;
satır 48. Onay: sunum 190 (172'den), güç kuyusu 164/118, skin önizleme 184
+ rarity halesi; kurdele 60 px içeri çekildi ve kapat X'i krem halka + erik
gölgeyle köşeye oturdu (`seat_modal_close`, yalnız Mağaza — paylaşılan
`modal_frame` Mola/Bonus Sandık'ta değişmedi). QA: `build/qa_m8.6-05.1/`.

**A36 cihaz kapısı (2026-09-17, 6baafbd ağacı, Samsung SM-A366B 1080×2340):**
native'de üst satır punch-hole altında ve kaydırmada piksel-sabit, bölüm
plakaları/kartlar/rarity halkaları/TAKILI–SAHİPSİN ayrımı okunur, +%17
önizleme cihazda net kazanç (taç/fiyonk kırpılmadı), haze bandı α .94
altında kart hayaleti ~%6 (kolda görünmez, değiştirilmedi); yavaş kaydırma +
hızlı fling sonrası üst kare 0 px farklı, SATIN AL üstünden başlayan swipe
onay açmadı, son sıra jest alanının 130 px üstünde; Legendary'de 10 s boşta
yalnız pırıltı pikselleri değişti (PSS sabit). Geçici kayıtlarla: basılı
durum, onay (X kurdeleye binmiyor), Android geri önce onayı kapatır, güç
satın alma 335→215→35 (stok +1, tek transaction), stok 0 alınabilir
(1350→1250), Hamur yetmiyor (35): onay yok + pembe plaka + kayıt md5 aynı,
skin 1500→1350 + auto-equip yok + SAHİPSİN'e döner, SAHİPSİN/TAKILI
dokunuşu hiçbir şey yapmaz, Legendary onayı; rotalar (Home madalyon / Home
"+" / Harita "+" / Koleksiyon "Mağazaya Git" / eski sekme çubuğu) tek örnek.
logcat: 0 SCRIPT ERROR / 0 E godot / 0 res:// / 0 shader / 0 FATAL / 0 ANR.
Owner kaydı byte-identical geri kondu (md5 597d50ac…); doğrulama açılışı
yalnız günlük ödülü yazdı (80→95, seri 4 — normal davranış). Cihaza özel
kusur yok, kod değişmedi. Ayrıntı: `build/qa_m8.6-05.1/device/DEVICE_GATE_NOTES.md`.

### 16.1 Kompozisyon (720 tuval, yükseklik serbest)

| Bölge | İçerik |
|---|---|
| **ÜST** (`ScreenTopBar`, sabit: `safe_top` + 14, 56 px satır, 24 px kenar) | sol `home_icon_button("back")` → Ana Sayfa · ortada pembe `HeaderRibbon` "MAĞAZA" · sağ Hamur `home_pill` **"+" YOK** (`with_add = false`: Mağaza zaten Home/Harita "+"ının hedefi; kendine giden ölü rota olmasın). Altında koyu çivit haze: satır boyunca **düz bant** (`WORLD_INDIGO` α .94 — kayan kart satırın altında OKUNMAZ) + 36 px solma (`HAZE_FADE`; offset `_layout`'ta satır yüksekliğine göre). İlk plaka solmanın dışında başlar (`CONTENT_TOP_GAP = HAZE_FADE`). |
| **İÇERİK** (`ScrollContainer`, tam ekran, çubuk gizli, yatay kapalı; `MarginContainer` 24 / üst `bar.height() + 36` / alt `64 + safe_bottom`) | `UiKit.section_header("GÜÇLER")` (44 px plaka + 4 px dudak = 48 satır: iki yanda 4 px açık lavanta çizgi, ortada `PanelShopSection` koyu lavanta `title_oval` + altında koyu lavanta dudak (`SECTION_LIP`, candy puff) + açık halka (dudağı da sarar) + erik gölge + gloss .38 + sol üstte küçük beyaz parlama noktası, Baloo 22 beyaz; MAĞAZA kurdelesinin altında ikincil, dar ve kompakt) → `GridContainer` 2 sütun (h 16 / v 20): 4 × `ShopPowerCard` → 22 px → `section_header("SKİNLER")` → 2 sütun: 20 × `ShopSkinCard` (katalog sırası: rarity + id). Kart 328×384 (05.1); 24 + 328 + 16 + 328 + 24 = 720. Sekmeye her girişte kaydırma en üste. |
| **ZEMİN** | `ShellBackdrop` Home ayarında (gece modulate `(0.80, 0.78, 0.94)`, karartma α .30, alt solma .70) + Harita'nın radyal erik vignette'i (α .30). Kartlar dünyanın üstünde oturan krem candy nesneler. |
| **ALT** | sekme çubuğu YOK. |

Dikey ritim 720×1280 (VBox ayrımı 12 her öğe arasında; 05.1 ölçüleri): bar 70 →
GÜÇLER 106–154 (44 plaka + 4 dudak) → güçler 166–550 / 570–954 → 22 px boşluk →
SKİNLER 1000–1048 → ilk skin sırası 1060'ta başlar (ilk ekranda ~220 px'i
görünür, kaydırmaya davet). 720×1560 (ve 1080×2340) aynı kompozisyon, bir skin sırası fazla; 540×960
0.75 ölçek. A36: satır 61 px payın altına iner, haze bandı payı kapatır.

### 16.2 `ShopPowerCard` anatomisi (328×384)

Arkadan öne: erik `popup_glow` gölge (16/6/16/26 taşma, α .34) → açık lavanta
`frame_round20` halka (+5) → 2 px erik kontur (`LAVENDER_DEEP` α .5 — krem
gövde açık halkanın içinde yüzmesin) → lavanta-krem `card_bevel_soft` gövde
(`PanelShopCardPower` `TRAY_CREAM`: gameplay güç tepsisinin tonu, kozmetik
kartlardan ayrık; 16/14/16/20 iç pay) → **kart yüzü** (`UiKit.card_face`,
05.1: gövdenin ilk çocuğu, içeriğin altında; `Clip` gövde dikdörtgeni —
beyaz radyal ışık `popup_glow` α .34, merkez gövde yüksekliğinin %24'ünde,
genişlik gövde + 2×24, yükseklik %80 → `popup_light` üst gloss bandı α .58,
7/5 iç pay, 28 px) → sütun: **candy kuyu** (`UiKit.
candy_well`, 130 px: gücün vurgu renginde geniş düşük-alfa hale (α .30) →
erik temas gölgesi → vurgu renginin koyusu 6 px alt oturak → açık lavanta
halka 6 px → renkli yüzey (`PowerUp.ACCENTS`: pembe/altın/gök/yeşil) → alt
gölge + üst gloss → **owner güç sanatı 96 px**, picto YOK; kuyunun sağ üst
omzunda **altın `Badge` "Stok ×N"** (72×30, Baloo 16; erik temas gölgesi +
3 px krem halka + rozet düz bir sarmalayıcı Control içinde kardeş — kuyunun
çocuğu, kuyu dikdörtgeninden 14 px sağa / 2 px yukarı taşar; gameplay
madalyonunun ×N rozetiyle aynı yer ve dil, kart köşesinde yüzen etiket
değil) → Baloo 24 ad (`LabelSection`) → 2 satır Nunito 17 amaç, satır aralığı
3, min 54 (gerçek mekanik: "Seçtiğin dumpling'i yok eder" / "bir üst
seviyeye çıkarır" / "Tahtayı sarsar, parçalar karışır" / "Küçük
dumpling'leri (1–2. boy) temizler") → fiyat satırı (Hamur 26 + `LabelPrice`
"120 Hamur") → 6 px → **SATIN AL** `UiKit.candy_button` (296×60:
`ButtonPrimary` cyan `btn_normal` (orta satır gerilir) + erik gölge +
`title_oval` açık halka + üst gloss; yazı çocuk Label — Button kendi yazısını çocuklardan önce çizer, gloss
soldururdu; basınca yazı 3 px iner + UiMotion 0.94). Ölçülen içerik minimumu
381 ≤ 384 (testle). Stok 0 bir mağaza durumu DEĞİL: ürün Hamur yettiği
sürece satılık. Fiyat `PowerUpEconomy.price`, stok `SaveManager.powerup_count`.

### 16.3 `ShopSkinCard` anatomisi (328×384)

Aynı gövde reçetesi (krem `PanelShopCard` + `card_face`); farklar: **rarity
halkası** (Common `LAVENDER_LIGHT`, Rare `RARITY_RARE`→beyaz %25, Epic
`RARITY_EPIC`→beyaz %22 + lavanta hale α .34, Legendary `GOLD` + geniş
`GOLD_BRIGHT` hale α .65 + satılıkken hafif altın-krem gövde (`CREAM`→
`GOLD_BRIGHT` %12) + 4 köşe-simetrik sinüs pırıltısı yalnız önizleme
alanında — RNG yok, ekran `_process`'i `tick_sparkles` ile besler); sol üstte `rarity_tag`
(trapez); **sahne 184 px**: karakterin arkasında rarity renginde radyal
candy hale (`popup_glow` 236, Common `LAVENDER` α .14 / Rare .17 / Epic .18 /
Legendary `GOLD` .24 — kartın içinde kalır) → `TRAY_CREAM` `item_circle_inner`
kuyu 152 → **`SkinSwatch` 164 px** (05.1, +%17; kartın üst yarısına hâkim,
%6 iç payla saç/fiyonk/taç kırpılmaz; 8 px aşağı: rarity etiketi sanat
kutusuna değmez — testle) (`setup(entry, true)`: kilitli skin de FINAL
önizleme + kilit rozeti — canlı önizleme yolu, yeni sanat YOK); **Baloo 26**
ad (sanatın altında, diğer metinlerden güçlü); **fiyat yuvası 32 px**
(kilitlide "150 Hamur"; sahip olunanda Nunito 16 ipucu **"Koleksiyon'da
tak"** / takılıda **"Şu an takılı"** — kart çıkmaz sokak değil, yuva boş
kalmaz, durum plakası komşu SATIN AL hizasında); eylem yuvası 60 px: LOCKED →
SATIN AL / OWNED → `OwnedBadge` açık nane "✓ SAHİPSİN" (nane tik, erik yazı,
min 184×50) / EQUIPPED → `EquippedBadge` dolu nane "✓ TAKILI" (nane ailesi =
"senin"; lavanta-gri "pasif" ailesinden ayrık). Sahip olunan gövde
`PanelShopCardOwned` (`CREAM_DEEP`, bir ton geri vanilya). Durum `SkinEntry` tek kaynak; **Mağaza skin TAKMAZ**
(Koleksiyon takar), satın alınan skin SAHİPSİN'e döner, takılı değişmez.

### 16.4 Satın alma durumları ve geri bildirim

| Durum | Sunum |
|---|---|
| NORMAL | cyan SATIN AL (296×60), fiyat koyu altın |
| BASILI | buton koyu gövde + yazı 3 px aşağı + 0.94 squash (`UiMotion.attach_press`) |
| HAMUR YETMİYOR | `ButtonBuyLocked` soluk cyan (`CYAN_MUTED`) gövde + lacivert-mor yazı — hâlâ satın alma butonu okunur; fiyat **`PINK_DEEP`** (koyu altınla karışmaz), Hamur ikonu α .6; buton `disabled` DEĞİL — dokununca **onay AÇILMAZ**, kart 220 ms sallanır (±2.2°), `ui_invalid` + hafif titreşim, pembe `PanelShopToast` "Hamur yetmiyor · N Hamur'un var" **kartın hemen altında** (ekrana sığmazsa üstünde). Bedava Hamur / reklam rotası YOK. |
| ONAY | `UiKit.modal_frame("Satın Al", 560)` + `UiKit.seat_modal_close` (05.1: kurdele 60 px içeri, kapat X'i krem 4 px halka + erik gölgeyle gövde köşesine oturur, kurdele kuyruğuna binmez — yalnız Mağaza): ürün sunumu (190 px alan; güç: `candy_well` 164/118 / skin: rarity halesi + kuyu 168 + `SkinSwatch` 184 + rarity etiketi) → Baloo 30 ad ("Bomba ×1") → açıklama ("Stok ×3 → ×4" / "Rare skin · kalıcı, bir kez alınır") → Hamur 36 + Nunito 28 fiyat → Nunito 17 **"Bakiye 335 → 215"** (işlem şeffaf) → **SATIN AL** `ButtonCTA` (88) → Vazgeç `ButtonSecondary`; kapat / karartma / Android geri = Vazgeç, hiçbir şey harcanmaz. Onay yalnız Hamur yetiyorken açılır. |
| BAŞARI | kanonik tek transaction (`PowerUpEconomy.purchase` / `Shop.purchase` → `SaveManager.purchase_*_with_dough`, tek `save_game`) → `ui_purchase` + orta titreşim → kart `celebrate()`: 1.04 pop + stok rozeti 1.25 pop + 5 sabit açılı yıldız pırıltısı (güç) / önizleme 1.12 pop (skin) → bakiye pill'i pop → nane plaka (lacivert yazı, `EquippedBadge` dili) kartın altında: "Bomba ×1 alındı · Stok ×4" / "İspanak alındı · Koleksiyon'da tak". Bütün kartlar `refresh()` (yetmiyor durumları anında). |

Geri bildirim plakası (`PanelShopToast` `title_oval` + açık halka + erik
gölge + gloss, Baloo 21) ilgili kartın 12 px altında belirir (sığmazsa
üstünde; kart yoksa alt kenardan 150 + `safe_bottom` yukarıda), 34 px
yükselip söner (`UiMotion.toast`).

### 16.5 Rotalar

| Kontrol | Rota |
|---|---|
| Home MAĞAZA madalyonu / Home Hamur "+" / Harita Hamur "+" / Koleksiyon Hamur "+" | `_show_tab(3)` — tek Mağaza örneği, çubuk yok |
| Koleksiyon kilitli skin "MAĞAZAYA GİT" (M8.6-06) | `_show_tab(3)` + `ShopScreen.focus_skin(id)`: hedef skin kartı üst satırın altına kaydırılır + 1.03 pop (son kartlarda içerik sonuna kadar); Mağaza kompozisyonu / satın alma akışı değişmedi |
| Geri | `home_requested` → `main._on_home_requested` → Ana Sayfa |
| Android geri | `handle_back()`: onay açıksa kapanır; değilse `main._notification` → Ana Sayfa (ayarlar açıksa önce ayarlar; gameplay politikası aynen; çıkış yok) |

Mağaza Hamur'a doğrudan DOKUNMAZ (`add_dough` / `spend_dough` /
`data["dough"]` / `grant_*` / `equip_skin` / `save_game` yok — testle);
fiyat hardcode yok. **Gelecek Billing seam'i:** gerçek para Güç Paketi
(GAME_DESIGN §5.7.4, ×3/×6/×12 taslağı) gelirse GÜÇLER bölümünün altına
üçüncü bir `section_header` + aynı kart ailesinden bir "paket kartı" girer;
ekran yapısı ve `ShopPowerCard` değişmez. Şimdi YERLEŞTİRİLMEDİ.


---

## 17. Production Koleksiyon — skin galerisi (M8.6-06) — PRE-DEVICE VISUAL REVIEW

**Karar:** eski M8.5-13 koleksiyonu (düz beyaz başlık + lacivert cip, üç
üst üste lacivert plaka, 126 px kartlarda gri "?" silüetler + pembe kilit, 4
sütun sola yaslı grid, alt sekme çubuğu; vitrin sanatı ~141 px — Mağaza
kartındaki 164'ten küçük) "uygulama ayar sayfası / envanter tablosu"
okunuyordu (audit: `build/qa_m8.6-06/QA_NOTES.md`). Yeni yön: **premium
karakter gardırobu** — seçili skin candy kaide üstünde kahraman, galeri keşif;
Mağaza kopyası DEĞİL (satın alma yok), dashboard DEĞİL (ekranı krem plaka
kaplamaz — dünya görünür).

**Kod:** `scripts/ui/collection_screen.gd` (ekran), `scripts/ui/
collection_skin_card.gd` (`CollectionSkinCard`, tek kart bileşeni),
`scenes/ui/collection_screen.tscn`; `ScreenTopBar` (`with_add = true`);
`SkinSwatch.lock_badge_ratio` (vitrin kilit rozeti %26); `SkinData.
rarity_display_name/upper` (§8); `UiMotion.release`; `ShopScreen.focus_skin`
(MAĞAZAYA GİT hedef karta kaydırır). **Tema:** `PanelCollectionCard`,
`PanelCollectionCardLocked` (GENERATED). **Test:** `tools/collection_ui_test.
tscn` (164 kontrol; 4 pencere + A36 payı, üç vitrin durumu, taban görünüm
taksonomisi, aynı-kare basış/bırakış, kayıt byte-identical; bekçi +
`_exit_tree` güvenlik ağı). **A36 cihaz kapısı geçti (06.2, 2026-09-17,
`build/qa_m8.6-06/device/DEVICE_GATE_NOTES.md`):** native 1080×2340'ta üst
satır cutout altında ve kaydırmada 0 px, ORİJİNAL şeridi / rarity dili /
3 sütun / TAKILI okunur; karttan, sanattan, addan, kilitli karttan ve
şeritten başlayan sürüklemeler kaydırır ve seçmez; seçim kayıt yazmaz, TAK
tek yazma, Varsayılan TAK sayacı değiştirmez, 20/20 ödülsüz; Mağaza derin
bağlantısı dört rarity'de hedefi gösterir. Tek cihaz kusuru (aynı-kare
basış, yukarıda) `1c82f94` ile kapatıldı. Gözlem: Mağaza SATIN AL
butonundan başlayan sürükleme kaydırmıyordu (STOP) → 06.3 `dbf9127` ile
kapatıldı (§16). **Çekim:** `tools/collection_shots.tscn -- <dir>
[GxY] [safe=61]` (20 durum × 4 boyut + A36; 16 için gerçek equip yolu koşar,
kayıt sonda AYNEN geri yazılır). Eski `collection_album.*` ve `tab_bar.*`
SİLİNDİ. Sanat üretilmedi; yeni asset yok.

### 17.1 Kompozisyon (720 tuval, yükseklik serbest) — üç bölge

| Bölge | İçerik |
|---|---|
| **ÜST** (`ScreenTopBar`, sabit: `safe_top` + 14, 56 px satır, 24 px kenar) | sol `home_icon_button("back")` → Ana Sayfa · ortada pembe `HeaderRibbon` "KOLEKSİYON" · sağ Hamur `home_pill` + nane **"+"** → Mağaza (kilitli skinlerin satın alma yeri; Mağaza'nın kendisinde yok). Arkasında yumuşak çivit haze **yalnız satır bandında** (`WORLD_INDIGO` α .72, son 24 px'te 0): vitrin halesi satırın arkasında sönük, vitrin sanatına dokunmaz. |
| **VİTRİN** (sabit, satırın hemen altında; yükseklik `showcase_height()` = 2 + sanat + 12 + 56 + 34 + 12 + 60 + 12 + 52 + 12 → 548 (1280) / 572 (1560)) | arkadan öne: rarity halesi (`popup_glow` 520, Common lavanta .42 / Rare mavi .58 / Epic mor .62 / Legendary altın .62) + Legendary sıcak altın bloom (640, `GOLD_BRIGHT` .26) → erik temas gölgesi (430×136) → **candy kaide**: rarity renginde halka (+10) → koyu lavanta alt kalınlık (8 px aşağı) → yassı elips 324×54 (`item_circle_inner` gerilir; `TRAY_CREAM`, Rare/Epic/Legendary'de rarity rengine %16 boyanır) + üst parlama; kaide merkezi karakterin ayaklarının (sanat kutusunun %87'si) 10 px üstünde — karakter kaideye OTURUR → 6 sabit owner yıldızı (sinüs, RNG yok) → **sanat kutusu 296 px** (uzun ekranda 320'ye büyür; ≥ %41 tuval genişliği; `SkinSwatch.setup(entry, true)`: kilitli skin de FİNAL sanat + %26 kilit rozeti; `Breath` sarmalayıcısı ±%1.2 ölçek / 3 px süzülme, pivot ayaklarda) → ad (Baloo EB 34 beyaz, 56 px kutu) → etiket satırı (rarity trapezi 18 px: YAYGIN / NADİR / EPİK / EFSANEVİ, Varsayılan'da "ORİJİNAL" `RarityCommon`; yanında TEK durum çipi: SAHİPSİN `OwnedBadge` **ya da** Hamur ikonu + "N Hamur" lacivert çip — kilit zaten sanatın üstünde, çift kilit yok; takılıyken çip yok) → **eylem yuvası** 320×60 (bir yuva, bir eylem, aynı ayak izi: cyan `candy_button` **TAK** / **MAĞAZAYA GİT** **ya da** nane `title_oval` **✓ TAKILI** plakası — sarmalayıcı Control'de erik gölge + açık halka + gloss (PanelContainer dekoru içerik dikdörtgenine oturturdu), buton değil, dokunulmaz) → **KOLEKSİYON N/20 pill'i** 264×52 (Home pill dili: `LAVENDER_DEEP` `label_round` + açık halka + erik gölge + gloss; "KOLEKSİYON" 15 beyaz + sayı 19 + `ProgressBarMint` 11 px; **20/20**: `ProgressBarGold` + owner yıldızı + altın sayı — ödül VERMEZ). |
| **GALERİ** (`ScrollContainer`, vitrinin altından tabana; `MarginContainer` 24 / üst 14 / alt 64 + `safe_bottom`) | **En üstte "Varsayılan" TABAN görünüm şeridi (06.1):** aynı kart reçetesiyle 672×116 yatay `CollectionSkinCard` (`create(entry, true)`): sol kuyu + 92 px orijinal dumpling · "Varsayılan" Baloo 22 + lavanta `label_trapezoid` **ORİJİNAL** rozeti · sağda TAKILI yuvası; lavanta halka (Common'ın açık lavantasından bir ton doygun), rarity etiketi YOK (YAYGIN/Common denmez), fiyat YOK, sayaca girmez (GAME_DESIGN §5.3: seçilebilir taban görünüm, koleksiyon skini değil — galeri 21 seçenek, koleksiyon 20 skin). Farklı BİÇİM = farklı tür; tek kartlık orphan sıra yok, ~116 px. Sonra `UiKit.section_header` rarity plakaları — rarity sözlüğüyle aynı aile: YAYGIN gri-lavanta `#8a8aa8` / NADİR `#3f86d0` / EPİK `#8e4fc0` / EFSANEVİ altın `#d99a2b` — + 6 px boşluk + **3 sütunlu ortalı `HBoxContainer` sıraları** (h 12 / v 12; 24 + 216 + 12 + 216 + 12 + 216 + 24 = 720; eksik son sıra ORTADA: YAYGIN son ikili, Safran tek, iki Legendary çift — sağda boş yuva yok; GridContainer bunu yapamaz) — 8 / 6 / 4 / 2 katalog kartı, katalog sırası; YAYGIN Sade ile başlar (GAME_DESIGN §5.3: ilk seçenek Varsayılan — şeritte). Vitrin altı dikişi: vitrinin gölgesi galeriye düşer (18 px yukarıdan 0 → kesim çizgisinde `WORLD_INDIGO` .82 → 42 px'te 0) — kartlar bir yüzeyin ALTINA kayar, düz kesilmez. Sekmeye her girişte kaydırma en üstte. |
| **ZEMİN** | `ShellBackdrop` Home ayarında + radyal erik vignette (Harita/Mağaza ile aynı). Alt sekme çubuğu YOK. |

3 sütun kararı: 4 sütunda kart 159 / sanat ~100 px (eski ekranla aynı
küçüklük); 3 sütunda 216 / 124 px karakter 540×960'ta 93 px fiziksel okunur.
720×1280'de galeride ~2.6 sıra görünür; uzun ekranda fazla alan galeriye
gider (sanat +24). Kartta **fiyat YOK** (gardırop fiyat listesi değil — dört
bağımsız görsel kritik "Mağaza fiyat listesi okunuyor" dedi); fiyat seçilince
vitrinde (çip + MAĞAZAYA GİT).

### 17.2 Seçim ve durumlar (SkinEntry tek kaynak)

| Durum | Vitrin | Kart |
|---|---|---|
| SAHİP, takılı değil | SAHİPSİN çipi + **TAK** | krem gövde, rarity halkası, durum satırı boş |
| TAKILI | **✓ TAKILI** nane plakası (CTA yok; dokunuş mutasyon yapmaz) | nane `EquippedBadge` "✓ TAKILI" (kompakt, sanatı kapatmaz) — başka kart seçiliyken de görünür |
| KİLİTLİ | Hamur + "N Hamur" çipi + **MAĞAZAYA GİT** (→ `shop_skin_requested(id)` → `main` Mağaza'yı açar ve `ShopScreen.focus_skin(id)` hedef kartı üst satırın altına kaydırır + 1.03 pop; son kartlarda içerik sonuna kadar; Koleksiyon SATIN ALMAZ) | buzlu gövde (`PanelCollectionCardLocked`) + sanat %14 soğuk buz (`LOCKED_FROST`) + owner kilit rozeti (sağ alt, gövdede); fiyat kartta YOK |
| SEÇİLİ (herhangi biri) | vitrin bu girişi gösterir | cyan dış halka (+7) + cyan hale + 1.04 pop; seçim değişince eski kart sakinleşir |
| VARSAYILAN (taban) | ad "Varsayılan", etiket **ORİJİNAL** (`RarityCommon` gövde, metin ORİJİNAL), SAHİPSİN + TAK ya da TAKILI; fiyat/kilit asla | geniş şerit (yukarıda); TAKILI plakası sağ yuvada; seçim halkası aynı |

Açılış seçimi (`refresh`, her sekme girişi): görünmezken kazanılan skin
(`skin_granted` → `_pending_focus`) → yoksa **takılı skin** (`SaveManager.
equipped_skin_id()`, bozuk id güvenli biçimde Varsayılan'a düşer, kayda
yazmaz). Kart dokunuşu (`CollectionSkinCard.selected`) yalnız `select()`:
vitrin geçişi 0.2 s (sanat 0.94 → 1.0 + solma, hale retint tween), `ui_select`;
**kayıt DEĞİŞMEZ**. **TAK** → `SaveManager.equip_skin(id)` (tek kanonik
yazma; `skin_equipped` → kartlar `refresh()`, vitrin TAKILI, `ui_equip` +
hafif titreşim, sanat/plaka pop + 8 altın yıldız patlaması `Fx` katmanında).
Varsayılan kartı da seçilir ve takılır (`equip_skin("")`). Rarity görüntü adı
Türkçe (§8); iç ad/enum/id değişmedi.

### 17.3 `CollectionSkinCard` anatomisi (216×220)

Stilsiz `Button` (`MOUSE_FILTER_PASS`, tüm kart dokunma hedefi,
`UiMotion.attach_press`; kaydırma başlayınca `NOTIFICATION_SCROLL_BEGIN` →
`UiMotion.release`); arkadan öne: seçim halesi (cyan `popup_glow`, yalnız
seçili) → Legendary altın hale (`GOLD_BRIGHT` .55) / Epic mor hale (.30) →
erik gölge → seçim halkası (cyan `frame_round20` +7, yalnız seçili) →
rarity halkası (+4: Common `LAVENDER_LIGHT`, Rare `RARITY_RARE`→beyaz %25,
Epic `RARITY_EPIC`→beyaz %22, Legendary `GOLD` — Mağaza 05.1 kalibrasyonu)
→ 2 px erik kontur → gövde (`card_bevel_soft`; 10/8/10/**22** iç pay: alt
dudak ~11 px + nefes, TAKILI plakası krem yüzün içinde kalır — testle;
Legendary gövde her durumda altın-krem `CREAM`→`GOLD_BRIGHT` %12, Mağaza
gibi) → `UiKit.card_face` → sahne 130: rarity renginde düşük alfa hale (176;
.14/.18/.20/.26) → `TRAY_CREAM` kuyu 110 → **`SkinSwatch` 124 px** (gerçek
final sanat; 20 farklı doku — testle) → Baloo 19 ad (kırpma + üç nokta;
21 ad sığıyor — testle) → durum satırı 26 (TAKILI plakası | boş). Legendary
kartta 4 köşe pırıltısı (Mağaza kartıyla aynı dil; sinüs, ekran
`_process`'inden `tick_sparkles`). Kart kayda YAZMAZ, takmaz.

### 17.4 Rotalar

| Kontrol | Rota |
|---|---|
| Home KOLEKSİYON madalyonu | `_show_tab(2)` — tek örnek |
| Geri | `home_requested` → `main._on_home_requested` → Ana Sayfa |
| Android geri | `main._notification` → Ana Sayfa (pencere yok; gameplay politikası aynen; çıkış yok) |
| Hamur "+" | `shop_requested` → `main._on_shop_requested` → Mağaza (tek örnek, en üst) |
| Kilitli MAĞAZAYA GİT | `shop_skin_requested(id)` → `main._on_shop_skin_requested` → Mağaza + `focus_skin(id)` (hedef kart üst satırın altında; Mağaza kompozisyonu değişmedi) |

Koleksiyon kaydı yalnız `equip_skin` ile yazar; `purchase` / `spend_dough` /
`add_dough` / `grant_skin` / `save_game` / `data["dough"]` çağrısı yok
(kaynak taramasıyla testli). Ekonomi, fiyatlar, sandık, kayıt şeması,
gameplay, Home, Harita, Mağaza kompozisyonu DEĞİŞMEDİ (Mağaza yalnız Türkçe
rarity etiketi aldı).

### 17.5 Performans

Ekran ~800 düğüm (21 kart × ~27 + vitrin ~50 + 4 plaka; eski ekran ~220).
Kartlarda `_process` YOK; yalnız ekran işler (görünürken): vitrin nefesi + 6
yıldız + 2 Legendary kartın 2'şer pırıltısı (10 sinüs güncellemesi/kare).
Büyük yumuşak dokular (`popup_glow` 470/600) alfa-karışımlı NinePatch;
cihaz ölçümü A36 kapısında.

---

## 18. İkincil UI denetimi — pencereler ve round sonu (M8.6-07, AUDIT)

**Kapsam:** Home / Harita / Mağaza / Koleksiyon / gameplay HUD onaylı referans;
kalan **yedi** runtime yüzeyi (hepsi `main.gd` `_ready`'de bir kez kurulan
`CanvasLayer`) + Mağaza onayı (referans) denetlendi, yeniden tasarım YAPILMADI.
Kanıt: `tools/secondary_ui_shots.tscn` (48 durum × 4 pencere + A36 simülasyonu,
kayıt byte'ı geri konur) → `build/qa_m8.6-07/` (envanter, ekran ekran denetim,
bağımlılık haritası, yol haritası, contact sheet'ler).

**Üç pencere iskeleti var (kod gerçeği):**

| İskelet | Kullanan | Karar |
|---|---|---|
| **A** `UiKit.modal_frame` (§5 `PanelModal` + kurdele + pembe kapat) | Mola, Bonus Sandık, Mağaza onayı (yalnız Mağaza'da `seat_modal_close`) | production; kapat halkası varsayılan olmalı, owner tepeliği (§10) seçenek |
| **B** M8.5-08 candy panel (`panel_candy.png` 600×540/560/650/770'e gerilmiş + `panel_candy_crown` + boş `ModalPanel`) + `CandyButton` mavi yıldızlı pill CTA | Günlük, Ayarlar, Devam, Refill | emekli: doku 9-slice değil (Refill %34 dikey gerilme), CTA ailesi §6'da yasak, birincil/ikincil aynı buton |
| **C** M8.5-10 koyu `PanelContainer` (`SB_surface`) + `CardPanel` + tema varsayılan neon `Button` | Round sonu | emekli: oyundaki son koyu M8.5 sayfası, HUD durum plakası içinden okunuyor |

**Ölçülen kusurlar (özet; ayrıntı build/qa_m8.6-07/SECONDARY_UI_AUDIT.md):**
Ayarlar'da Gizlilik → Göster metni sabit çerçeveden TAŞIYOR (sürüm satırı +
Kapat panel dışında, her boyutta); Round sonu sandık başlıkları İngilizce
(`ChestReward.title` → `rarity_name`), 80 px sandık kartı ödül anı vermiyor,
panel yalnız aşağı büyüyor (3 sandıkta CTA'lar kap dudağında, 4+ ödülde
ekran dışı, kaydırma yok), "Level listesi" etiketi eski (rota Harita); Devam:
"Bitir" ile "DEVAM ET" aynı pill, talep durumunda hiyerarşi tersine dönüyor;
Refill: üç aynı CTA; Mola/Bonus Sandık: kapat X kurdele kuyruğunda (05.1
yalnız Mağaza'ya uygulandı). Tipografi ailesi her yerde Baloo/Nunito (sistem
font yok); sorun rol/boyut/büyük-küçük harf. Android geri matrisi: tek boşluk
Refill (yok sayılıyor; beklenen = Kapat).

**Yol haritası (bağımlılığa göre, `build/qa_m8.6-07/SECONDARY_UI_ROADMAP.md`):**
**M8.6-08** modal shell v2 (`modal_frame`: oturmuş kapat varsayılan, tepelik,
kahraman sanat yuvası, taşmayan/kaydırılabilir gövde, tek açılış hareketi) +
Ayarlar (`settings_row`, picto + `switch_toggle`) + Günlük (7 günlük seri
şeridi, ödül çipi) + Mola/Bonus Sandık kapat oturması → A36 kapısı.
**M8.6-09** Round sonu / level tamam / kayıp + sandık reveal (`RewardCard`
+ mevcut `RewardGem`, Türkçe rarity, HARİTA CTA'sı; reveal zamanlaması, ses,
haptik, `Main` sözleşmesi aynen) → A36 kapısı. **M8.6-10** Devam + Refill
(shell v2, `UiKit.cta` iki satır, birincil/`ButtonPurchase`/ikincil
hiyerarşisi; 2 devam/round ve 1 refill/gün politikası, token, sağlayıcı
seam'i DEĞİŞMEZ) + `CandyButton` CTA / candy panel sahneleri / M8.5 rollerinin
emekliye ayrılması → A36 kapısı. Genel onay (`ConfirmationModal`) için kanıt
yok; "Ana Menüye Dön" onayı owner kararı.

---

## 19. Pencere iskeleti v2 + Ayarlar + Günlük + Mola/Bonus Sandık cilası (M8.6-08) — A36 CİHAZ KAPISI GEÇTİ (3d682e6)

**Kod:** `scripts/ui/ui_kit.gd` (`modal_shell`, `modal_relayout`,
`modal_body_cap`, `set_modal_height_cap`, `attach_dim_close`, `settings_row`,
`settings_divider`, `_seat_close`), `scripts/ui/streak_strip.gd`
(`StreakStrip`), `scripts/ui/settings_panel.gd` + `.tscn`,
`scripts/ui/daily_reward_popup.gd` + `.tscn`, `scripts/ui/pause_menu.gd`,
`scripts/ui/bonus_chest_info.gd`, `scripts/main.gd` (tek koruma satırı).
**Test:** `tools/secondary_modal_ui_test.tscn` (102). **Çekim:**
`tools/secondary_ui_shots.tscn -- <dir> [GxY] [safe=61] [groups=daily,chest,settings,pause,generic]`
→ `build/qa_m8.6-08/` (before = M8.6-07 denetim kareleri, after/final 21
durum × 4 pencere + A36, contact sheet'ler). Tema **değişmedi** (yeni
variation yok); `modal_frame` **değişmedi**.

### 19.1 `UiKit.modal_shell` anatomisi (shell v2)

`modal_shell(title, width = 560, header = &"ribbon" | &"heading", topper,
closable, glow)`; meta: `body`, `footer`, `close_button`, `ribbon` /
`heading`, `topper`, `scroll`, `body_host`, `panel`, `column`, `fade`,
`body_scrolls`.

| Katman | Malzeme | Not |
|---|---|---|
| parıltı | `popup_glow` `GLOW_SUBTLE` (−70 px) | modal_frame ile aynı |
| gövde | `PanelModal` (`popup_body` krem, iç pay 36/56/36/36) | üst 56 = kurdele/tepelik payı |
| gloss | `popup_light` α .5, üst 33 px | |
| sütun | VBox: [`heading`] / `body_host` / `footer` | ayrık 12 |
| `body_host` | düz Control: tam dikdörtgen `ScrollContainer` (dikey `SHOW_NEVER`, yatay kapalı, stil boş) + altta 40 px krem solma bandı (`fade`, yalnız kaydırılabilirken) | band ScrollContainer'ın çocuğu OLAMAZ (her çocuğu içerik sayar) |
| `body` | VBox, ekranın içeriği | kaydırılan tek bölge |
| `footer` | VBox (ayrık 8), CTA alanı | **hiç kaydırılmaz**; boşsa gizli |
| kurdele | `HeaderRibbon`, iki yandan **60 px** içeride, −34/+46 | `header = &"ribbon"` (Mola, Bonus Sandık; Mağaza onayı ile aynı ölçü) |
| başlık | `LabelTitle` 32 ortalı, gövde içinde | `header = &"heading"` (Ayarlar, Günlük) |
| tepelik | `panel_candy_crown.png` 300×96 (1024×328, oran korunur), −62 px taşma | owner kimlik katmanı (§10) |
| kapat | `ButtonRoundIcon` 64, sağ üst köşe (−40/+24, −26/+38), **her zaman oturmuş** (`_seat_close`: erik temas gölgesi + krem halka +4, 05.1 reçetesi) | kurdele kuyruğuyla kesişmez (testle) |

**Boyut sistemi.** Pencere içeriği kadar büyür (min = doğal gövde). Tavan:
`modal_body_cap` = tuval yüksekliği − `safe_top` − `safe_bottom` −
2 × `MODAL_OUTER_MARGIN` (36) − tepelik/kurdele taşması − krom (panel iç
payları + başlık + altlık + aralar). Doğal gövde tavanı aşarsa **gövde
kaydırılır** (`body_host` yüksekliği = tavan, en az `MODAL_BODY_MIN` 160),
metin küçültülmez, altlık yerinde kalır. `set_modal_height_cap(frame, h)`
pencere toplam yüksekliğini dışarıdan sınırlar (test / prova). Not:
`canvas_items` + `expand` tuvali hiçbir pencerede 1280'in altına indirmez
(540×960 = 720×1280'in 0.75'i), yani gerçek en kısa durum 1280'dir;
Gizlilik açık Ayarlar (≈ 700 px) ona sığar, kaydırma yalnız daha kısa
tavanda devreye girer (`secondary_modal_ui_test` 640 tavanıyla kanıtlar).

**Karartma.** `UiKit.attach_dim_close(dim, callback)`: tüm ikincil
pencerelerde TEK anlam — parmak/tık **bırakılınca** (basışta değil);
dokunmadan üretilen emülasyon fare olayı (`device == -1`) atlanır (bir dokunuş
iki kez tetiklemez); karartma `STOP` (arkadaki ekrana tıklama sızmaz —
Ana Sayfa OYNA'nın üstüne tık Harita'ya gitmez, testle). Renk her yerde
`Color(0.05, 0, 0.06, 0.62)` (değişmedi).

**Z-order.** Ayarlar katman **13** (Mola/Günlük/Sandık 12'nin üstünde):
Ayarlar ile Mola bir arada görünürse Ayarlar önde, Mola karartmanın arkasında
etkileşimsiz. `Main.open_pause_menu` Ayarlar açıkken mola AÇMAZ (tek odak
kuralı; dokunma yolu zaten karartmayla kapalıydı, kod yolları da kapandı).
Ayarlar kapanınca mola açıksa board donuk kalır (değişmedi).

**`modal_frame` (M8.6-01) DEĞİŞMEDİ:** Mağaza onayı onu + `seat_modal_close`
ile kullanmaya devam ediyor; `seat_modal_close` gövdesi `_seat_close`'a
taşındı (aynı düğüm sırası/ölçü) — `generic_01/02` kareleri M8.6-07
denetimiyle 5 pencere yapılandırmasında **piksel piksel aynı** (PIL fark = 0).

### 19.2 Ayarlar (yeniden kurulum)

`modal_shell("AYARLAR", 560, heading, tepelik)`. Gövde (ayrık 4):
`UiKit.settings_row` × 3 (44 px lavanta yuvarlak kuyucuk + 26 px plum picto
`sound_on` / `vibration` / `info`, `LabelSection` 24 başlık, sağda kontrol),
aralarında 2 px lavanta `settings_divider`. Kart çerçevesi YOK. Anahtar:
`UiKit.switch_toggle` 96×52 (`SwitchOn` nane / `SwitchOff` lavanta-gri +
LayerLab topuz), **`MOUSE_FILTER_PASS`** (kısa tavanda gövde kaydırılırken
anahtardan başlayan sürükleme de kaydırır; BaseButton kaydırma başlayınca
basışı iptal eder, anahtar yanlışlıkla dönmez). Gizlilik: `ButtonSecondary`
132×58 Göster/Gizle → gövdede bir ton geri krem (`CREAM_DEEP`,
`frame_round20`) plaka + `LabelBody` 19 `TEXT_SECONDARY` metin (kanonik kopya
`PRIVACY_TEXT`, değişmedi). Altlık: `LabelCaption` `TEXT_TERTIARY` sürüm +
`ButtonSecondary` Kapat. **Eski taşma kusuru yapısal olarak kapandı**
(pencere içeriği kadar büyür; 720×1280 / 1560 / 540×960 / 1080×2340 / A36'da
metin, sürüm ve Kapat panelin içinde — regresyon kontrolü). Kayıt sözleşmesi
aynı: yalnız `set_sfx_enabled` / `set_haptics_enabled` (dokunuşta), açıp
kapamak yazmaz. Müzik anahtarı bilerek yok. X / Kapat / karartma / Android
geri → `close_panel` (Ana Sayfa aynen kalır, uygulama kapanmaz).

### 19.3 Günlük ödül (yeniden kurulum) + `StreakStrip`

`modal_shell("GÜNLÜK ÖDÜL", 560, heading, tepelik)`. Gövde (ayrık 8):
`UiKit.candy_well(icon_dough, PINK, 164, 118)` (Mağaza onayı ürün sunumuyla
aynı ölçek; Ana Sayfa Günlük madalyonuyla aynı pembe aile) + 4 sabit altın
pırıltı (owner yıldızı) + sanatın yavaş süzülmesi (tek loop tween, kapanınca
durur; `_process` yok) → `LabelPrice` 38 **"+15 HAMUR"** (durum modunda
`LabelPositive` 24 "Bugünkü ödülünü aldın") → altın `Badge` **"N. GÜN"** →
`StreakStrip` → not (`LabelWarning` "Serin kırılmıştı, sayaç sıfırlandı." /
`LabelCaption` "Yarın tekrar gel, seri devam etsin."). Altlık: `ButtonCTA` 88
**AL** (ödül) ya da `ButtonPrimary` 58 **TAMAM** (durum).

`StreakStrip` (Control, 7 düğüm 44 px, bugün ×1.14, 14 px iç pay, altında
1–7 numaraları `LabelCaption`, bağlantı çizgileri `_draw` ile arkada):
CLAIMED nane disk + beyaz tik; TODAY altın odak halkası + krem disk + soluk
yıldız (kutlanmamış) / altın disk + parlak yıldız (`mark_today`, pop 1.22);
FUTURE lavanta-krem disk. Segmentler: tamamlanan nane, bugüne gelen altın,
gelecek lavanta. Seri > 7: 7. düğümde altın `CountBadge` "+N". Gün başına
farklı ödül **icat edilmedi** (runtime her gün `DailyReward.DAILY_DOUGH`).

**Claim işlemi (değişmedi):** ödül `DailyReward.claim_if_new_day` ile
Main'in açılış / madalyon yolunda kayda yazılır (`record_daily_login` +
`add_dough`, tek Hamur + tek seri mutasyonu), pencere yalnız gösterir. **AL**
kutlamadır: bugünkü düğüm yıldız + kuyu pop + 8 yıldızlık 0.42 s patlama
(deterministik tween'ler, parçacık düğümü yok) → 0.48 s sonra `close_popup`
→ `closed` → `Main._on_daily_closed` → Ana Sayfa yenilenir (Hamur pill'i
kanonik yoldan güncellenir). AL kayda DOKUNMAZ (kaynak taramasıyla testli);
ikinci basış yok sayılır; Android geri / X / karartma kutlamayı beklemez.
Aynı gün ikinci açılış = durum modu, ödül tekrar verilmez.
**Karartma dokunuşu kapatır (M8.6-08'de eklendi)** — diğer Ana Sayfa
pencereleriyle aynı; `show_reward` / `show_status` / `close_popup`
imzaları aynı.

### 19.4 Mola / Bonus Sandık (dar cila)

Mola: `modal_shell("Mola", 560, ribbon)`; üç eylem altlıkta — `ButtonCTA`
DEVAM ET (play) / `ButtonSecondary` Yeniden Başlat (refresh) / ince ayraç /
`ButtonDanger` Ana Menüye Dön (home); "Oyun duraklatıldı." dolgu satırı
kalktı; X oturmuş; X ve karartma = devam (bırakışta). Eylemler, terk,
Android geri, onay penceresinin olmaması DEĞİŞMEDİ.

Bonus Sandık: `modal_shell("Bonus Sandık", 560, ribbon)`; owner sandık sanatı
altın `candy_well` (150/112, ödül rengi) içinde; kural metni elle satır kırma
yerine autowrap; `ProgressBarGold` 22 + `LabelStat` sayaç + `LabelCaption`
kalan; OYNA altlıkta. İlerleme kaynağı, rota, uygunluk DEĞİŞMEDİ. Not:
"Sandık hazır" dalı runtime'da erişilemez — tasarım gereği (`add_merges`
sayacı `% 75` saklar, sandık aynı çağrıda verilir; sayaç 75'e ulaşmaz),
mantık kusuru değil; dal güvenlik için duruyor.

### 19.5 A36 cihaz kapısı (M8.6-08.1, 2026-09-18, 3d682e6)

Samsung SM-A366B, Android 16, native 1080×2340 (density 450, cutout 92 px):
debug APK 45 579 140 B sızıntısız (build/tools/_visual_source/docs/md/py/zip/sh/
kayıt/logcat 0; dört pencere + `modal_shell` / `StreakStrip` / `UiToggle`
sembolleri paketlenmiş bytecode'da). Owner kaydı (670 B) yalnız görsel
gezinmede kullanıldı — açılış, oyunun kendi kanonik günlük yolunu koştu
(dünkü giriş → 5. GÜN, gerçek otomatik açılış cihazda görüldü), AL owner
kaydında hiç basılmadı, sonda byte-identical geri kondu ve oyun bir daha
açılmadı. Native bulgular: tepelik/oturmuş X/krem gövde keskin; Ayarlar
Gizlilik açıkken metin + sürüm + Kapat panelde (4 aç/kapa döngüsünde panel
üst kenarı 846/723 px sabit, kayma yok), anahtar dokunuşları yalnız
`sfx_enabled` / `haptics_enabled` yazdı, sürükleyip bırakma anahtarı
döndürmedi ve 0.94'te bırakmadı; X / Kapat / geri / OYNA üstüne karartma
dokunuşu tek kapanış, Home'a sızma yok. Günlük: 1 / 4 / 12 (+5 rozeti
kırpılmadı) / kırık seri durumları geçici kayıtlarla; claim yalnız açılış
yolunda tam bir kez (+15, seri +1, tarih), AL basış görseli + kutlama +
kapanış + Home yenileme, AL sonrası kayıt md5 aynı; sürükleyip bırakma claim
etmedi; ikinci açılış "Bugünkü ödülünü aldın" + TAMAM, Hamur sabit;
alınmış durumda yeniden açılış pencere açmadı; 10 s boşta metin/şerit/CTA
0 px, yalnız kuyu sanatı süzülüyor, PSS 331→326 MB. Mola: geri / X / DEVAM ET
devam, Yeniden Başlat / Ana Menüye Dön semantiği aynı; Bonus Sandık 10 / 49 /
74; tek odak: karartma altındaki HUD butonları ikinci pencere açmıyor;
Mağaza onayı cihazda değişmemiş. logcat: SCRIPT ERROR 0 / E godot 0 / res://
0 / shader 0 / FATAL 0 / ANR 0. Cihaza özel kusur YOK, runtime değişmedi.
Kapı sonrası masaüstü otomatik kapı 3d682e6'da ilk koşuda temiz.
Kanıt: `build/qa_m8.6-08/device/` (20 zorunlu kare + ek kareler, 4 contact
sheet, DEVICE_GATE_NOTES.md).

### 19.6 Taşınmayan yüzeyler (bilerek)

Round sonu M8.6-09'da (§20), Devam ve Refill M8.6-10'da (§21) taşındı — M8.5
iskeleti kalmadı; `CandyButton`, `panel_candy.png`, `UiPalette`, candy pill
dokuları ve `assets/visual/ui/icons/` M8.6-10'da **silindi** (§21.6). Mağaza
onayı `modal_frame`'de kaldı (cihazda onaylı; piksel eşdeğerliği kanıtlanmış
olsa da göç için sebep yok).

---

## 20. Production Round sonu — level tamam / kayıp / ödül reveal (M8.6-09) — DEVICE VERIFIED (A36)

**Kod:** `scripts/ui/round_result.gd` + `scenes/ui/round_result.tscn` (kompozisyon,
katman 10), `scripts/ui/result_reward_card.gd` (`ResultRewardCard`),
`scripts/ui/result_star_strip.gd` (`ResultStarStrip`), `scripts/ui/reward_gem.gd`
(`setup(reward, size)`, `settle()`, `continuous_effects()` — RARITY_FX tablosu
DEĞİŞMEDİ), `scripts/game/chest_reward.gd` (Türkçe `title/description/note`),
`scripts/ui/ui_kit.gd` (`modal_shell`: **`hero` sabit üst bölge** + `topper_scale`
+ `glow` metası), `scripts/main.gd` (`show_result`'a salt-okunur `newly_unlocked`
/ `reached_tier`; RESULT_DELAY aralığında mola kilidi), `scripts/game/game_board.gd`
(`is_finished()` / `max_tier_reached()` okuyucuları), `tools/make_result_art.py`
→ `assets/visual/ui/icon_star_empty_soft.png` (owner kontur yıldızının beyaza
normalize türevi; boya runtime'da). **Test:** `tools/result_ui_test.tscn` (226).
**Çekim:** `tools/result_shots.tscn -- <dir> [GxY] [safe=61] [only=05,13]` →
`build/qa_m8.6-09/` (before = M8.6-07 denetim kareleri, after/v1 → v2 → final,
contact sheet'ler, QA_NOTES). Tema **değişmedi** (yeni variation yok).

**Neydi (M8.6-07 denetimi):** oyundaki son koyu M8.5-10 sayfası — yarı saydam
lacivert panel (HUD "Hedef tamam!" plakası içinden okunuyordu), 80 px sandık
satırları, İngilizce rarity başlıkları, gerilmiş `banner_new.png`, neon varsayılan
Button + "Level listesi", yalnız aşağı büyüyen 680 px kutu (3 sandıkta CTA kap
dudağında, 4+ ödülde ekran dışı, kaydırma yok), kazanma/kayıp yalnız başlık
kelimesiyle ayrışıyordu, skin ödülü sanatsız.

### 20.1 Mimari — tek bileşen, üç mod

`UiKit.modal_shell("", 600, ribbon, topper=true, closable=false, topper_scale 1.18)`:
X YOK (karar ekranı — çıkış yalnız iki CTA'dan). Sütun: **hero** (sabit) →
**body** (kaydırılan ödül kartları) → **footer** (sabit: özet çipleri + CTA'lar).
Karartma `Color(0.05, 0, 0.06, 0.74)` STOP (arkadaki HUD'a dokunuş sızmaz;
dokunuş kapatmaz). Çerçeve `CenterContainer` içinde; `Anchor.offset_top` =
aktif taşma (tepelik 73 / kurdele 34) → tepelik + gövde bileşiği ortalanır,
kısa ekranda tepelik üst kenara / çentiğe yaslanmaz.

| | WIN | FAIL | ENDLESS |
|---|---|---|---|
| tepelik | owner kanatlı kalp ×1.18 (354×113) | yok | yalnız yeni rekorda |
| kontur / parıltı | 4 px altın `popup_body` halkası (panelin arkasında; altta panelin pişmiş gölgesi kalır) + sıcak `GLOW_WIN` | yok / `GLOW_SUBTLE` | rekor: altın; değil: yok |
| başlık | gövde İÇİNDE altın `header_ribbon` "LEVEL 4 TAMAM!" (beyaz Baloo 34 + 6 px `GOLD_DEEP` kontur) | üst kenardan taşan `LAVENDER_DEEP` kurdele "OLMADI" | "YENİ REKOR!" (altın, gövde içi) / "TUR BİTTİ" (lavanta, kenar) |
| hero | [yeni kilit rozeti] + `ResultStarStrip` | `ResultStarStrip` (0★) + teşvik satırı | SKOR kahraman çipi (Nunito 44) |
| footer çipleri | SKOR · HEDEF (+skor satırı) · HAMUR | aynı | REKOR · HAMUR |
| kahraman CTA (`ButtonCTA`) | **HARİTA** (`map`) → `exit_pressed` | **TEKRAR DENE** (`refresh`) → `retry_pressed` | **TEKRAR OYNA** → `retry_pressed` |
| ikincil (`ButtonSecondary`) | TEKRAR OYNA → `retry_pressed` | HARİTA → `exit_pressed` | HARİTA → `exit_pressed` |

Rota kanonik ve DEĞİŞMEDİ: `exit_pressed` → `Main._on_exit_pressed` (board
silinir, Harita; yeni açılan düğüm oradaki açılış animasyonuyla),
`retry_pressed` → `_start_level(_current_level)`. "Sonraki level" rotası icat
edilmedi. Kilit rozeti: `EquippedBadge` nane "LEVEL N AÇILDI" (`unlock`
picto) / L10'da altın `Badge` "SONSUZ MOD AÇILDI" (`trophy`) — yalnız Main'in
yazımdan önce-sonra karşılaştırdığı `newly_unlocked` true iken (tekrar
oynanan level'da yok). Teşvik: ulaşılan tier = hedef−1 → "Hedefe çok
yaklaştın!"; hedef tier'a ulaşılmış ama skor hedefi (L8/L10) eksik → "Hedef
tier tamam, skor az kaldı!"; diğer → "Bir dahaki sefere!". Kazanma dili
Sonsuz'da hiç kullanılmaz.

### 20.2 `ResultStarStrip`

Üç owner yıldızı yay üzerinde (yan 86, orta 104 ve 16 px yukarıda, aralık 10;
126 px şerit). Kazanılan = dolu altın; kazanılmayan = `icon_star_empty_soft`
× `#c9b3e6` (yumuşak lavanta kontur — "üç kez kaybettin" okunmaz). Reveal:
`set_stars(earned, hidden)` → `reveal(i)`: 0 → 1.28 → 1.0 yay (0.16 + 0.14 s)
+ 5 mini altın yıldız pırıltısı (0.42 s, deterministik açılar, parçacık düğümü
yok). Sahibi 0.3 s bekler, yıldızları **0.2 s arayla** açar (owner brief'i §10;
GAME_DESIGN §5.1'deki ~400 ms notu bu brief'le güncellenmeli — doküman
değişikliği owner onayına bırakıldı) ve `star_reveal`'i 1.0/1.12/1.24 pitch ile
çalar. Kayıpta pop yok (sahte kazanım yok); Sonsuz'da şerit gizli.

### 20.3 `ResultRewardCard` (528 × 128 / skin 176)

Yatay satır, `card_bevel_soft` gövde (`TRAY_CREAM`; teselli `CREAM_DEEP`;
Legendary krem→`GOLD_BRIGHT` %14) + `frame_round20` halka (Common gri-lavanta /
Rare mavi / Epic mor / Legendary altın + altın hale + 3 pırıltı) + erik gölge +
`card_face`; gövde `clip_contents` (sandık ışınları kartın içinde kalır, halka
ve hale kökte). **Sahne** (116; skin 160): rarity renginde düşük alfa hale →
`RewardGem` 88 (kapalı sandık; `open()` = owner sandığı açılır + kalibre rarity
katmanları). **Yazı sütunu** (açılışa kadar α 0): `UiKit.rarity_tag` (YAYGIN /
NADİR / EPİK / EFSANEVİ) ya da lavanta "TESELLİ" trapezi → ana satır → not.

| ödül | sahne | ana satır | not |
|---|---|---|---|
| Hamur (rarity) | sandık açık, katmanlar | Hamur ikonu 34 + `LabelPrice` 30 "+25 HAMUR" | — |
| skin | sandık açılır → 0.24 s sonra söner/küçülür → krem `item_circle_inner` kaide üstünde GERÇEK final sanat `SkinSwatch` 140 pop (0.28 s) | skin adı Baloo 30 | pembe **YENİ SKİN** rozeti (pop) + "Koleksiyon'a eklendi"; satın alma CTA'sı YOK |
| geri düşüş (rarity tamam) | Hamur kartıyla aynı | "+60 HAMUR" | "Epik skinlerin tamamı sende" (iç terim yok, skin verildi denmez) |
| teselli | sandık YOK: lavanta `candy_well` 84 içinde owner Hamur sanatı | "+5 HAMUR" | — |

Kart `MOUSE_FILTER_IGNORE` (eylemi yok → karttan başlayan sürükleme doğrudan
ScrollContainer'a). Kart kayda DOKUNMAZ; skin vitrini `SkinEntry.for_skin` +
`owned = true` ile her zaman "senin" görünümünde (kanonik grant ekrandan önce).
Reveal sonunda `settle()`: parçacık yayımı ve nabız durur, ışın dönüşü yalnız
Legendary'de kalır; kart başına `_process` yok; Legendary pırıltıları sahibin
tek `tween_method`'undan (Legendary kart yoksa hiç çalışmaz).

### 20.4 Reveal ve Hamur sayacı

`show_result` → kartlar kurulur (α 0, yer ayırır) → `modal_relayout` →
`UiMotion.modal_open` → 0.3 s → yıldızlar (0.2 s) → her kart: 0.45 s bekle
(4+ ödülde 0.30), gövde kaydırılıyorsa açılan karta kay (0.28 s), `appear()`
(0.26 s yay) + `chest_open` (teselli hariç), 0.35 s (4+ ödülde 0.25) sonra
`open()` + rarity renginde ışık
patlaması (FxLayer, kırpılmaz, kendini siler) + `AudioManager.play_reward` +
titreşim (Legendary `special`, Epic/yeni skin `medium`, Hamur `light`) →
sonda `settle()`. Butonlar ilk kareden aktif ("hemen tekrar dene"). HAMUR çipi
`SaveManager.dough() − açılmamış Hamur` ile başlar, her açılışta pop'la artar →
son değer = kayıt (sayaç yalnız sunum; harness'ta sahte ödülle de tutarlı).
`_sequence_id` gizleme / yeniden açılışta eski reveal'i geçersiz kılar;
`hide_result` kartları serbest bırakır, döngüleri öldürür.

### 20.5 Taşma / kaydırma

Doğal yükseklik: 1 ödül ≈ 676, 3 ödül ≈ 956 px (720×1280 tavanı 1146 −
krom). **4 Hamur kartı 1280'e sığar; 5+ ödülde gövde kaydırılır**, hero
(başlık + yıldız) ve altlık (çipler + CTA) SABİT. Runtime'da ödül sayısı için
tavan yok (level: 1 sandık + ⌊(merge+taşıma)/75⌋ bonus; tipik L10 ≈ 3; Sonsuz
uzun tur ≈ 5); harness 5 (Sonsuz gerçekçi en çok) ve 6 (stres) ile doğrular:
bütün kartlar kaydırmayla erişilir, birbirine binmez, altlık ve CTA ekranda.

### 20.6 Sıra, geri tuşu, güvenlik

Devam teklifi (katman 11) açıkken sonuç YOK: `round_finished` yalnız Bitir /
hak yok yolunda yayılır; Main teklifi kapattıktan 0.8 s sonra sonuç açılır
(sonuç teklifin altında hiç görünmez). Android geri sonuçta yok sayılır
(değişmedi); yeni: RESULT_DELAY aralığında da mola açılmaz
(`Main.open_pause_menu` `is_finished()` kilidi — eskiden bu 0.8 s'de açılan
mola "Ana Menüye Dön" ile board'u silip sonucu haritanın üstünde
bırakabiliyordu). Bütün yazımlar (`complete_level`, `record_stars`,
`ChestSystem.open/consolation`, `add_merges`, `record_endless_score`) sonuç
açılmadan önce ve tam bir kez; sonuç ağacı `SaveManager` yazma çağrısı içermez
(kaynak taraması + byte kontrolü testte).

### 20.7 A36 cihaz kapısı (M8.6-09.1, 2026-09-18, c3c6a0d)

Samsung SM-A366B, Android 16 (SDK 36), native 1080×2340 (density 450, cutout
92 px, 3 tuşlu gezinme çubuğu 135 px, 120 Hz). Owner masaüstü incelemesini
onayladıktan sonra koşuldu; **cihaza özel kusur çıkmadı, runtime dosyası
değişmedi**. Debug APK c3c6a0d ağacından: 45 620 684 B, 787 girdi, sızıntı 0
(build/tools/_visual_source/docs/md/py/zip/sh/kayıt/logcat/contact sheet);
`round_result / result_reward_card / result_star_strip / reward_gem /
chest_reward / skin_*` ve `show_result / _run_reveal / set_stars / note /
is_finished / RESULT_DELAY / hero` sembolleri paketlenmiş bytecode'da, emekli
`CandyButton / UiPalette / style_cta` sonuç bytecode'unda yok.

Owner kaydı (670 B) yalnız açılış + Ana Sayfa/Harita görsel geçişinde
kullanıldı (açılış oyunun kendi kanonik günlük yolunu koştu, AL basılmadı,
round oynanmadı); bütün sonuç/ödül/ilerleme testleri geçici kayıtlarda ya da
**ayrı paketteki** (`com.example.squishymerge.qa`, kendi user-data dizini)
`tools/result_device.tscn` sürücüsünde koştu. Sonda owner kaydı byte-identical
geri kondu (`cmp` aynı), uygulama bir daha açılmadı, QA paketi kaldırıldı.

Native bulgular:

* **Güvenli alan:** krem panel üst kenarı en dar durumda cutout'un 167 px
  altında; alt kenar gerçekçi tavanda (5 ödül) nav bölgesinin 73 px, yalnız
  harness'a özgü 6 ödül stresinde 9 px üstünde — çakışma yok (yükseklik
  tavanı devreye girip gövdeyi kaydırılabilir yapıyor).
* **HUD sızması (eski kusur) kapandı:** sonuç açıkken HUD parlaklığı %31'e
  düşüyor (skor plakası 154.6 → 47.4), krem gövde tamamen opak — içinden
  yazı okunmuyor.
* **Yıldızlar:** cihazda ölçülen görünürlük 305 / 517 / 718 ms → **≈207 ms
  arayla** (hedeflenen 0.2 s), titreme/çift pop yok, son konumlar sabit.
* **Kartlar:** dört Hamur rarity'si ve dört skin kartı 450 dpi'da net; skin
  sanatı büyük ve keskin, YENİ SKİN rozeti baskın, "Koleksiyon'a eklendi"
  ikincil; EFSANEVİ kart altın, soluk değil; geri düşüş kartı skin iddia
  etmiyor.
* **Kaydırma:** 5 ödül (gerçekçi tavan) cihazda kaydırma bile gerektirmiyor;
  6 ödül stresinde kart üstünden başlayan yavaş sürükleme, hızlı fling, ters
  yön ve iki limite tekrar kaydırma sorunsuz (0 ↔ 130), altlık sabit, kart
  sürüklemeyi yutmuyor, ödül mutasyonu yok.
* **İki izleme maddesi ölçüldü, değişiklik yapılmadı:** (1) kaydırmada üst
  kenar kırpması — durağan hâlde kartlar tam oturuyor, parmak basılıyken kesim
  ayırıcı çizginin hemen altında temiz; (2) reveal öncesi boş krem gövde —
  1 ödülde hiç yok (panel büyüyor), 3 ödüllü 3 yıldızlı kazanmada ~0.15 → 1.28 s
  (yıldızlar bu sırada pop'luyor), Sonsuz'da ~0.12 → 0.60 s; panel yüksekliği
  zıplamıyor, kartlar patlama + sesle sırayla doluyor. Zaman çizelgesi kanıtı:
  `build/qa_m8.6-09/device/contact_device_reveal_timeline_3.jpg` / `_5.jpg`.
* **İlerleme:** gerçek dokunuşla oynanan Level 1 kazanması tam bir kez yazdı
  (Hamur 100 → 110, kilit 1 → 2, yıldız {} → {"1": 3}); gerçek taşma → Devam
  teklifi → BİTİR yolunda teselli +5 bir kez; sonuç açıkken ikinci `_finish`
  ve ikinci `show_result` kopya pencere/kart/ödül üretmedi (kayıt sha256 aynı).
* **Rotalar:** Android geri sonuçta yok sayıldı (kare farkı 0 px), kart
  dokunuşu/sürüklemesi sunum-only, HARİTA tek geçiş + harita açılış
  animasyonu, TEKRAR DENE/TEKRAR OYNA aynı level'ı yeniden başlattı (ek yazım
  yok), RESULT_DELAY aralığında mola açılmadı (kontrol: canlı board'da aynı
  dokunuş molayı açıyor), Devam → Sonuç sırasında sonuç parlaması yok.
* **Performans:** reveal sırasında ortalama kare 8.8–12.2 ms, 25 ms üstü kare
  13 durumun 11'inde 0 (kalan ikisinde birer kare), SkinSwatch kaynaklı takılma
  yok; 15 s boşta düğüm 3023 → 3023, FX 0, PSS 389.5 → 386.4 MB. Logcat
  (206 506 satır): 0 SCRIPT ERROR / 0 E godot / 0 eksik res:// / 0 shader / 0
  FATAL / 0 ANR / 0 tombstone.

Kanıt ve sürücüler: `build/qa_m8.6-09/device/` (`DEVICE_GATE_NOTES.md`, 01–25
kare + X_/N_/R_ ek kareler, 9 contact sheet, `apk_leak_check.txt`,
`export_log.txt`, `logcat_gate.txt`, kayıt yedeği/geri koyma kanıtı,
`dev.sh` / `qa.sh` / `drive.sh` / `play_l1.py` / `pause_race.py`).

### 20.8 Şimdilik yapılmayan

GAME_DESIGN §5.1 "~400 ms" yıldız notu owner brief'iyle 0.2 s'ye çekildi —
doküman güncellemesi owner onayına bırakıldı (cihazda ölçülen 207 ms).
Harness notu (runtime kusuru değil): `RoundResult._clear_cards()` `_rewards`
dizisini de temizlediği için, `show_result`'a sonucun **kendi** `_rewards`
dizisi geri verilirse kart kalmaz; üretim yolunda `Main` her zaman
`_collect_rewards`'tan taze dizi veriyor.

---

## 21. Production Devam (revive) + stok 0 Refill (M8.6-10) — DEVICE VERIFIED (A36, 40bab45)

**Kod:** `scripts/ui/revive_offer.gd` + `scenes/ui/revive_offer.tscn` (katman 11),
`scripts/ui/power_refill.gd` + `scenes/ui/power_refill.tscn` (katman 11),
`scripts/ui/ui_kit.gd` (`cta` metaları `subtitle_label` / `picto` +
`set_cta_enabled`), `scripts/main.gd` (`_revive_provider_ready`, `show_offer`'a
sağlayıcı durumu, Android geri: Refill = Kapat), `tools/make_revive_art.py` →
`assets/visual/ui/icon_heart_revive.png` (owner kanatlı-kalp tepeliğinden
izole kalp; yeni sanat değil). **Test:** `tools/revive_refill_ui_test.tscn` (266).
**Çekim:** `tools/revive_refill_shots.tscn -- <dir> [GxY] [safe=61] [only=01,08]`
→ `build/qa_m8.6-10/` (before = M8.6-07 denetim harness'ı ile 15 durum × 5
yapılandırma; after/final 17 durum × 5; contact sheet'ler; QA_NOTES).
Tema **değişmedi** (yeni variation yok); `modal_shell` **değişmedi**.

**Neydi (M8.6-07 denetimi, `build/qa_m8.6-10/before/`):** ikisi de M8.5-08
candy paneli (`panel_candy.png` 600×650/770'e gerilmiş, Refill'de %34 dikey
gerilme) + mavi yıldızlı `CandyButton` pill'leri: Devam'da "Bitir" ile "DEVAM
ET" aynı pill (talep sırasında hiyerarşi tersine dönüyordu), Refill'de üç aynı
CTA, 88 px güç ikonu, sağlayıcı yokken DEVAM ET aktif görünüp basınca "bağlı
değil" diyordu, Android geri Refill'de yok sayılıyordu (tek boşluk).

### 21.1 Devam — kompozisyon

`modal_shell("DEVAM ETMEK İSTER MİSİN?", 560, heading, topper=true,
closable=false)`: X YOK, karartma (α .62, STOP) dokunuşu KAPATMAZ, Android geri
yok sayılır — karar penceresi, çıkış yalnız iki CTA'dan. Tepelik = owner kanatlı
kalp (duygusal katman; Kazanma sonucundan daha güçlü değil: kontur/altın yok,
tepelik 1.0×). Hero (sabit): Baloo 30 başlık (tek satır, testle) → `LabelBody`
19 `TEXT_SECONDARY` "Taşan parçaları temizle, kaldığın yerden devam et." →
**DEVAM HAKKI plakası** (`label_round` `CREAM_DEEP` + lavanta kontur + arkasında
pembe α .16 hale): "DEVAM HAKKI" 13 → iki kalp 84 px (`icon_heart_revive`;
kalan = renkli, kullanılmış = `Color(.62,.58,.72,.42)` soluk lavanta) → "2 / 2"
`LabelStat` 22. Kalp sayısı = `GameBoard.max_revives()` (2); sahte üçüncü yuva
yok; açılışta kalan kalpler 1.14 pop (tek seferlik). Altlık (sabit):
`UiKit.cta("DEVAM ET", "Reklam izle", ButtonCTA, "movie")` → durum notu →
`ButtonSecondary` "BİTİR".

| durum | DEVAM ET | not |
|---|---|---|
| A/B hak var + sağlayıcı bağlı (test çifti) | cyan aktif | — |
| D sağlayıcı yok (bugünkü production) | **pasif** (DISABLED gövde, TEXT_DISABLED yazı) | "Ödüllü reklam henüz bağlı değil." (uyarı) |
| E talep gönderildi | pasif (kilitli) | "Reklam isteniyor…" (sakin) |
| sağlayıcı "olmadı" | bağlıysa yeniden aktif (tekrar dene); değilse pasif | sağlayıcı mesajı |
| C hak yok (0/2, savunma — runtime açmaz) | pasif | "Bu turdaki devam hakkın bitti." |

`show_offer(remaining, max_revives, provider_ready)` — Main
`_revive_provider_ready()` (sağlayıcı bağlı ve `show_rewarded_revive` var)
verir. Talep yalnız `provider_ready and remaining > 0 and not pending` iken
yayılır (çift dokunuş / çift talep yok). Devam **yalnız** sağlayıcının ödül
callback'i → `Main.grant_revive` → `GameBoard.grant_revive` ile; pencere o
anda kapanır (board aynı karede çözülür; ayrı "başarı geçişi" bilerek yok —
oyun süresi yenmesin). Pencere kayda/ekonomiye dokunmaz (kaynak taraması).

### 21.2 Refill — kompozisyon

`modal_shell("STOK BİTTİ", 560, ribbon, topper=false, closable=true)`: oturmuş
X, karartma bırakışı KAPATIR (diğer terminal olmayan pencereler gibi), KAPAT
altlıkta, **Android geri = Kapat** (M8.6-07'nin tek boşluğu; kanıt: bütün
terminal olmayan pencereler geri ile kapanıyor, Kapat yolu hiçbir şey
tüketmiyor — `Main._on_refill_closed` → `exit_refill_pending(false)`;
regresyon testi). Hero (sabit): `candy_well(güç sanatı, güç vurgu rengi, 156,
112)` (Mağaza onayının sunumundan büyük — pencerenin konusu bu güç; dört güçte
gerçek sanat, generic refill ikonu yok) → güç adı Baloo 28 → `LockBadge`
"STOK ×0". Gövde (kaydırılan): iki **ayrı kimlikli** seçenek kartı
(`card_bevel_soft` `CREAM_DEEP` + `frame_round20` lavanta halka; sol üstte
küçük kuyu 60/38, Baloo 20 başlık + "+1 Bomba" satırı, durum satırı, gerekirse
sebep notu, tam genişlik 58 px buton):

| kart | kuyu | durum satırı | buton |
|---|---|---|---|
| ÖDÜLLÜ REKLAM | koyu lavanta + beyaz `movie` pictosu | "Bugünkü hakkın: 1/1" (nane; 0/1 uyarı) | `ButtonPrimary` cyan "REKLAM İZLE" + film |
| HAMURLA AL | altın + owner Hamur sanatı | Hamur 24 + `LabelPrice` 22 "120 Hamur" · sağda "Bakiyen: 335" | `ButtonPurchase` nane "SATIN AL" |

Pasif seçenek = pasif buton + kartın içinde kısa sebep: "Ödüllü reklam henüz
bağlı değil." / "Bugünkü reklam hakkın doldu, yarın yenilenir." / "Reklam
isteniyor…" / "Hamur yetersiz (10 Hamur'un var)." (bakiye de uyarı rengine
döner). Sessiz başarısızlık yok. Altlık: sağlayıcı/işlem notu (Main'in
`show_unavailable` mesajı) + `ButtonSecondary` KAPAT. Fiyat
`PowerUpEconomy.price()` (100 / 120 / 160 / 180 — testle kilitli, UI'da sayı
yok), kota `RewardedPolicy` (günde 1, **dört gücün toplamı**: Bomba'ya ödül →
Büyütücü/Sarsıntı/Temizleyici 0/1, testle). Güç Paketi seam'i
(`power_pack_requested`) bağlı değil, butonu yok (billing yok).

**İşlem sınırı (değişmedi):** REKLAM İZLE → `rewarded_refill_requested` →
Main token'lı talep → sağlayıcı → `Main.grant_rewarded_power(type, token)` →
`RewardedPolicy.grant` (tek transaction). SATIN AL → `dough_refill_requested`
→ `PowerUpEconomy.purchase` (tek transaction) → `_finish_refill` (kapanış +
niyet geri dönüşü: hedefli güçte hedefleme yeniden açılır). Pencere stok
vermez, Hamur düşmez, kota tüketmez, kayda yazmaz. Çift basış: reklam butonu
cevap gelene kadar kilitli; SATIN AL tek sinyal (`_purchase_sent`, Main
cevaplayınca sıfırlanır). Talep / sağlayıcı hatası / kapanış / geri kota
tüketmez ve yazmaz (byte kontrolü).

### 21.3 Responsive

720×1280 / 720×1560 / 540×960 / 1080×2340 / A36 (720×1560 + safe 61): iki
pencerede çerçeve + tepelik/kurdele ekranda ve güvenli payın altında, altlık
çerçevede, CTA'lar ekranda, başlık tek satır, güç sanatı ≥ 96 px görünür, iki
kart çerçevede (1280 tuvalde kaydırma gerekmiyor; refill doğal yükseklik ≈
900 px). Devam ≈ 560 px.

### 21.4 Performans

Düğüm: Devam 37, Refill 83 (ağaç, CanvasLayer dahil). Sürekli tween yok
(kalp pop / pencere açılışı tek seferlik; dinlenmede 0 çalışan tween, testle).
Parçacık yok. `_process` yok.

### 21.5 Sıra, geri tuşu, güvenlik

fail → Devam → BİTİR / hak yok → `round_finished(false)` tam bir kez → 0.8 s →
Sonuç (KAYIP); teklif aynı karede kapanır, sonuç teklifin altında hiç
görünmez (testle). Hak bitince (2 devam) teklif AÇILMAZ (3. devam yok).
Android geri: Devam açıkken yok sayılır (mola/çıkış/sonuç atlama yok);
Refill açıkken Kapat; Refill kapalıyken oyun içi mola (değişmedi). Refill
açıkken mola açılmaz, ikinci güç isteği yok sayılır, stoklu güç silahlanmaz,
board donuk; fail-pending'de refill açılmaz.

### 21.6 Eski M8.5 kabuğunun emekliliği

Runtime tüketicisi kalmadığı kanıtlanıp (production `scripts/` + `scenes/`
taraması, testle) **silindi:** `scripts/ui/candy_button.gd` (`CandyButton`),
`scripts/ui/ui_palette.gd` (`UiPalette`), `assets/visual/ui/panel_candy.png`,
`cta_button_normal/disabled.png`, `power_button_normal/selected/disabled.png`
(hepsi yalnız `CandyButton`/`UiPalette` okuyordu), `assets/visual/ui/icons/`
(14 Free Casual GUI türevi; tek tüketici `UiPalette`) ve türetme aracı
`tools/make_pack_icons.gd`; `tools/make_gameplay_art.py` candy pill üretimini,
`tools/make_owner_sprites.gd` `panel_candy` kırpımını bıraktı (CREDITS.md
güncel). **Kalanlar (bilerek):** `panel_candy_crown.png` (modal tepeliği),
`UiType` (`game_board.gd` "+N" uçan skor etiketi `UiType.CARD_TITLE` — gameplay
görseline dokunulmadı), `UiIcons` (Home pill'leri / SkinSwatch kilidi),
`ui_theme.tres` içindeki M8.5 rolleri (`Display` / `Stat` / `Caption` /
`SecondaryButton` / `ModalPanel` …: `make_ui_theme.gd` GENERATED listesinde
değil, temayı yeniden üretmeden silinemez — production kullanıcısı yalnız
`UiType.CARD_TITLE`; ayrı bir tema temizliği adayı), M7 dönemi ölü owner
asset'leri (`banner_new`, `ui_button_*`, `ui_panel`, `ui_star_*` — bu
milestone'un konusu değil, owner kararı).

### 21.7 A36 cihaz kapısı (M8.6-10.1, 2026-09-19, 40bab45)

Samsung SM-A366B / Android 16 / native 1080×2340 (yoğunluk 450, cutout 92 px, nav 135 px,
120 Hz). Debug APK `40bab45` ağacından (44 800 970 B, 743 girdi — M8.6-09'un 45 620 684 /
787'sinden küçük: emekli asset'ler gitti), sızıntı 0; APK'da `candy_button` / `ui_palette` /
`panel_candy.png` / `cta_button_*` / `power_button_*` / `ui/icons/` YOK, `revive_offer` /
`power_refill` / tepelik / `icon_heart_revive` / dört güç sanatı / `movie` pictosu / politika +
ekonomi + kayıt sembolleri VAR. **Runtime değişmedi; cihaza özel kusur YOK.** Owner kaydı
(671 B, md5 `942aa5c3…`) gate boyunca hiç yüklenmedi — bütün üretim paketi testleri geçici
kayıtlarla (`run-as cp`), sonunda pre-gate byte'lar geri kondu (on-device md5/sha256/stat +
read-back cmp aynı), uygulama force-stop'ta bırakıldı; telefon gate ortasında kendi kendine
kilitlendi ve **açılması beklendi** (hiç uyandırılmadı / kilidi açılmadı). Logcat 0 SCRIPT
ERROR / 0 E godot / 0 missing res / 0 shader / 0 FATAL / 0 ANR / 0 tombstone.

- **Devam (native):** panel 742–1597 px, tepelik cutout'un 557 px altında, alt kenar nav
  bölgesinin 608 px üstünde; 2/2 ↔ 1/2 kalpleri anında ayrışıyor, sağlayıcısız DEVAM ET gri
  gövde + koyu yazı + turuncu sebep (kırık doku gibi değil), BİTİR lavanta. Sağlayıcısız:
  pasif CTA'ya iki gerçek dokunuş + karartma dokunuşu + karartma altındaki HUD geri / güç
  slotu dokunuşları + Android geri ×3 → pencere bölgesi **piksel piksel aynı**, 0 talep,
  fail-pending sürüyor, mola/sonuç yok, kayıt aynı. Test sağlayıcısıyla: çift + tekrar
  dokunuş → **1** talep; callback bir kez → devam #1 (sayaç 1), ikinci callback `false`;
  1/2 → #2; hak bitince taşma teklif AÇMAZ (3. devam yok). Sağlayıcı hatası → tekrar dene.
  Basıp sürükleyerek bırakma → takılı ölçek yok. **Gerçek taşma → teklif → gerçek BİTİR
  basışı:** uygulama içi zaman çizelgesi (50 ms): teklif kapanır + round biter aynı örnekte,
  **836 ms** boyunca ne teklif ne sonuç, sonra sonuç (KAYIP, teselli +5 tam bir kez,
  `round_finished` 1); hızlı üçlü BİTİR de tek bitiş. 15 s dinlenme: düğüm/bellek sabit,
  tween 0, PSS 337 → 334 MB.
- **Refill (native):** panel 507–1831 px, kurdele + X 468 px'te (cutout'un 376 px altında),
  alt kenar nav bölgesinin **374 px** üstünde, iki kart tam görünür, **kaydırma yok**. Dört
  kahraman doğru sanat/renk/ad/fiyat (120/180/100/160). Ödüllü ↔ Hamur kartları ilk bakışta
  ayrı. Sağlayıcısız: REKLAM İZLE pasif + sebep, kota 1/1 dürüst, dokunuş 0 talep. **Satın
  alma (gerçek basış):** Bomba 500 → 380 / stok 1 (basılı kare + kapanış + slot ×1 + hedefleme
  geri), Büyütücü hızlı üçlü dokunuş 380 → 200 / stok 1 (tek işlem), Temizleyici 200 → 40 /
  yalnız clear_small +1 (yanlış güç yok), Sarsıntı tam 100 → 0. Yetersiz (10): SATIN AL pasif +
  sebep, üçlü dokunuş kayıt sha aynı. **Ödüllü (test sağlayıcı):** çift dokunuş → 1 talep,
  callback → Bomba +1, kota 1/1 → 0/1; Büyütücü / Sarsıntı / Temizleyici üçü de **0/1 +
  pasif** (dört gücün toplamı); kopya callback `false`; sağlayıcı hatası kota tüketmez, CTA
  yeniden açılır, geç callback `false`; **bekleyen talep + Android geri** → pencere kapanır,
  token iptal, geç callback `false`, stok/kota aynı. **Kapanış:** geri / X / KAPAT / karartma
  bırakışı → kayıt sha aynı, board sürer, mola açılmaz; Refill kapalıyken geri → Mola
  (değişmedi). Stok 0 gerçek slot dokunuşu dört güçte doğru pencereyi açar; Refill açıkken
  stoklu slota dokunuş pencereyi kapatır ama gücü **silahlamaz** (kontrol: canlı board'da aynı
  dokunuş silahlar). 15 s dinlenme: düğüm/bellek sabit, tween 0, PSS 341 → 336 MB.
- **Üretim paketi (geçici kayıt, gerçek build):** Level 4'te stok 0 Bomba slotu → Refill
  (sağlayıcı yok, 120 / 500) → pasif reklam dokunuşları etkisiz → geri kapatır (yazma yok) →
  SATIN AL → cihaz kaydı **380 / bomb 1** (tek yazma) → Sarsıntı stok 0 → KAPAT (byte aynı).
  Level 10 hızlı orta dokunuşlarla **gerçek taşma → gerçek Devam** → pasif CTA + karartma +
  geri ×3 etkisiz → BİTİR: +0.4 s "Bitti" board'u, sonuç yok; ~1.3 s sonuç (teselli +5, kayıt
  405 → 410, merge'ler bir kez). 10 Hamur kaydında yetersiz durum gerçek build'de de aynı.
  Kanıt: `build/qa_m8.6-10/device/` (`DEVICE_GATE_NOTES.md`, 55 kare, 7 contact sheet,
  logcat, kayıt kanıtları).

### 21.8 Şimdilik yapılmayan

Devam'da "başarı geçişi" (kalp pop / nane flaş) yok: kanonik `grant_revive`
board'u aynı karede çözüyor, pencere beklerse oyun süresi yenir. Refill talebi
açıkken KAPAT / geri hâlâ açık (M8.5-06 davranışı korundu): gerçek sağlayıcı
bağlanınca "reklam yüklenirken kapatma → token iptali → izlenen reklam ödülsüz"
riski sağlayıcı entegrasyonunda ele alınmalı (sağlayıcı iptalde reklamı
göstermemeli ya da KAPAT bekleme sırasında kilitlenmeli — owner kararı).
