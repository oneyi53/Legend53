from pathlib import Path
import re
root=Path(__file__).resolve().parents[2]
html=(root/"index.html").read_text(encoding="utf-8")
assert '<script type="module" src="./web/js/main.js"></script>' in html
assert 'href="./web/css/game.css"' in html
for asset in re.findall(r'(?:src|href)="(\./[^"]+)"',html):
    if asset.startswith("./assets/") or asset.startswith("./web/"):
        assert (root/asset[2:]).is_file(), f"Missing referenced asset: {asset}"
for required in ["web/js/data.js","web/js/storage.js","web/js/input.js","web/js/game.js","web/js/renderer.js","web/js/main.js"]:
    assert (root/required).is_file(), f"Missing module: {required}"
print("HTML5 entry point and local asset references: OK")
