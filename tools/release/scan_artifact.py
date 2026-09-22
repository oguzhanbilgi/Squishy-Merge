"""Squishy Merge (M9-01) — scan an exported Android artifact (APK or AAB).

  python tools/release/scan_artifact.py ARTIFACT --mode debug|release [--sdk SDK_DIR] [--json OUT]

Checks (exit 1 on any failure):
  - no dev/test/doc/secret files inside the game assets (tools/, docs/, build/,
    _visual_source/, *.md, *.py, test suites, QA harnesses, release gate tooling,
    keystores, export presets/credentials);
  - the packed AdMob configuration (addons/AdmobPlugin/android_export.cfg) and
    the manifest APPLICATION_ID: debug -> Google's official sample app id;
  - the patched AdMob plugin (UMP canRequestAds / privacy options) is in the dex;
  - manifest facts via aapt2 (package, versionCode/Name, min/target SDK,
    permissions, debuggable) — printed for the release report.
Editor-only plugin scripts (addons/squishy_*) are reported as a warning.
"""
import argparse
import hashlib
import io
import json
import os
import re
import subprocess
import sys
import tempfile
import zipfile

GOOGLE_SAMPLE_PUBLISHER = "ca-app-pub-3940256099942544"
GOOGLE_SAMPLE_APP_ID = "ca-app-pub-3940256099942544~3347511713"
FORBIDDEN = [
    (r"(^|/)tools/", "tools/"),
    (r"(^|/)docs/", "docs/"),
    (r"(^|/)build/", "build/"),
    (r"(^|/)_visual_source/", "_visual_source/"),
    (r"\.md$", "*.md"),
    (r"\.py$", "*.py"),
    (r"fake_ad_backend", "FakeAdBackend (test double)"),
    (r"_test\.(gd|gdc|tscn|scn)$", "test suite"),
    (r"(release_readiness|release_check|scan_artifact)", "release gate tooling"),
    (r"(ads_device|gameplay_device|audio_device|_shots)\.", "QA harness"),
    (r"\.(keystore|jks)$", "keystore"),
    (r"export_presets\.cfg$", "export_presets.cfg"),
    (r"export_credentials", "export credentials"),
    (r"keystore\.properties$", "keystore.properties"),
]
EDITOR_ONLY = [r"^addons/squishy_ads_export/", r"^addons/squishy_release/"]
PATCHED_DEX_STRINGS = [b"can_request_ads", b"get_privacy_options_requirement_status",
                       b"show_privacy_options_form", b"privacy_options_form_dismissed"]


