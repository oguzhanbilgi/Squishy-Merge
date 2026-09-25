#!/usr/bin/env bash
# Squishy Merge (M9-01) — deterministic rebuild of the godot-admob v6.0 Android
# plugin with the UMP privacy-options / debug-geography patch.
#
#   tools/admob_plugin/build_patched_plugin.sh verify    rebuild v6.0 + patch and prove the
#                                                        committed addons/AdmobPlugin files are
#                                                        exactly that build (default)
#   tools/admob_plugin/build_patched_plugin.sh install   rebuild, then copy the two AARs and the
#                                                        generated Admob.gd into addons/AdmobPlugin
#   tools/admob_plugin/build_patched_plugin.sh baseline  rebuild UNPATCHED v6.0 and prove it equals
#                                                        the upstream v6.0 release AARs (toolchain check)
#   tools/admob_plugin/build_patched_plugin.sh spike     TASK/040 FEASIBILITY ONLY: v6.0 + 0001 + 0002
#                                                        (GMA 25.3.0 / UMP 4.0.0 + age-restricted
#                                                        treatment + diagnostics) into
#                                                        build/admob_plugin_spike/out/spike — NEVER
#                                                        installed into addons/AdmobPlugin
#
# Nothing is installed system-wide: the JDK and Android SDK are the ones the
# Godot editor already uses, Gradle is the project's own Godot 4.6.3 Android
# build template wrapper (Gradle 8.11.1), godot-lib is that template's AAR.
# Overrides: SQUISHY_JAVA_HOME, SQUISHY_ANDROID_SDK, SQUISHY_PLUGIN_WORK.
# Read tools/admob_plugin/README.md first.
set -euo pipefail

MODE="${1:-verify}"
case "$MODE" in verify|install|baseline|spike) ;; *) echo "usage: $0 [verify|install|baseline|spike]"; exit 64 ;; esac

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
HERE="$REPO/tools/admob_plugin"
PLUGIN="$REPO/addons/AdmobPlugin"
if [ "$MODE" = "spike" ]; then
	WORK="${SQUISHY_PLUGIN_WORK:-$REPO/build/admob_plugin_spike}"
else
	WORK="${SQUISHY_PLUGIN_WORK:-$REPO/build/admob_plugin}"
fi
PATCH="$HERE/0001-ump-privacy-options-and-debug-geography.patch"
# TASK/040 feasibility spike (not production): GMA 25.3.0 (+ UMP 4.0.0 transitively),
# AgeRestrictedTreatment (TFAT) + a TFAT_DIAG diagnostic seam. Applied only in `spike` mode.
SPIKE_PATCH="$HERE/0002-spike-gma25-age-restricted-treatment.patch"
SPIKE_PATCH_SHA256="e54c22713539d2fe0bce0ad019a12733ca498eb3da297f65b83022da0be8b036"

UPSTREAM_URL="https://github.com/godot-sdk-integrations/godot-admob.git"
PINNED_COMMIT="90e3c616ea3c680e3875c31e6bcccffbebbe9d3b"   # tag v6.0 ("Upgraded to Godot 4.6 (#89)")
PATCH_SHA256="57580a948b7c969ea83d5f0601d472c940f14c1f96967ca3af4c89f2a8b9c5eb"
# Upstream v6.0 release assets (built by upstream CI) — committed on main until M9-01.
UPSTREAM_AAR_COMMIT="5a3a0f0bc06e071127e5c1c0ea0d4abfcbf50bc1"
UPSTREAM_DEBUG_SHA256="388243802894363133814f9f8c0c9be61adc27b5911c11460483768700f6be63"
UPSTREAM_RELEASE_SHA256="526516f93b1e29a6749b0293d86649bb7a6971603258a62e109dfd65afb36789"
# This build on Windows (AGP writes the AAR manifest with CRLF there; a Linux
# build differs ONLY in those line endings — aar_equivalence.py accepts that).
PATCHED_DEBUG_SHA256_WINDOWS="e3ac9a6b1492468928c037d4d21464310560c7b21c14c597fa4a567c23c6eb2d"
PATCHED_RELEASE_SHA256_WINDOWS="90d359921f10bc6618ed63b9ea97cdba5afcbdfbb8cb72fe264834e5bf478284"
GODOT_TEMPLATE_VERSION="4.6.3.stable"
BUILD_TOOLS="36.1.0"          # upstream pins 35.0.0; 36.1.0 is what Godot 4.6.3's template uses
PLATFORM="android-35"         # upstream compileSdk 35

