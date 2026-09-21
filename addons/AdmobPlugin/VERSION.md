# AdmobPlugin — pinned release (M8.9-01)

Third-party Godot Android plugin, installed **as released**, no source edits.

| | |
|---|---|
| Project | https://github.com/godot-sdk-integrations/godot-admob |
| Release | **v6.0** — "Admob Plugin v6.0", published 2026-02-01 |
| Tag commit | `90e3c616ea3c680e3875c31e6bcccffbebbe9d3b` ("Upgraded to Godot 4.6 (#89)") |
| Asset | `AdmobPlugin-Android-v6.0.zip` (256 591 B) |
| Asset SHA-256 | `9ec2600238f53104fcf9f21b9e8dec1525880af0d40f7a66878022aa05973f24` |
| `bin/debug/AdmobPlugin-debug.aar` SHA-256 | `388243802894363133814f9f8c0c9be61adc27b5911c11460483768700f6be63` |
| `bin/release/AdmobPlugin-release.aar` SHA-256 | `526516f93b1e29a6749b0293d86649bb7a6971603258a62e109dfd65afb36789` |
| Licence | MIT (see `LICENSE` next to this file) |
| Built against | `godot-lib 4.6.stable` (plugin `config.properties`: `godotVersion=4.6`, `godotReleaseType=stable`) |
| Google Mobile Ads SDK | `com.google.android.gms:play-services-ads:24.9.0` (added at export by `AdmobPlugin.gd` → `ANDROID_DEPENDENCIES`) |
| UMP SDK | `com.google.android.ump:user-messaging-platform:3.2.0` (transitive via `play-services-ads-api:24.9.0`) |
| Android | AAR `minSdkVersion 24`; plugin build `compileSdk 35`, `buildTools 35.0.0` |
| Plugin API | Godot Android plugin **v2** (`org.godotengine.plugin.v2.AdmobPlugin` meta-data) |

Why v6.0 and not v7.0 (2026-05-27): v7.0 is built against **Godot 4.7 beta1**
(`godot.properties`: `godotVersion=4.7`, `godotReleaseType=beta1`) and the
maintainer states in issue #122 that "v7.0 requires Godot 4.7+ … for Godot 4.6.x
use v6.0". This project is pinned to Godot **4.6.3** (CLAUDE.md).

Google SDK 24.x support window (developers.google.com/admob/android/deprecation,
read 2026-09-21): *Supported*; deprecation 2027-06-30, sunset 2028-06-30.

Upgrading: replace this folder with the newer release zip contents, re-add
`LICENSE`, update this file, keep `android_export.cfg` (project configuration,
not part of the release). Full notes: `docs/monetization/ADS_SYSTEM.md`.
