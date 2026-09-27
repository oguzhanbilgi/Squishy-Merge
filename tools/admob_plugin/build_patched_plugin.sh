#!/usr/bin/env bash
# Squishy Merge (M9-01, TASK/041, TASK/042) — deterministic rebuild of the godot-admob v6.0 Android
# plugin with the three production patches, applied in this order:
#   0001  UMP privacy options / debug geography (M9-01)
#   0002  RequestConfiguration value conversion for Godot 4.6 Long / Object[] values (TASK/041)
#   0003  Google Mobile Ads SDK 25.3.0 (UMP 4.0.0 transitively) + AgeRestrictedTreatment (TFAT)
#         support + SDK read-back API; advertising id never logged (TASK/042)
#
#   tools/admob_plugin/build_patched_plugin.sh verify    rebuild v6.0 + 0001 + 0002 + 0003 and prove
#                                                        the committed addons/AdmobPlugin files are
#                                                        exactly that build (default)
#   tools/admob_plugin/build_patched_plugin.sh build     rebuild v6.0 + 0001 + 0002 + 0003 into
#                                                        $WORK/out/build and print the SHA-256s —
#                                                        installs and compares nothing (run twice
#                                                        to prove reproducibility BEFORE install)
#   tools/admob_plugin/build_patched_plugin.sh install   rebuild, then copy the two AARs and the
#                                                        generated files the patches change (Admob.gd,
#                                                        AdmobPlugin.gd, model/AdmobConfig.gd) into
#                                                        addons/AdmobPlugin
#   tools/admob_plugin/build_patched_plugin.sh baseline  rebuild UNPATCHED v6.0 and prove it equals
#                                                        the upstream v6.0 release AARs (toolchain check)
#
# Every patched mode also resolves the plugin's runtime classpath and fails unless it is
# play-services-ads 25.3.0 / play-services-ads-api 25.3.0 / user-messaging-platform 4.0.0.
#
# Nothing is installed system-wide: the JDK and Android SDK are the ones the
# Godot editor already uses, Gradle is the project's own Godot 4.6.3 Android
# build template wrapper (Gradle 8.11.1), godot-lib is that template's AAR.
# Overrides: SQUISHY_JAVA_HOME, SQUISHY_ANDROID_SDK, SQUISHY_PLUGIN_WORK.
# Read tools/admob_plugin/README.md first.
set -euo pipefail

MODE="${1:-verify}"
case "$MODE" in verify|build|install|baseline) ;; *) echo "usage: $0 [verify|build|install|baseline]"; exit 64 ;; esac

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
HERE="$REPO/tools/admob_plugin"
PLUGIN="$REPO/addons/AdmobPlugin"
WORK="${SQUISHY_PLUGIN_WORK:-$REPO/build/admob_plugin}"
PATCH="$HERE/0001-ump-privacy-options-and-debug-geography.patch"
# TASK/041 production fix: AdmobConfiguration reads Godot 4.6 Long / Object[] values safely
# (the v6.0 (int) / (String[]) casts threw, so RequestConfiguration was never applied).
CONFIG_PATCH="$HERE/0002-fix-request-configuration-value-types.patch"
CONFIG_PATCH_SHA256="bfa9fb450d86956c4326d47c4d930b86948c19961bef07ceed7145d94bf73b9d"
# TASK/042 production migration (promoted from the TASK/040 spike): playads 24.9.0 -> 25.3.0,
# AgeRestrictedTreatment (UNSPECIFIED / CHILD / TEEN) in the request configuration, the SDK
# read-back API get_applied_request_configuration(), read-back log before MobileAds.initialize(),
# advertising id no longer logged. Runtime default stays UNSPECIFIED (set by the project, not here).
GMA25_PATCH="$HERE/0003-gma25-age-restricted-treatment.patch"
GMA25_PATCH_SHA256="6767e1aaa1e24b995309f28954b1a18e35f043559c7a06aab82b740448adec3f"
EXPECTED_GMA="25.3.0"
EXPECTED_UMP="4.0.0"

