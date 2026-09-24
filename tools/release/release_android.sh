#!/usr/bin/env bash
# Squishy Merge — Android release pipeline (M9-01). Repo kökünden, Git Bash / Linux:
#
#   tools/release/release_android.sh check                 release kapısı raporu (export YOK)
#   tools/release/release_android.sh debug-apk             TEST reklamlı debug APK + tarama
#   tools/release/release_android.sh aab                   Play'e yüklenebilir AAB — kapı engel
#                                                          görürse REDDEDER (export çalışmaz)
#   tools/release/release_android.sh non-publishable-aab   İMZASIZ, NOT_FOR_UPLOAD işaretli,
#                                                          release biçimli AAB (yalnız pipeline
#                                                          doğrulaması — Play'e YÜKLENEMEZ)
#
# Presetler YEREL export_presets.cfg'de (gitignore'lu; kurulum:
# docs/ANDROID_RELEASE_CHECKLIST.md): "Android" (debug), "Android Release AAB"
# (imzalı), "Android AAB NOT FOR UPLOAD" (imzasız). Upload anahtarı YALNIZ ortam
# değişkenleriyle verilir, hiçbir dosyaya yazılmaz:
#   GODOT_ANDROID_KEYSTORE_RELEASE_PATH / _USER / _PASSWORD
# Tek kaynaklar: project.godot [squishy] + application/config/version,
# addons/AdmobPlugin/android_export.cfg. Kapı: tools/release/release_readiness.gd.
set -euo pipefail

MODE="${1:-check}"
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO"
GODOT="${SQUISHY_GODOT:-C:/Users/ledaj/AppData/Local/Godot463/Godot_v4.6.3-stable_win64_console.exe}"
SDK="${SQUISHY_ANDROID_SDK:-${ANDROID_HOME:-$LOCALAPPDATA/Android/Sdk}}"
PY="${PYTHON:-$(command -v python3 || command -v python)}"
OUT="$REPO/build/release"
mkdir -p "$OUT"

DEBUG_PRESET="Android"
RELEASE_PRESET="Android Release AAB"
NP_PRESET="Android AAB NOT FOR UPLOAD"
VERSION_NAME="$(grep -m1 '^config/version=' project.godot | sed 's/^[^"]*"//; s/"$//')"
VERSION_CODE="$(grep -m1 '^release/android_version_code=' project.godot | cut -d= -f2)"
TAG="${VERSION_NAME}_vc${VERSION_CODE}"

say() { printf '[release] %s\n' "$*"; }
die() { printf '[release] ERROR: %s\n' "$*" >&2; exit 1; }

"$GODOT" --version 2>/dev/null | grep -q '^4\.6\.3\.stable' || die "Godot 4.6.3 bulunamadı (SQUISHY_GODOT)"

gate() {   # $1 preset, $2 path → çıkış kodu: 0 aday, 2 engelli, 3 non-publishable, 4 debug
	local code=0
	timeout 280 "$GODOT" --headless --path . res://tools/release/release_check.tscn -- \
		"--preset=$1" "--path=$2" "--build=${3:-release}" | grep -v '^Godot Engine' || code=${PIPESTATUS[0]}
	return "$code"
}

# Godot'un headless Gradle export'u "[ DONE ] export" deyip bazen çıkmıyor (bu
# repo'nun bilinen tuzağı): çıktı dosyası + DONE satırı görülünce YALNIZ bu
# süreç sonlandırılır (başka Godot süreçlerine dokunulmaz); üst sınır 25 dk.
export_artifact() {   # $1 --export-debug|--export-release, $2 preset, $3 path
	local start log pid waited=0
	start=$(date +%s)
	log="$OUT/$(basename "$3").export.log"
	say "export $1 '$2' -> $3 (log: $log)"
	rm -f "$3"
	"$GODOT" --headless --path . "$1" "$2" "$3" >"$log" 2>&1 &
	pid=$!
	while kill -0 "$pid" 2>/dev/null; do
		if [ -f "$3" ] && grep -aE 'DONE.*export' "$log" >/dev/null 2>&1; then
			sleep 5
			break
		fi
		if [ "$waited" -ge 1500 ]; then
			say "export 25 dk içinde bitmedi — süreç sonlandırılıyor"
			break
		fi
		sleep 3
		waited=$((waited + 3))
	done
	if kill -0 "$pid" 2>/dev/null; then
		local winpid
		winpid="$(cat "/proc/$pid/winpid" 2>/dev/null || true)"
		if [ -n "$winpid" ]; then taskkill //F //PID "$winpid" >/dev/null 2>&1 || true; else kill "$pid" 2>/dev/null || true; fi
	fi
	wait "$pid" 2>/dev/null || true
	if [ ! -f "$3" ] || [ "$(stat -c %Y "$3")" -lt "$start" ]; then
		grep -aE "ERROR|failed|Could not find|BLOCKED|REDDED" "$log" | tail -20 || true
		die "export üretmedi: $3"
	fi
	grep -aE "SquishyReleaseGate|SquishyAdsExport" "$log" | head -40 || true
}

