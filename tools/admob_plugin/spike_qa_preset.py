"""TASK/040 spike QA export: turn preset.0 ("Android", the debug TEST-ad preset) into the
ads_device QA export IN PLACE. The caller (spike_qa_export.sh) backs the file up and
restores it byte-identically afterwards.

Only preset.0 is touched: tools/* is no longer excluded (the ads_device harness lives
there) and the export path points at the QA APK. The package must ALREADY be the QA
identity (com.obappstudio.squishymerge.qa) -- anything else fails closed, so the spike
can never be exported under the production package id.
"""
import re
import sys

QA_PACKAGE = "com.obappstudio.squishymerge.qa"
path, export_path = sys.argv[1], sys.argv[2]
text = open(path, "rb").read().decode("utf-8")
start = text.index("[preset.0]")
end = text.index("[preset.1]") if "[preset.1]" in text else len(text)
block = text[start:end]
if 'name="Android"' not in block:
    raise SystemExit("preset.0 is not the 'Android' debug preset")
if not re.search(r'^package/unique_name="%s"$' % re.escape(QA_PACKAGE), block, flags=re.M):
    raise SystemExit("preset.0 package/unique_name is not %s -- refusing (QA only)" % QA_PACKAGE)


def sub(pattern, repl, s):
    new, n = re.subn(pattern, repl, s, count=1, flags=re.M)
    if n != 1:
        raise SystemExit("pattern not found exactly once in preset.0: %s" % pattern)
    return new


block = sub(r'^exclude_filter="[^"]*"', 'exclude_filter="_visual_source/*, docs/*, build/*, *.md, *.py"', block)
block = sub(r'^export_path="[^"]*"', 'export_path="%s"' % export_path, block)
open(path, "wb").write((text[:start] + block + text[end:]).encode("utf-8"))
for line in block.splitlines():
    if line.startswith(("name=", "exclude_filter=", "export_path=", "package/unique_name=")):
        print("preset.0", line)