UPSTREAM_URL="https://github.com/godot-sdk-integrations/godot-admob.git"
PINNED_COMMIT="90e3c616ea3c680e3875c31e6bcccffbebbe9d3b"   # tag v6.0 ("Upgraded to Godot 4.6 (#89)")
PATCH_SHA256="57580a948b7c969ea83d5f0601d472c940f14c1f96967ca3af4c89f2a8b9c5eb"
# Upstream v6.0 release assets (built by upstream CI) — committed on main until M9-01.
UPSTREAM_AAR_COMMIT="5a3a0f0bc06e071127e5c1c0ea0d4abfcbf50bc1"
UPSTREAM_DEBUG_SHA256="388243802894363133814f9f8c0c9be61adc27b5911c11460483768700f6be63"
UPSTREAM_RELEASE_SHA256="526516f93b1e29a6749b0293d86649bb7a6971603258a62e109dfd65afb36789"
# This build on Windows (AGP writes the AAR manifest with CRLF there; a Linux
# build differs ONLY in those line endings — aar_equivalence.py accepts that).
PATCHED_DEBUG_SHA256_WINDOWS="a78acb2274db8081364258e2e6686fed8e49117810cbe5a8e1fd82a44c7315b6"
PATCHED_RELEASE_SHA256_WINDOWS="f5a563a7f3784a1006520199c0946ba05c7a2eb41da7fb55deebda93371b20f8"
GODOT_TEMPLATE_VERSION="4.6.3.stable"
BUILD_TOOLS="36.1.0"          # upstream pins 35.0.0; 36.1.0 is what Godot 4.6.3's template uses
PLATFORM="android-35"         # upstream compileSdk 35
# Generated addon files the patches change (0001 + 0003); every other generated file must equal
# the committed upstream-generated one.
PATCHED_GENERATED="Admob.gd AdmobPlugin.gd model/AdmobConfig.gd"

say() { printf '[admob-plugin] %s\n' "$*"; }
die() { printf '[admob-plugin] ERROR: %s\n' "$*" >&2; exit 1; }
sha() { sha256sum "$1" | cut -d' ' -f1; }
is_patched_generated() { case " $PATCHED_GENERATED " in *" $1 "*) return 0 ;; esac; return 1; }

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

# --- Source: exact upstream commit, LF checkout, patches ---------------------
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
apply_patch() {   # FILE PINNED_SHA LABEL
	[ "$(sha "$1")" = "$2" ] || die "$3 patch SHA-256 changed — update its pin deliberately"
	git -C "$SRC" apply --check "$1"
	git -C "$SRC" apply "$1"
	say "patch: $(basename "$1") $2"
}
if [ "$MODE" != "baseline" ]; then
	apply_patch "$PATCH" "$PATCH_SHA256" "0001"
	apply_patch "$CONFIG_PATCH" "$CONFIG_PATCH_SHA256" "0002"
	apply_patch "$GMA25_PATCH" "$GMA25_PATCH_SHA256" "0003"
	grep -q "^playads = \"$EXPECTED_GMA\"$" "$SRC/common/gradle/libs.versions.toml" || die "patched source does not pin playads $EXPECTED_GMA"
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
for rel in $PATCHED_GENERATED; do
	mkdir -p "$OUT/$(dirname "$rel")"
	tr -d '\r' <"$GEN/$rel" >"$OUT/$rel"   # the repo stores LF (.gitattributes)
done
say "built debug   $(sha "$OUT/AdmobPlugin-debug.aar")"
say "built release $(sha "$OUT/AdmobPlugin-release.aar")"

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

# The Google SDK versions the patched plugin resolves (its release runtime classpath = what the
# generated AdmobPlugin.gd hands to the app's Gradle build). UMP comes transitively from
# play-services-ads-api; nothing may resolve to an older or newer version.
DEPS="$WORK/$MODE.dependencies.txt"
"$GRADLEW" -p "$SRC/common" --no-daemon --console=plain -Pandroid.builder.sdkDownload=false \
	:android:dependencies --configuration releaseRuntimeClasspath >"$DEPS" 2>&1 \
	|| { tail -30 "$DEPS"; die "gradle dependency report failed"; }
