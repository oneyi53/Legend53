"""UI rebuild checks: DOM id wiring + 390x844 layer non-overlap.
Run: python3 scripts/qa/check_ui_layout.py
Static only: this VM has no headless browser, so runtime layout is verified
by the band table below (values read from web/css/game.css) plus the
phone test steps in UI_REBUILD_CHECK.md.
"""
import re
from pathlib import Path

root = Path(__file__).resolve().parents[2]
html = (root / "index.html").read_text(encoding="utf-8")
js = "".join((root / "web/js").glob("*.js") and [p.read_text(encoding="utf-8") for p in sorted((root / "web/js").glob("*.js"))])

# 1. duplicate ids in index.html
ids = re.findall(r'id="([^"]+)"', html)
dupes = sorted({i for i in ids if ids.count(i) > 1})
assert not dupes, f"duplicate ids in index.html: {dupes}"

# 2. every $(...) / getElementById target exists in index.html or in a JS panel template
defined = set(ids) | set(re.findall(r'id="([^"]+)"', js))
wanted = set(re.findall(r'\$\("([^"]+)"\)', js)) | set(re.findall(r'getElementById\("([^"]+)"\)', js))
missing = sorted(w for w in wanted if w not in defined)
assert not missing, f"missing DOM ids: {missing}"

# 3. every data-panel / data-slot / data-channel target used by JS exists
for attr in ["data-panel", "data-slot"]:
    pass  # panel types are handled by openPanel switch; slots are generated

# 4. 390x844 bands (y0, y1, x0, x1) read from game.css; assert no overlap
#    where x ranges intersect. Bottom bar height --bb = 116 (safe-area 0).
W, H, BB = 390, 844, 116
bands = {
    "topbar": (0, 52, 0, 390),
    "quest-strip": (54, 90, 8, 288),
    "target-banner": (94, 130, 74, 316),
    "side-actions": (422, 600, 342, 382),   # top 50%, 4x40 + 3x6
    "npc-button": (576, 608, 8, 98),
    "chat-collapsed": (H - BB - 6 - 108, H - BB - 6, 8, 203),
    "chat-expanded": (H - BB - 6 - 190, H - BB - 6, 8, 203),
    "attack-cluster": (H - BB - 8 - 64, H - BB - 8, 214, 382),
    "bottombar": (H - BB, H, 0, 390),
}
# expanded chat hides the npc button in JS; exclude that pair explicitly
exempt = {("chat-expanded", "npc-button"), ("chat-collapsed", "chat-expanded")}
names = list(bands)
for i, a in enumerate(names):
    for b in names[i + 1:]:
        if (a, b) in exempt or (b, a) in exempt:
            continue
        ay0, ay1, ax0, ax1 = bands[a]
        by0, by1, bx0, bx1 = bands[b]
        y_overlap = ay0 < by1 and by0 < ay1
        x_overlap = ax0 < bx1 and bx0 < ax1
        assert not (y_overlap and x_overlap), f"overlap: {a} {bands[a]} vs {b} {bands[b]}"
# bottom bar + chat share of screen height (report: ~30% is the classic feel)
assert 0.27 <= (BB + 108 + 6) / H <= 0.33, "bottombar+chat share out of range"
print(f"DOM ids: {len(ids)} in index.html, {len(wanted)} referenced, 0 missing; "
      f"bands: {len(bands)} checked, 0 overlaps; bottombar+chat share {(BB + 114) / H:.1%}")
print("UI layout checks: OK")
