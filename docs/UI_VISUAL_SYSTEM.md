# UI_VISUAL_SYSTEM.md — Squishy Merge production UI sistemi

**Durum:** M8.6-01 ile kuruldu, **kaynak dokümandır** — M8.6-02+ ekran işleri buna uyar.
**Kod kaynağı:** `scripts/ui/ui_tokens.gd` (sayılar) → `tools/make_ui_theme.gd`
(`assets/visual/ui_theme.tres` üretir) → `scripts/ui/ui_kit.gd` (bileşenler).
**Asset kaynağı:** `tools/make_ui_core.py` → `assets/visual/ui/core/**` +
`scripts/ui/ui_core_assets.gd` (üretilir, elle düzenlenmez).
**Galeri:** `tools/ui_system_gallery.tscn` (dev-only, 5 sayfa).
**Test:** `tools/ui_foundation_test.tscn` (135 kontrol), `tools/gameplay_shell_test.tscn` (125, §13).

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
| Birincil CTA | `CYAN` / `CYAN_DEEP` | `#5eddf9` / `#2f8fd0` | ButtonPrimary, ButtonCTA, SectionTag |
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
| HUD skor / HUD başlık | Nunito Bold | 30 / 13 | `LabelHudScore` (gölgeli) / `LabelHudCaption` (beyaz %62) — M8.6-02 |
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
| `PowerSlot` / `PowerSlotArmed` / `PowerSlotEmpty` | `btn_circle` (84×88 madalyon) | krem / cyan / pasif gri | gameplay güç slotu — `UiKit.power_slot`, §13.4 |

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
sistemi YOK.

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

**Etiketler:** `HeaderRibbon` (`header_ribbon`, pembe; lavanta/altın `tint`
ile — beyaza indirgenmiş LayerLab kurdelesi), `SectionTag` (`label_trapezoid`,
cyan varsayılan; pembe/nane/altın).

**Rarity:** `RarityCommon/Rare/Epic/Legendary` = trapez etiket (Common %12
koyulaştırılır ki kremde okunsun), `RarityFrameCommon/…/Legendary` = `item_frame`
rarity renginde skin önizleme çerçevesi. Legendary ödülde ek `GLOW_PREMIUM`
(`item_focus`). Tonlar `SkinData.rarity_color` ile birebir (test).

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
card_large (CardFrame08), card_bevel (CardFrame03), card_flat/border
(CardFrame01), list_row, item_frame(+inner), item_circle(+inner), item_focus,
border_round(+thin), frame_round12/20 ·
`buttons/` btn_cta/large/normal/compact (Button01 175/145), btn_bevel(+light),
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
`_draw*` (kap kabuğu). **Test:** `tools/gameplay_shell_test.tscn` (125 kontrol).
**Çekim:** `tools/shell_shots.tscn -- <dir> [GxY]` (10 durum × 4 boyut).

### 13.1 Bölge sözleşmesi (responsive)

720 px tuval, yükseklik serbest (16:9 → 1280, 19.5:9 → 1560; 540×960 aynı
kompozisyonun 0.75'i, 1080×2340 1560'ın 1.5'i). Dikeyde dört bölge:

| Bölge | Yükseklik | İçerik |
|---|---|---|
| **HUD** | sabit: `max(SAFE_TOP 10, cihaz üst güvenli pay + 4) + ROW1 62 + 8 + ROW2 92` = 172 (A36 punch-hole: 92 px fiziksel = 61 tuval px → 227) | satır 1: Ayarlar · Skor · Sıradaki; satır 2: 2 güç · Hedef · 2 güç |
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

### 13.3 HUD hiyerarşisi

1. **Skor** — `PanelHud` (erik bevel, dar pay) + owner yıldızı + `LabelHudCaption`
   "SKOR" + `LabelHudScore` (Nunito Bold 30, binlik boşluklu). Ortada, en
   üstte. "+N" pop'u plakanın sağ kenarından çıkar (`score_pop_home`), 16 px
   yükselip söner (altın, rozetsiz; Sıradaki'ye değmez).
2. **Hedef** — `PanelHud`: `Badge` (taç + level no; sonsuzda "SONSUZ") +
   sütun: `LabelHudCaption` "HEDEF" (sonsuzda "REKOR") → hedef tier'ın
   **gerçek dokusu** + adı (`LabelBodyOnDark`, taşarsa …) → `ProgressBarMint`
   16 px; skor hedefi çubuğun sağ ucunda `LabelHudCaption`.
   İlerleme = ulaşılan tier / hedef tier (skor hedefi varsa ikisinin ort.);
   sonsuzda skor / rekor.
3. **Sıradaki** — `PanelElevated` (krem, 138×58) + "SIRADAKI" `LabelCaption` +
   tier dokusu 40 px. Sağ üst; Ayarlar ile aynı yükseklik (satır 1 dengesi).
4. **Ayarlar** — `ButtonIcon` 58. Sol üst. Açılınca board `set_menu_paused`
   ile donar (fail/refill makinesi), kapanınca çözülür.
5. Üst karartma: 178+56 px yumuşak gradyan (`GameplayHud.scrim`) — opak plaka
   değil.

### 13.4 Güç slotu anatomisi (`UiKit.power_slot`)

84×88 `Button` **madalyon**: gövde `btn_circle` (3B basılabilir daire),
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

### 13.8 Gelecek banner seam'i

`GameplayHud.banner_seam` (görünmez Control) = `layout["banner"]`; yüksekliği
`GameplayLayout.banner_height()`. v1: 0. AdMob bağlandığında sağlayıcı
`GameplayLayout.set_banner_height(px)` çağırır ve board `_apply_layout`
yeniden koşar; kontroller seam'e giremez (test kilitli).