def sha256(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def find_aapt2(sdk: str) -> str:
    bt = os.path.join(sdk, "build-tools")
    if not os.path.isdir(bt):
        return ""
    for version in sorted(os.listdir(bt), reverse=True):
        for name in ("aapt2.exe", "aapt2"):
            p = os.path.join(bt, version, name)
            if os.path.isfile(p):
                return p
    return ""


def manifest_xmltree(aapt2: str, artifact: str, is_aab: bool, zf: zipfile.ZipFile) -> str:
    if not aapt2:
        return ""
    if not is_aab:
        return subprocess.run([aapt2, "dump", "xmltree", "--file", "AndroidManifest.xml", artifact],
                              capture_output=True, text=True, encoding="utf-8", errors="replace").stdout
    # AAB: proto manifest — repack as a proto "APK" (manifest + resources.pb at the root).
    with tempfile.TemporaryDirectory() as tmp:
        probe = os.path.join(tmp, "proto.apk")
        with zipfile.ZipFile(probe, "w") as out:
            out.writestr("AndroidManifest.xml", zf.read("base/manifest/AndroidManifest.xml"))
            if "base/resources.pb" in zf.namelist():
                out.writestr("resources.pb", zf.read("base/resources.pb"))
        return subprocess.run([aapt2, "dump", "xmltree", "--file", "AndroidManifest.xml", probe],
                              capture_output=True, text=True, encoding="utf-8", errors="replace").stdout


def _int_attr(tree: str, attr: str) -> str:
    m = re.search(attr + r"\(0x[0-9a-f]+\)=(?:\(type 0x10\))?(0x[0-9a-f]+|\d+)", tree)
    if not m:
        return ""
    value = m.group(1)
    return str(int(value, 16)) if value.startswith("0x") else value


def parse_manifest(tree: str) -> dict:
    facts = {
        "package": (re.search(r'A: package="([^"]+)"', tree) or [None, ""])[1],
        "versionCode": _int_attr(tree, "versionCode"),
        "versionName": (re.search(r'versionName\(0x[0-9a-f]+\)="([^"]*)"', tree) or [None, ""])[1],
        "minSdk": _int_attr(tree, "minSdkVersion"),
        "targetSdk": _int_attr(tree, "targetSdkVersion"),
        "debuggable": bool(re.search(r"debuggable\(0x[0-9a-f]+\)=(?:\(type 0x12\))?(0xffffffff|true)", tree)),
        "permissions": sorted(set(re.findall(r'uses-permission.*?\n\s+A: [^\n]*:name\(0x[0-9a-f]+\)="([^"]+)"', tree))),
        "application_id_meta": "",
    }
    lines = tree.splitlines()
    for i, line in enumerate(lines):
        if '"com.google.android.gms.ads.APPLICATION_ID"' in line:
            for nxt in lines[i + 1:i + 4]:
                m = re.search(r':value\(0x[0-9a-f]+\)="([^"]+)"', nxt)
                if m:
                    facts["application_id_meta"] = m.group(1)
                    break
    return facts


def parse_ads_cfg(text: str) -> dict:
    section, out = "", {}
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith(";"):
            continue
        if line.startswith("[") and line.endswith("]"):
            section = line[1:-1]
            continue
        if "=" in line:
            key, value = line.split("=", 1)
            out[f"{section}/{key.strip()}"] = value.strip().strip('"')
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("artifact")
    ap.add_argument("--mode", choices=["debug", "release"], required=True)
    ap.add_argument("--sdk", default=os.environ.get("SQUISHY_ANDROID_SDK", ""))
    ap.add_argument("--json", default="")
    args = ap.parse_args()

    path = args.artifact
    is_aab = path.lower().endswith(".aab")
    zf = zipfile.ZipFile(path)
    names = zf.namelist()
    # AAB: Godot puts the game files in the install-time asset pack (Gradle template
    # module `assetPackInstallTime`), not in base/assets/.
    asset_roots = ["assetPackInstallTime/assets/", "base/assets/"] if is_aab else ["assets/"]
    dex_names = [n for n in names if re.match((r"base/dex/" if is_aab else r"") + r"classes\d*\.dex$", n)]
    lib_prefix = "base/lib/" if is_aab else "lib/"
    abis = sorted({n[len(lib_prefix):].split("/")[0] for n in names if n.startswith(lib_prefix) and n.count("/") >= 2})

    failures, warnings = [], []
    leaks = []
    asset_files = {}
    for n in names:
        root = next((r for r in asset_roots if n.startswith(r)), "")
        if not root:
            continue
        rel = n[len(root):]
        asset_files[rel] = n
        for pattern, label in FORBIDDEN:
            if re.search(pattern, rel):
                leaks.append(f"{label}: {rel}")
        for pattern in EDITOR_ONLY:
            if re.search(pattern, rel):
                warnings.append(f"editor-only plugin script packed (harmless, not a secret): {rel}")
    if leaks:
        failures.append(f"{len(leaks)} forbidden asset(s): " + "; ".join(leaks[:10]))

    cfg_name = asset_files.get("addons/AdmobPlugin/android_export.cfg", "")
    ads = parse_ads_cfg(zf.read(cfg_name).decode("utf-8")) if cfg_name else {}
    if not ads:
        failures.append("android_export.cfg is NOT packed (runtime would fail closed: no ads)")
    dex_blob = b"".join(zf.read(n) for n in dex_names)
    patched = all(s in dex_blob for s in PATCHED_DEX_STRINGS)
    if not patched:
        failures.append("patched AdMob plugin (UMP canRequestAds / privacy options) NOT found in dex")

    aapt2 = find_aapt2(args.sdk) if args.sdk else ""
    manifest = parse_manifest(manifest_xmltree(aapt2, path, is_aab, zf)) if aapt2 else {}
    if args.mode == "debug":
        if ads.get("General/is_real", "").lower() != "false":
            failures.append("debug artifact: packed config is_real is not false")
        debug_ids = [v for k, v in ads.items() if k.startswith("Debug/") and k.endswith("_id")]
        if not debug_ids or any(not v.startswith(GOOGLE_SAMPLE_PUBLISHER) for v in debug_ids):
            failures.append("debug artifact: a [Debug] ad id is not a Google sample id")
        if manifest and manifest.get("application_id_meta") != GOOGLE_SAMPLE_APP_ID:
            failures.append(f"debug artifact: manifest APPLICATION_ID is {manifest.get('application_id_meta')!r}, "
                            f"expected Google sample {GOOGLE_SAMPLE_APP_ID}")
    if manifest and "arm64-v8a" not in abis:
        failures.append("arm64-v8a native libraries missing")

    report = {
        "artifact": os.path.basename(path), "format": "AAB" if is_aab else "APK", "mode": args.mode,
        "bytes": os.path.getsize(path), "sha256": sha256(path), "entries": len(names),
        "game_asset_files": len(asset_files), "asset_roots": asset_roots, "abis": abis,
        "dex_files": dex_names, "patched_admob_plugin_in_dex": patched,
        "ads_cfg": {k: v for k, v in ads.items() if k.startswith(("General/", "Debug/", "Release/", "Audience/"))},
        "manifest": manifest, "aapt2": bool(aapt2), "warnings": sorted(set(warnings)), "failures": failures,
    }
    print(json.dumps(report, indent=2, ensure_ascii=False))
    if args.json:
        with open(args.json, "w", encoding="utf-8") as f:
            json.dump(report, f, indent=2, ensure_ascii=False)
    print("SCAN " + ("PASS" if not failures else "FAIL"))
    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main())
