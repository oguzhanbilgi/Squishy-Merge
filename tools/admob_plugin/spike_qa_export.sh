#!/usr/bin/env bash
# TASK/040 FEASIBILITY ONLY -- export the tools/ads_device QA harness as the QA package
# (com.obappstudio.squishymerge.qa, Google TEST ad ids only) with the GMA 25.3.0 TEEN SPIKE
# plugin built by `build_patched_plugin.sh spike`. This is NOT a production build path.
#
# Swapped ONLY for this export and restored byte-identically (sha256 checked, trap on exit):
#   addons/AdmobPlugin  2 AARs + Admob.gd + AdmobPlugin.gd + model/AdmobConfig.gd (git checkout)
#   project.godot       run/main_scene -> res://tools/ads_device.tscn (backup copy)
#   export_presets.cfg  (gitignored, local) preset.0 via spike_qa_preset.py (backup copy)
# Refuses to start if any of those tracked files is already modified. Only this export's own
# Godot process is ever terminated. Output: build/qa_040/ (gitignored).
set -uo pipefail
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO" || exit 1
GODOT="${SQUISHY_GODOT:-C:/Users/ledaj/AppData/Local/Godot463/Godot_v4.6.3-stable_win64_console.exe}"
PY="${PYTHON:-$(command -v python3 || command -v python)}"
SPIKE="$REPO/build/admob_plugin_spike/out/spike"
OUTDIR="$REPO/build/qa_040"
TMP="$OUTDIR/_tmp"
APK_REL="build/qa_040/squishy_merge_ads_qa_040_gma25_teen_spike_debug.apk"
APK="$REPO/$APK_REL"
PLUGIN_FILES="addons/AdmobPlugin/bin/debug/AdmobPlugin-debug.aar addons/AdmobPlugin/bin/release/AdmobPlugin-release.aar addons/AdmobPlugin/Admob.gd addons/AdmobPlugin/AdmobPlugin.gd addons/AdmobPlugin/model/AdmobConfig.gd"

say() { printf '[spike-qa] %s\n' "$*"; }
die() { printf '[spike-qa] ERROR: %s\n' "$*" >&2; exit 1; }

for f in AdmobPlugin-debug.aar AdmobPlugin-release.aar addon/Admob.gd addon/AdmobPlugin.gd addon/model/AdmobConfig.gd; do
	[ -f "$SPIKE/$f" ] || die "missing $SPIKE/$f -- run tools/admob_plugin/build_patched_plugin.sh spike first"
done
grep -q 'play-services-ads:25.3.0' "$SPIKE/addon/AdmobPlugin.gd" || die "spike addon does not declare GMA 25.3.0"
# shellcheck disable=SC2086
git diff --quiet -- project.godot $PLUGIN_FILES || die "project.godot / addons/AdmobPlugin already modified -- refusing"
[ -f export_presets.cfg ] || die "export_presets.cfg missing (local, gitignored)"

mkdir -p "$TMP"
cp project.godot "$TMP/project.godot.bak"
cp export_presets.cfg "$TMP/export_presets.cfg.bak"
# shellcheck disable=SC2086
sha256sum project.godot export_presets.cfg $PLUGIN_FILES > "$TMP/before.sha256"

restore() {
	# shellcheck disable=SC2086
	git checkout -- $PLUGIN_FILES
	cp "$TMP/project.godot.bak" project.godot
	cp "$TMP/export_presets.cfg.bak" export_presets.cfg
	if sha256sum -c --quiet "$TMP/before.sha256"; then
		say "RESTORED: project.godot, export_presets.cfg and addons/AdmobPlugin byte-identical to before"
	else
		say "RESTORE MISMATCH -- inspect git status NOW"
	fi
}
trap restore EXIT

cp "$SPIKE/AdmobPlugin-debug.aar" addons/AdmobPlugin/bin/debug/AdmobPlugin-debug.aar
cp "$SPIKE/AdmobPlugin-release.aar" addons/AdmobPlugin/bin/release/AdmobPlugin-release.aar
cp "$SPIKE/addon/Admob.gd" addons/AdmobPlugin/Admob.gd
cp "$SPIKE/addon/AdmobPlugin.gd" addons/AdmobPlugin/AdmobPlugin.gd
cp "$SPIKE/addon/model/AdmobConfig.gd" addons/AdmobPlugin/model/AdmobConfig.gd
sed -i 's#^run/main_scene="res://scenes/main.tscn"#run/main_scene="res://tools/ads_device.tscn"#' project.godot
grep -q '^run/main_scene="res://tools/ads_device.tscn"' project.godot || die "main_scene swap failed"
"$PY" "$REPO/tools/admob_plugin/spike_qa_preset.py" export_presets.cfg "$APK_REL" || die "QA preset edit refused"

say "export (Gradle, GMA 25.3.0 from Google Maven) -> $APK_REL"
T0=$(date +%s)
rm -f "$APK"
"$GODOT" --headless --path . --export-debug "Android" "$APK_REL" > "$TMP/export.log" 2>&1 &
PID=$!
W=0
while kill -0 "$PID" 2>/dev/null; do
	if [ -f "$APK" ] && grep -aE 'DONE.*export' "$TMP/export.log" >/dev/null 2>&1; then sleep 5; break; fi
	[ "$W" -ge 1500 ] && { say "export did not finish in 25 min"; break; }
	sleep 3; W=$((W + 3))
done
if kill -0 "$PID" 2>/dev/null; then
	WINPID="$(cat "/proc/$PID/winpid" 2>/dev/null || true)"
	if [ -n "$WINPID" ]; then taskkill //F //PID "$WINPID" >/dev/null 2>&1 || true; else kill "$PID" 2>/dev/null || true; fi
fi
wait "$PID" 2>/dev/null
say "export duration $(( $(date +%s) - T0 ))s"
sed 's/\x1b\[[0-9;]*m//g' "$TMP/export.log" | grep -aE "SquishyAdsExport|SquishyReleaseGate|DONE|ERROR|error:|FAILURE" | tail -15
[ -f "$APK" ] && [ "$(stat -c %Y "$APK")" -ge "$T0" ] || die "no APK produced"
say "APK $(stat -c %s "$APK") B sha256 $(sha256sum "$APK" | cut -c1-64)"