say() { printf '[admob-plugin] %s\n' "$*"; }
die() { printf '[admob-plugin] ERROR: %s\n' "$*" >&2; exit 1; }
sha() { sha256sum "$1" | cut -d' ' -f1; }

# --- Toolchain (the Godot editor's own settings) -----------------------------
editor_setting() {
	local key="$1" file=""
	for f in "${APPDATA:-/nonexistent}/Godot/editor_settings-4.6.tres" \
			"$HOME/.local/share/godot/editor_settings-4.6.tres" \
			"$HOME/Library/Application Support/Godot/editor_settings-4.6.tres"; do
		if [ -f "$f" ]; then file="$f"; break; fi
	done
	[ -n "$file" ] || return 0
	grep -m1 "^$key = " "$file" | sed -e 's/^[^"]*"//' -e 's/"$//' -e 's/\\\\/\\/g'
}
JAVA_DIR="${SQUISHY_JAVA_HOME:-$(editor_setting export/android/java_sdk_path)}"
SDK_DIR="${SQUISHY_ANDROID_SDK:-$(editor_setting export/android/android_sdk_path)}"
JAVA_DIR="${JAVA_DIR:-${JAVA_HOME:-}}"
SDK_DIR="${SDK_DIR:-${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}}"
[ -n "$JAVA_DIR" ] || die "JDK 17 not found (Godot editor setting export/android/java_sdk_path or SQUISHY_JAVA_HOME)"
[ -n "$SDK_DIR" ] || die "Android SDK not found (export/android/android_sdk_path or SQUISHY_ANDROID_SDK)"
JAVA_DIR="${JAVA_DIR%\\}"; JAVA_DIR="${JAVA_DIR%/}"
unix_path() { if command -v cygpath >/dev/null 2>&1; then cygpath -u "$1"; else printf '%s' "$1"; fi; }
"$(unix_path "$JAVA_DIR")/bin/java" -version 2>&1 | grep -q 'version "17\.' || die "$JAVA_DIR is not a JDK 17"
[ -d "$(unix_path "$SDK_DIR")/build-tools/$BUILD_TOOLS" ] || die "Android SDK build-tools $BUILD_TOOLS missing (not auto-installed)"
[ -d "$(unix_path "$SDK_DIR")/platforms/$PLATFORM" ] || die "Android SDK platform $PLATFORM missing (not auto-installed)"
export JAVA_HOME="$JAVA_DIR" ANDROID_HOME="$SDK_DIR" ANDROID_SDK_ROOT="$SDK_DIR"

TEMPLATE="$REPO/android"
[ "$(cat "$TEMPLATE/.build_version" 2>/dev/null)" = "$GODOT_TEMPLATE_VERSION" ] \
	|| die "Godot $GODOT_TEMPLATE_VERSION Android build template not installed (Project > Install Android Build Template)"
GRADLEW="$TEMPLATE/build/gradlew"
GODOT_LIB="$TEMPLATE/build/libs/release/godot-lib.template_release.aar"
[ -f "$GRADLEW" ] && [ -f "$GODOT_LIB" ] || die "template gradlew / godot-lib missing"
say "JDK: $JAVA_DIR"
say "SDK: $SDK_DIR (build-tools $BUILD_TOOLS, $PLATFORM)"
say "Gradle: Godot template wrapper; godot-lib $GODOT_TEMPLATE_VERSION $(sha "$GODOT_LIB")"

