# assets/audio — ses asset'leri ve kaynakları

Runtime yalnızca `sfx/**` altını okur; eşleme `AudioManager.EVENTS`
(`scripts/autoload/audio_manager.gd`). Durum ve ölçümler:
`docs/AUDIO_AUDIT.md`. Eksik final örneklerin şartnamesi:
`docs/AUDIO_ASSET_REQUIREMENTS.md`.

## Klasörler

```
sfx/ui/        buton, sekme, pencere, hata, anahtar, seçim
sfx/gameplay/  bırakma, iniş, merge, tehlike, taşma, round sonu, devam
sfx/powers/    bomba, büyütücü, sarsıntı, temizleyici
sfx/rewards/   parıltı, ödül çanı, sandık, kazanma jingle'ı
```

## Kenney.nl — CC0 (Creative Commons Zero)

Ticari kullanım serbest, atıf zorunlu değil. Paketler:
Impact Sounds — https://kenney.nl/assets/impact-sounds ·
Interface Sounds — https://kenney.nl/assets/interface-sounds ·
Music Jingles — https://kenney.nl/assets/music-jingles

| dosya | kaynak | kullanım |
|---|---|---|
| `sfx/gameplay/kenney_impact_soft_01.ogg` | Impact Sounds `impactSoft_medium_000.ogg` | iniş (`land`), merge pes gövde katmanı (`merge_body`), bomba gövdesi |
| `sfx/ui/kenney_pluck_01.ogg` | Interface Sounds `pluck_001.ogg` | yıldız reveal, anahtar açma, kart seçme, güç silahlanma (tabloda −8…−14 dB: ham tepe +0.4 dBFS) |
| `sfx/rewards/kenney_open_01.ogg` | Interface Sounds `open_001.ogg` | sandık açılış aşaması |
| `sfx/rewards/kenney_jingle_win_01.ogg` | Music Jingles `jingles_PIZZI07.ogg` | round kazanma |
| `sfx/gameplay/kenney_jingle_lose_01.ogg` | Music Jingles `jingles_PIZZI16.ogg` | round kaybı |

M8.5-15'te kaldırılanlar (Digital Audio paketi, candy tona aykırı, Kenney'den
yeniden indirilebilir): `sfx_danger.ogg` (`lowDown.ogg`), `sfx_combo.ogg`
(`pepSound1.ogg`).

## Sentez (bu repo, `tools/make_sfx.gd`) — GEÇİCİ

`sfx_*.wav` dosyaları (22 adet) sabit tohumlu, deterministik sentezle
üretildi (saf sinüs / süzülmüş gürültü). Lisans sorunu yok (kendi
üretimimiz). **Final değil:** kulakla doğrulanmadılar; owner final örnekleri
aynı adla üzerine yazacak (bkz. `docs/AUDIO_ASSET_REQUIREMENTS.md`).
Yeniden üretmek için:

```
godot --headless --path . --script res://tools/make_sfx.gd
godot --headless --editor --quit --path .
```

## Değiştirirken

Dosya **adlarını koru**; aynı adla üzerine yaz, Godot'ta bir kez import et.
Yeni varyant: `AudioManager.EVENTS[<olay>]["streams"]` listesine yol ekle.
Ölçüm: `godot --headless --audio-driver Dummy --path . --script res://tools/audio_probe.gd`.
