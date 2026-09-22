"""Content equivalence of two Godot AdMob plugin AARs (M9-01).

A byte-identical AAR is the strongest proof; when the SHA-256 differs this
checks WHY. Every entry must be byte-identical (classes.jar is compared class
by class) except AndroidManifest.xml, which may differ ONLY in line endings:
AGP writes the library manifest with the build machine's line separator (CRLF
on Windows, LF on the Linux CI that built the upstream release).

Usage:  python aar_equivalence.py A.aar B.aar
Exit:   0 = equivalent (identical, or manifest line endings only), 1 = different.
"""
import hashlib
import io
import sys
import zipfile

LINE_ENDING_ONLY = {"AndroidManifest.xml"}


def _entries(data: bytes) -> dict:
    with zipfile.ZipFile(io.BytesIO(data)) as zf:
        return {info.filename: zf.read(info.filename) for info in zf.infolist()}


def _sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def compare(path_a: str, path_b: str) -> bool:
    raw_a = open(path_a, "rb").read()
    raw_b = open(path_b, "rb").read()
    print(f"A {_sha(raw_a)}  {path_a}")
    print(f"B {_sha(raw_b)}  {path_b}")
    if raw_a == raw_b:
        print("BYTE-IDENTICAL")
        return True
    a, b = _entries(raw_a), _entries(raw_b)
    ok = True
    for name in sorted(set(a) | set(b)):
        if name not in a or name not in b:
            print(f"  missing in {'B' if name in a else 'A'}: {name}")
            ok = False
        elif a[name] == b[name]:
            continue
        elif name in LINE_ENDING_ONLY and a[name].replace(b"\r\n", b"\n") == b[name].replace(b"\r\n", b"\n"):
            print(f"  {name}: line endings only (CRLF vs LF)")
        elif name == "classes.jar":
            ca, cb = _entries(a[name]), _entries(b[name])
            for cls in sorted(set(ca) | set(cb)):
                if ca.get(cls) != cb.get(cls):
                    print(f"  classes.jar: {cls} differs")
            ok = False
        else:
            print(f"  {name}: content differs")
            ok = False
    print("EQUIVALENT" if ok else "DIFFERENT")
    return ok


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    sys.exit(0 if compare(sys.argv[1], sys.argv[2]) else 1)
