# UI_VISUAL_SYSTEM.md — Squishy Merge production UI sistemi

**Durum:** M8.6-01 ile kuruldu, **kaynak dokümandır** — M8.6-02+ ekran işleri buna uyar.
**Kod kaynağı:** `scripts/ui/ui_tokens.gd` (sayılar) → `tools/make_ui_theme.gd`
(`assets/visual/ui_theme.tres` üretir) → `scripts/ui/ui_kit.gd` (bileşenler).
**Asset kaynağı:** `tools/make_ui_core.py` → `assets/visual/ui/core/**` +
`scripts/ui/ui_core_assets.gd` (üretilir, elle düzenlenmez).
**Galeri:** `tools/ui_system_gallery.tscn` (dev-only, 5 sayfa).
**Test:** `tools/ui_foundation_test.tscn` (164 kontrol), `tools/gameplay_shell_test.tscn` (147, §13), `tools/home_ui_test.tscn` (207, §14), `tools/map_ui_test.tscn` (127, §15), `tools/shop_ui_test.tscn` (212, §16), `tools/collection_ui_test.tscn` (164, §17).

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

Eski dev neon-mavi pill (`Button` varsayılanı, `CandyButton.CTA_*`) M8.5
ekranlarında duruyor; **yeni ekranlarda kullanılmaz**, her yerde aynı
`ButtonCTA`/`ButtonPrimary` ailesi.

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
production ekranlarda hâlâ bağlı; M8.6 ekran işlerinde aynı roller picto
setine geçirilir, sonra eski klasör kaldırılır.

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
bunu yazar (Koleksiyon + Mağaza kartı + Mağaza onayı). İç ad `rarity_name`
(Common…) variation kimliği ve id öneki olarak DEĞİŞMEDİ. Sonuç ekranı sandık
başlığı (`ChestReward.title`) hâlâ İngilizce — result/reward işinde.

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