# --- Source: exact upstream commit, LF checkout, optional patch --------------
SRC="$WORK/src"
mkdir -p "$WORK"
if [ ! -d "$SRC/.git" ]; then
	git clone --quiet --filter=blob:none --no-checkout "$UPSTREAM_URL" "$SRC"
fi
git -C "$SRC" config core.autocrlf false   # Git for Windows would CRLF the XML resources
git -C "$SRC" config core.eol lf
git -C "$SRC" cat-file -e "$PINNED_COMMIT^{commit}" 2>/dev/null || git -C "$SRC" fetch --quiet origin "$PINNED_COMMIT"
git -C "$SRC" checkout --quiet --force "$PINNED_COMMIT"
git -C "$SRC" rm -rq --cached . >/dev/null
git -C "$SRC" reset --quiet --hard "$PINNED_COMMIT"
git -C "$SRC" clean -qfdx
[ "$(git -C "$SRC" rev-parse HEAD)" = "$PINNED_COMMIT" ] || die "upstream checkout is not $PINNED_COMMIT"
say "upstream: $PINNED_COMMIT"
if [ "$MODE" != "baseline" ]; then
	[ "$(sha "$PATCH")" = "$PATCH_SHA256" ] || die "patch SHA-256 changed — update PATCH_SHA256 deliberately"
	git -C "$SRC" apply --check "$PATCH"
	git -C "$SRC" apply "$PATCH"
	say "patch: $(basename "$PATCH") $PATCH_SHA256"
fi
if [ "$MODE" = "spike" ]; then
	[ "$(sha "$SPIKE_PATCH")" = "$SPIKE_PATCH_SHA256" ] || die "spike patch SHA-256 changed — update SPIKE_PATCH_SHA256 deliberately"
	git -C "$SRC" apply --check "$SPIKE_PATCH"
	git -C "$SRC" apply "$SPIKE_PATCH"
	say "spike patch: $(basename "$SPIKE_PATCH") $SPIKE_PATCH_SHA256 (FEASIBILITY ONLY)"
fi

# Build environment only (no source change): installed build-tools, local godot-lib
# (the upstream downloadGodotAar task is skipped when the file exists).
sed -i "s/^buildTools = \"35.0.0\"$/buildTools = \"$BUILD_TOOLS\"/" "$SRC/common/gradle/libs.versions.toml"
grep -q "^buildTools = \"$BUILD_TOOLS\"$" "$SRC/common/gradle/libs.versions.toml" || die "buildTools pin not applied"
mkdir -p "$SRC/android/libs"
cp "$GODOT_LIB" "$SRC/android/libs/godot-lib-4.6.stable.aar"

LOG="$WORK/$MODE.log"
say "gradle build (log: $LOG) ..."
"$GRADLEW" -p "$SRC/common" --no-daemon --console=plain -Pandroid.builder.sdkDownload=false \
	:android:assembleDebug :android:assembleRelease :addon:generateGDScript >"$LOG" 2>&1 \
	|| { tail -30 "$LOG"; die "gradle build failed"; }

OUT="$WORK/out/$MODE"
rm -rf "$OUT"; mkdir -p "$OUT"
cp "$SRC/android/build/outputs/aar/AdmobPlugin-debug.aar" "$SRC/android/build/outputs/aar/AdmobPlugin-release.aar" "$OUT/"
GEN="$SRC/addon/build/output/AdmobPlugin"
tr -d '\r' <"$GEN/Admob.gd" >"$OUT/Admob.gd"   # the repo stores LF (.gitattributes)
say "built debug   $(sha "$OUT/AdmobPlugin-debug.aar")"
say "built release $(sha "$OUT/AdmobPlugin-release.aar")"