# Every report line for the three artifacts, reduced to "artifact resolved-version": the version
# after " -> " when Gradle resolved a range / conflict, else the requested one. Each artifact must
# resolve to exactly one version, the expected one (a "4.0.0 -> 4.1.0" line fails).
RESOLVED="$(grep -oE "com\.google\.android\.(gms:play-services-ads(-api)?|ump:user-messaging-platform):[^ ]+( -> [^ ]+)?" "$DEPS" \
	| sed -E 's/^com\.google\.android\.(gms|ump):([^:]+):([^ ]+)( -> ([^ ]+))?$/\2 \3 \5/' \
	| awk '{ print $1, ($3 != "" ? $3 : $2) }' | sort -u)"
for artifact in play-services-ads play-services-ads-api user-messaging-platform; do
	want="$EXPECTED_GMA"; [ "$artifact" = "user-messaging-platform" ] && want="$EXPECTED_UMP"
	got="$(printf '%s\n' "$RESOLVED" | awk -v a="$artifact" '$1 == a { print $2 }' | sort -u | tr '\n' ' ')"
	[ "$got" = "$want " ] || die "runtime classpath resolves $artifact '${got% }' (expected exactly $want; see $DEPS)"
done
grep -q "\"com.google.android.gms:play-services-ads:$EXPECTED_GMA\"" "$OUT/AdmobPlugin.gd" \
	|| die "generated AdmobPlugin.gd does not declare play-services-ads:$EXPECTED_GMA"
say "resolved: play-services-ads $EXPECTED_GMA, play-services-ads-api $EXPECTED_GMA, user-messaging-platform $EXPECTED_UMP (log: $DEPS)"

if [ "$(sha "$OUT/AdmobPlugin-debug.aar")" = "$PATCHED_DEBUG_SHA256_WINDOWS" ] \
	&& [ "$(sha "$OUT/AdmobPlugin-release.aar")" = "$PATCHED_RELEASE_SHA256_WINDOWS" ]; then
	say "hashes match the recorded Windows build"
else
	say "hashes differ from the recorded Windows build"
fi
if [ "$MODE" = "build" ]; then
	say "BUILD OK -> $OUT (nothing installed or compared)"
	exit 0
fi
if [ "$MODE" = "verify" ]; then
	say "checking content equivalence with addons/AdmobPlugin"
	for v in debug release; do $EQ "$PLUGIN/bin/$v/AdmobPlugin-$v.aar" "$OUT/AdmobPlugin-$v.aar" || FAIL=1; done
fi
# Generated GDScript: the patched files are compared / installed below; every other generated
# file must equal the committed (upstream-generated) one.
while IFS= read -r f; do
	rel="${f#"$GEN"/}"
	is_patched_generated "$rel" && continue
	if ! diff -q --strip-trailing-cr "$f" "$PLUGIN/$rel" >/dev/null 2>&1; then
		say "generated $rel differs from addons/AdmobPlugin/$rel"; FAIL=1
	fi
done < <(find "$GEN" -type f)
[ "$FAIL" = 0 ] || die "verification failed"

if [ "$MODE" = "install" ]; then
	cp "$OUT/AdmobPlugin-debug.aar" "$PLUGIN/bin/debug/AdmobPlugin-debug.aar"
	cp "$OUT/AdmobPlugin-release.aar" "$PLUGIN/bin/release/AdmobPlugin-release.aar"
	for rel in $PATCHED_GENERATED; do cp "$OUT/$rel" "$PLUGIN/$rel"; done
	say "INSTALLED into addons/AdmobPlugin (update VERSION.md hashes if they changed)"
else
	for rel in $PATCHED_GENERATED; do
		cmp -s "$OUT/$rel" "$PLUGIN/$rel" || die "addons/AdmobPlugin/$rel is not the patched generated file"
	done
	say "VERIFY OK: addons/AdmobPlugin == godot-admob $PINNED_COMMIT + $(basename "$PATCH") + $(basename "$CONFIG_PATCH") + $(basename "$GMA25_PATCH")"
fi
