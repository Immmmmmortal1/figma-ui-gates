#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf '%s\n' 'Usage: validate-g6-asset-binding.sh --workspace <dir> --source-root <root> [--report <path>]'
}

WORKSPACE=""; SOURCE_ROOT=""; REPORT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --workspace) WORKSPACE="${2:-}"; shift 2 ;;
    --source-root) SOURCE_ROOT="${2:-}"; shift 2 ;;
    --report) REPORT="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'Unknown argument: %s\n' "$1" >&2; exit 2 ;;
  esac
done
if [[ -z "$WORKSPACE" || -z "$SOURCE_ROOT" ]]; then usage >&2; exit 2; fi
if [[ ! -d "$WORKSPACE" || ! -d "$SOURCE_ROOT" ]]; then printf '%s\n' 'workspace/source root does not exist' >&2; exit 2; fi
if [[ -z "$REPORT" ]]; then REPORT="$WORKSPACE/gates/G6V-binding-validation.json"; fi

python3 - "$WORKSPACE" "$SOURCE_ROOT" "$REPORT" <<'PY'
import json
import re
import sys
from pathlib import Path

workspace, source_root, report_path = (Path(v).expanduser().resolve() for v in sys.argv[1:])
errors, checked = [], []

def load(path, label):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        print(f"missing {label}: {path}", file=sys.stderr); raise SystemExit(2)
    except json.JSONDecodeError as exc:
        print(f"invalid {label} JSON: {exc}", file=sys.stderr); raise SystemExit(2)

g2 = load(workspace / "gates" / "G2-detail.json", "G2")
g6 = load(workspace / "gates" / "G6-assets.json", "G6")
assets = g6.get("assets")
if not isinstance(assets, list):
    errors.append("assets must be an array")
    assets = []

def rows(payload):
    for key in ("units", "details", "nodes", "items"):
        if isinstance(payload.get(key), list):
            return payload[key]
    return []

g2_collapse = {
    str(row.get("figma_id")) for row in rows(g2)
    if isinstance(row, dict) and row.get("collapse") is True and row.get("figma_id")
}
if not assets and g2_collapse:
    errors.append("assets must be a non-empty array when G2 collapse set is non-empty")
g6_ids = {
    str(row.get("figma_id")) for row in assets
    if isinstance(row, dict) and row.get("collapse") is True and row.get("figma_id")
}
for missing in sorted(g2_collapse - g6_ids):
    errors.append(f"G2 collapse node missing from assets: {missing}")
for extra in sorted(g6_ids - g2_collapse):
    errors.append(f"assets contains node not declared collapse in G2: {extra}")

ignored = {".build", "build", "DerivedData", "Pods", ".devflow-ui", ".git"}
swift_text = {
    p: p.read_text(encoding="utf-8", errors="replace")
    for p in source_root.rglob("*.swift") if not any(part in ignored for part in p.parts)
}

def declared_names(row, label):
    single_present = "local_asset" in row
    plural_present = "local_assets" in row
    if single_present and plural_present:
        errors.append(f"{label}: local_asset and local_assets are mutually exclusive")
        return []
    if single_present:
        value = row["local_asset"]
        if not isinstance(value, str) or not value.strip():
            errors.append(f"{label}: local_asset must be a non-empty string")
            return []
        return [value.strip()]
    if plural_present:
        value = row["local_assets"]
        if not isinstance(value, list) or not value or any(not isinstance(v, str) or not v.strip() for v in value):
            errors.append(f"{label}: local_assets must be a non-empty string array")
            return []
        return [v.strip() for v in value]
    errors.append(f"{label}: collapse=true requires local_asset or local_assets")
    return []

def anchor_for(figma_id):
    return "figma." + "".join(ch if ch.isascii() and ch.isalnum() else "_" for ch in figma_id)

def runtime_detail(anchor):
    for path in sorted((workspace / "runtime").glob("*.json")):
        try: payload = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError): continue
        node = payload.get("node") if isinstance(payload.get("node"), dict) else payload
        if anchor in (payload.get("anchor"), payload.get("accessibilityIdentifier"), node.get("accessibilityIdentifier")):
            return path, node
    return None, None

if g6.get("status") != "pass": errors.append("G6 status must be pass")
for index, row in enumerate(assets):
    if not isinstance(row, dict):
        errors.append(f"assets[{index}] must be an object"); continue
    if row.get("collapse") is not True:
        if "nativeMapping" not in row or not isinstance(row.get("nativeMapping"), str) or not row["nativeMapping"].strip():
            errors.append(f"assets[{index}]: collapse=false requires nativeMapping")
        continue
    figma_id = row.get("figma_id")
    label = str(row.get("name") or figma_id or f"assets[{index}]")
    names = declared_names(row, label)
    item = {"figma_id": figma_id, "assets": names, "checks": []}
    checked.append(item)
    for name in names:
        literal = re.compile(r"(?P<q>['\"])" + re.escape(name) + r"(?P=q)")
        if any(literal.search(text) for text in swift_text.values()): item["checks"].append(f"literal:{name}:pass")
        else: errors.append(f"{label}: source lacks complete string literal '{name}'"); item["checks"].append(f"literal:{name}:fail")
    if not isinstance(figma_id, str) or not figma_id.strip():
        errors.append(f"{label}: collapsed row requires figma_id"); continue
    anchor = anchor_for(figma_id.strip())
    for path, text in swift_text.items():
        if anchor in text and re.search(r"override\s+func\s+draw\s*\(", text):
            errors.append(f"{label}: anchor binding file contains override func draw(: {path}")
    detail_path, node = runtime_detail(anchor)
    if node is None:
        errors.append(f"{label}: missing runtime detail for {anchor}"); continue
    class_name = node.get("className") or ""
    image_name, image_size, image_hash = node.get("imageAssetName"), node.get("imageSize"), node.get("imageHash")
    image_bearing = class_name in {"UIImageView", "UIButton", "UIControl"} or class_name.endswith(("ImageView", "Button"))
    if not image_bearing: errors.append(f"{label}: runtime class is not image-bearing: {class_name or '<missing>'}")
    if not image_name and not image_size and not image_hash: errors.append(f"{label}: runtime detail lacks image evidence")
    if image_name and names and image_name not in names: errors.append(f"{label}: runtime imageAssetName is not a declared local asset")
    item["runtime_detail"] = str(detail_path)

existing_path = workspace / "gates" / "G6V-binding-validation.json"
try: existing = json.loads(existing_path.read_text(encoding="utf-8"))
except (OSError, json.JSONDecodeError): existing = {}
g8 = load(workspace / "gates" / "G8-build.json", "G8")
report = {
    "gate": "G6V", "status": "pass" if not errors else "fail",
    "sequence": existing.get("sequence"), "recordedAt": existing.get("recordedAt"),
    "buildId": existing.get("buildId", g8.get("buildId")), "runtimeSamples": existing.get("runtimeSamples", [str(p) for p in sorted((workspace / "runtime").glob("*.json"))]),
    "evidence": [str(workspace / "gates" / "G6-assets.json")], "checks": checked, "errors": errors
}
report_path.parent.mkdir(parents=True, exist_ok=True)
report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
if errors:
    for error in errors: print(error, file=sys.stderr)
    raise SystemExit(1)
print(f"G6V binding: pass ({len(checked)} collapsed asset rows)")
PY