if [ "$MODE" = "spike" ]; then
	# Feasibility output only: the two AARs + the whole generated addon (Admob.gd, model/,
	# AdmobPlugin.gd with the GMA 25.3.0 dependency). Nothing is copied into addons/.
	mkdir -p "$OUT/addon"
	(cd "$GEN" && find . -type f) | while IFS= read -r rel; do
		mkdir -p "$OUT/addon/$(dirname "$rel")"
		case "$rel" in
			*.gd|*.cfg) tr -d '\r' <"$GEN/$rel" >"$OUT/addon/$rel" ;;   # the repo stores LF
			*) cp "$GEN/$rel" "$OUT/addon/$rel" ;;                        # binary (icon.png)
		esac
	done
	grep -q 'com.google.android.gms:play-services-ads:25.3.0' "$OUT/addon/AdmobPlugin.gd" || die "spike: generated AdmobPlugin.gd does not declare GMA 25.3.0"
	say "SPIKE BUILD OK -> $OUT (NOT installed; addons/AdmobPlugin stays GMA 24.9.0 / UMP 3.2.0)"
	exit 0
fi

PY="${PYTHON:-$(command -v python3 || command -v python || true)}"
[ -n "$PY" ] || die "python not found (needed for aar_equivalence.py)"
EQ="$PY $HERE/aar_equivalence.py"
FAIL=0
if [ "$MODE" = "baseline" ]; then
	REF="$WORK/upstream_release"; mkdir -p "$REF"
	for v in debug release; do
		git -C "$REPO" show "$UPSTREAM_AAR_COMMIT:addons/AdmobPlugin/bin/$v/AdmobPlugin-$v.aar" >"$REF/AdmobPlugin-$v.aar"
	done
	[ "$(sha "$REF/AdmobPlugin-debug.aar")" = "$UPSTREAM_DEBUG_SHA256" ] || die "upstream debug AAR hash mismatch"
	[ "$(sha "$REF/AdmobPlugin-release.aar")" = "$UPSTREAM_RELEASE_SHA256" ] || die "upstream release AAR hash mismatch"
	for v in debug release; do $EQ "$REF/AdmobPlugin-$v.aar" "$OUT/AdmobPlugin-$v.aar" || FAIL=1; done
	[ "$FAIL" = 0 ] && say "BASELINE OK: this toolchain reproduces the upstream v6.0 release AARs" || die "baseline differs"
	exit 0
fi

[ "$(sha "$OUT/AdmobPlugin-debug.aar")" = "$PATCHED_DEBUG_SHA256_WINDOWS" ] \
	&& [ "$(sha "$OUT/AdmobPlugin-release.aar")" = "$PATCHED_RELEASE_SHA256_WINDOWS" ] \
	&& say "hashes match the recorded Windows build" \
	|| say "hashes differ from the recorded Windows build — checking content equivalence"
if [ "$MODE" = "verify" ]; then
	for v in debug release; do $EQ "$PLUGIN/bin/$v/AdmobPlugin-$v.aar" "$OUT/AdmobPlugin-$v.aar" || FAIL=1; done
fi
# Generated GDScript: only Admob.gd is touched by the patch; the rest must equal the
# committed (upstream-generated) files.
while IFS= read -r f; do
	rel="${f#"$GEN"/}"
	[ "$rel" = "Admob.gd" ] && continue
	if ! diff -q --strip-trailing-cr "$f" "$PLUGIN/$rel" >/dev/null 2>&1; then
		say "generated $rel differs from addons/AdmobPlugin/$rel"; FAIL=1
	fi
done < <(find "$GEN" -type f)
[ "$FAIL" = 0 ] || die "verification failed"

if [ "$MODE" = "install" ]; then
	cp "$OUT/AdmobPlugin-debug.aar" "$PLUGIN/bin/debug/AdmobPlugin-debug.aar"
	cp "$OUT/AdmobPlugin-release.aar" "$PLUGIN/bin/release/AdmobPlugin-release.aar"
	cp "$OUT/Admob.gd" "$PLUGIN/Admob.gd"
	say "INSTALLED into addons/AdmobPlugin (update VERSION.md hashes if they changed)"
else
	cmp -s "$OUT/Admob.gd" "$PLUGIN/Admob.gd" || die "addons/AdmobPlugin/Admob.gd is not the patched generated file"
	say "VERIFY OK: addons/AdmobPlugin == godot-admob $PINNED_COMMIT + $(basename "$PATCH")"
fi