case "$MODE" in
	check)
		code=0; gate "$RELEASE_PRESET" "$OUT/squishy_merge_${TAG}_release.aab" || code=$?
		case "$code" in
			0) say "UPLOAD_CANDIDATE — tools/release/release_android.sh aab" ;;
			2) say "BLOCKED — yukarıdaki engeller kapanmadan yüklenebilir AAB üretilmez" ;;
			*) say "kapı çıkış kodu $code" ;;
		esac
		exit "$code" ;;
	debug-apk)
		APK="$OUT/squishy_merge_${TAG}_testads_debug.apk"
		export_artifact --export-debug "$DEBUG_PRESET" "$APK"
		"$PY" tools/release/scan_artifact.py "$APK" --mode debug --sdk "$SDK" --json "$APK.scan.json"
		say "TEST-reklam debug APK: $APK (Google test kimlikleri; Play'e YÜKLENMEZ)" ;;
	aab)
		AAB="$OUT/squishy_merge_${TAG}_release.aab"
		code=0; gate "$RELEASE_PRESET" "$AAB" || code=$?
		if [ "$code" != "0" ]; then
			say "REDDEDİLDİ: release kapısı engelli (kod $code) — yüklenebilir AAB ÜRETİLMEDİ."
			say "Engelleri kapat (docs/ANDROID_RELEASE_CHECKLIST.md) ya da pipeline'ı doğrulamak için:"
			say "  tools/release/release_android.sh non-publishable-aab"
			exit 2
		fi
		export_artifact --export-release "$RELEASE_PRESET" "$AAB"
		"$PY" tools/release/scan_artifact.py "$AAB" --mode release --sdk "$SDK" --json "$AAB.scan.json"
		say "UPLOAD_CANDIDATE AAB: $AAB — Play Console'a yüklemeden önce checklist'in Play/hesap bölümleri" ;;
	non-publishable-aab)
		AAB="$OUT/NOT_FOR_UPLOAD_squishy_merge_${TAG}_unsigned.aab"
		export SQUISHY_NON_PUBLISHABLE_RELEASE=1
		code=0; gate "$NP_PRESET" "$AAB" || code=$?
		[ "$code" = "3" ] || die "NON_PUBLISHABLE koşulları sağlanmadı (kod $code): preset imzasız + yol NOT_FOR_UPLOAD olmalı"
		export_artifact --export-release "$NP_PRESET" "$AAB"
		"$PY" tools/release/scan_artifact.py "$AAB" --mode release --sdk "$SDK" --json "$AAB.scan.json" || true
		{
			echo "NOT FOR UPLOAD — Squishy Merge ${VERSION_NAME} (versionCode ${VERSION_CODE})"
			echo "İmzasız, release biçimli AAB; yalnız pipeline doğrulaması (Gradle release, AAB yapısı,"
			echo "arm64, manifest, boyut, sızıntı taraması). Google TEST reklam"
			echo "yapılandırması içerir; release build'de reklamlar fail-closed KAPALI. Play Console'a"
			echo "YÜKLENEMEZ ve yüklenmemelidir. Rapor: $(basename "$AAB").scan.json"
		} > "$AAB.NOT_FOR_UPLOAD.txt"
		say "NON-PUBLISHABLE AAB: $AAB (+ .NOT_FOR_UPLOAD.txt) — Play'e YÜKLENEMEZ" ;;
	*)
		die "bilinmeyen mod: $MODE (check | debug-apk | aab | non-publishable-aab)" ;;
esac
