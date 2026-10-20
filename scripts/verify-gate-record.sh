#!/usr/bin/env bash
set -euo pipefail

usage() { printf '%s\n' 'Usage: verify-gate-record.sh --workspace <dir> --source-root <root> [--report <path>]'; }
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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
if [[ -z "$REPORT" ]]; then REPORT="$WORKSPACE/gates/G12-final-verify.json"; fi
mkdir -p "$(dirname "$REPORT")"

python3 - "$WORKSPACE" "$SOURCE_ROOT" "$REPORT" "$SCRIPT_DIR/validate-g6-asset-binding.sh" <<'PY'
import datetime, json, re, subprocess, sys
from pathlib import Path

workspace, source_root, report_path, validator = map(lambda value: Path(value).resolve(), sys.argv[1:])
errors, checks = [], []

def load(path, label):
    try: return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError: errors.append(f"missing {label}: {path}")
    except json.JSONDecodeError as exc: errors.append(f"invalid JSON for {label}: {exc}")
    return None

def nonempty(value): return isinstance(value, str) and bool(value.strip())

def evidence(owner, payload):
    values = payload.get("evidence")
    if not isinstance(values, list) or not values:
        errors.append(f"{owner} evidence must be a non-empty array"); return
    for value in values:
        if not nonempty(value): errors.append(f"{owner} has invalid evidence path"); continue
        path = Path(value) if Path(value).is_absolute() else workspace / value
        if not path.exists(): errors.append(f"{owner} missing evidence path: {value}")

manifest = load(workspace / "manifest.json", "manifest")
if manifest:
    for field in ("fileKey", "rootNodeId", "version"):
        if not nonempty(manifest.get(field)): errors.append(f"manifest missing non-empty {field}")

preflight = load(workspace / "preflight.json", "preflight")
if preflight:
    if preflight.get("status") != "pass": errors.append("preflight status is not pass")
    rows = preflight.get("checks")
    if not isinstance(rows, list) or not rows: errors.append("preflight checks must be a non-empty array")
    else:
        for index, row in enumerate(rows):
            if not isinstance(row, dict) or not row.get("name") or row.get("status") != "pass":
                errors.append(f"preflight checks[{index}] requires name and status=pass")

git_probe = subprocess.run(["git", "-C", str(source_root), "rev-parse", "--is-inside-work-tree"], text=True, capture_output=True)
if git_probe.returncode == 0:
    ignored = subprocess.run(["git", "-C", str(source_root), "check-ignore", "-q", str(workspace)], capture_output=True)
    if ignored.returncode != 0: errors.append("artifact workspace is not git ignored")

sequence = [
    ("G0", "G0-scope.json"), ("G1", "G1-root-tree.json"), ("G2", "G2-detail.json"),
    ("G3", "G3-rest-evidence.json"), ("G4", "G4-classification.json"),
    ("G5", "G5-ordered-sweep.json"), ("G6", "G6-assets.json"),
    ("G7", "G7-implementation.json"), ("G8", "G8-build.json"),
    ("G6V", "G6V-binding-validation.json"), ("G7A", "G7A-runtime-review.json"),
    ("G7B", "G7B-parent-rollup.json"), ("G9", "G9-runtime-semantics.json"),
    ("G10", "G10-geometry-parity.json"), ("G11", "G11-final-review.json"),
]
payloads = {}
review_gates = ("G1", "G2", "G6", "G7A", "G7B", "G10", "G11")
iso = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$")

def review(gate):
    payload = load(workspace / "reviews" / f"{gate}.json", f"{gate} missing review")
    if payload is None: return
    if payload.get("gate") != gate: errors.append(f"review {gate} has wrong gate")
    reviewer = payload.get("reviewer")
    if not isinstance(reviewer, dict) or reviewer.get("kind") not in ("self", "subagent", "custom"):
        errors.append(f"review {gate} reviewer.kind is invalid")
    if not isinstance(reviewer, dict) or not nonempty(reviewer.get("id")): errors.append(f"review {gate} missing reviewer.id")
    if payload.get("verdict") != "pass": errors.append(f"review {gate} verdict is not pass")
    findings = payload.get("findings")
    if not isinstance(findings, list): errors.append(f"review {gate} findings must be an array")
    else:
        for index, finding in enumerate(findings):
            if not isinstance(finding, dict) or not nonempty(finding.get("id")): errors.append(f"review {gate} findings[{index}] missing id")
            if not isinstance(finding, dict) or finding.get("severity") not in ("blocking", "non-blocking"): errors.append(f"review {gate} findings[{index}] severity is invalid")
            if not isinstance(finding, dict) or not nonempty(finding.get("message")): errors.append(f"review {gate} findings[{index}] missing message")
    evidence(f"review {gate}", payload)
    if not isinstance(payload.get("at"), str) or not iso.match(payload["at"]): errors.append(f"review {gate} at must be ISO8601")
    if gate in ("G7A", "G7B"):
        parents = payload.get("parentResults")
        if not isinstance(parents, list) or not parents: errors.append(f"review {gate} parentResults must be a non-empty array")
        else:
            for index, parent in enumerate(parents):
                if not isinstance(parent, dict) or not nonempty(parent.get("parentId")): errors.append(f"review {gate} parentResults[{index}] missing parentId")
                if not isinstance(parent, dict) or not isinstance(parent.get("units"), list) or not parent["units"]: errors.append(f"review {gate} parentResults[{index}] units must be a non-empty array")
                if not isinstance(parent, dict) or parent.get("verdict") != "pass": errors.append(f"review {gate} parentResults[{index}] verdict is not pass")

def require(gate, payload, key, predicate, message):
    if key not in payload or not predicate(payload.get(key)): errors.append(f"gate {gate} {message}")

last_time = None
for expected_sequence, (gate, name) in enumerate(sequence, 1):
    if gate == "G6V":
        result = subprocess.run(["bash", str(validator), "--workspace", str(workspace), "--source-root", str(source_root)], text=True, capture_output=True)
        if result.returncode:
            errors.append(f"G6V asset binding validation failed: {result.stderr.strip() or result.stdout.strip() or 'validator failed'}")
            checks.append({"name": "G6V-validator", "status": "fail"}); break
        checks.append({"name": "G6V-validator", "status": "pass"})
    payload = load(workspace / "gates" / name, f"gate {gate}")
    if payload is None: break
    payloads[gate] = payload
    before = len(errors)
    if payload.get("gate") != gate: errors.append(f"gate {gate} record has wrong gate")
    if payload.get("status") != "pass": errors.append(f"gate {gate} status is not pass")
    if payload.get("sequence") != expected_sequence: errors.append(f"gate {gate} sequence is not continuous: expected {expected_sequence}")
    recorded = payload.get("recordedAt")
    if not isinstance(recorded, str) or not iso.match(recorded): errors.append(f"gate {gate} recordedAt must be ISO8601")
    else:
        moment = datetime.datetime.fromisoformat(recorded.replace("Z", "+00:00"))
        if last_time is not None and moment < last_time: errors.append(f"gate {gate} recordedAt is earlier than previous gate")
        last_time = moment
    evidence(f"gate {gate}", payload)
    if gate == "G0":
        for key in ("fileKey", "rootNodeId", "version"): require(gate, payload, key, nonempty, f"{key} must be non-empty")
    if gate == "G1": require(gate, payload, "structureArtifact", nonempty, "structureArtifact must be non-empty")
    if gate == "G2": require(gate, payload, "units", lambda v: isinstance(v, list) and v, "units must be a non-empty array")
    if gate == "G3": require(gate, payload, "figmaVersion", nonempty, "figmaVersion must be non-empty")
    if gate == "G4": require(gate, payload, "containerClass", nonempty, "containerClass must be non-empty")
    if gate == "G5": require(gate, payload, "groups", lambda v: isinstance(v, list) and v, "groups must be a non-empty array")
    if gate == "G7": require(gate, payload, "changedFiles", lambda v: isinstance(v, list) and v, "changedFiles must be a non-empty array")
    if gate == "G8":
        require(gate, payload, "exitCode", lambda v: type(v) is int and v == 0, "exitCode must equal 0")
        require(gate, payload, "buildId", nonempty, "buildId must be non-empty")
        require(gate, payload, "productPath", lambda v: nonempty(v) and (Path(v) if Path(v).is_absolute() else workspace / v).exists(), "productPath must exist")
        require(gate, payload, "launchedAt", nonempty, "launchedAt must be non-empty")
    if gate == "G6V":
        if payload.get("buildId") != payloads.get("G8", {}).get("buildId"): errors.append("gate G6V buildId must equal G8 buildId")
        require(gate, payload, "runtimeSamples", lambda v: isinstance(v, list) and v, "runtimeSamples must be a non-empty array")
    if gate == "G7A":
        require(gate, payload, "buildId", nonempty, "buildId must be non-empty")
        require(gate, payload, "launchedAt", nonempty, "launchedAt must be non-empty")
        if payload.get("buildId") != payloads.get("G8", {}).get("buildId"): errors.append("gate G7A buildId must equal G8 buildId")
        if payload.get("launchedAt") != payloads.get("G8", {}).get("launchedAt"): errors.append("gate G7A launchedAt must equal G8 launchedAt")
    if gate == "G9":
        require(gate, payload, "pageId", nonempty, "pageId must be non-empty")
        require(gate, payload, "anchorsChecked", lambda v: type(v) is int and v > 0, "anchorsChecked must be > 0")
        require(gate, payload, "scrollOwnerCount", lambda v: type(v) is int and v == 1, "scrollOwnerCount must equal 1")
    if gate == "G10":
        profiles = payload.get("profiles")
        declared = payload.get("unobservable", [])
        if not isinstance(declared, list):
            errors.append("gate G10 unobservable must be an array"); declared = []
        declared_keys = set()
        for index, row in enumerate(declared):
            if not isinstance(row, dict) or not all(nonempty(row.get(key)) for key in ("unit", "assertion", "missingCapability")):
                errors.append(f"gate G10 unobservable[{index}] requires unit, assertion, and missingCapability")
            else:
                declared_keys.add((row["unit"], row["assertion"]))
        observed_unavailable = set()
        if not isinstance(profiles, list) or len(profiles) < 2: errors.append("gate G10 profiles must contain at least 2 profiles")
        else:
            ids, widths, unit_sets = [], [], []
            for index, profile in enumerate(profiles):
                if not isinstance(profile, dict) or not nonempty(profile.get("id")): errors.append(f"gate G10 profiles[{index}] id must be non-empty"); continue
                ids.append(profile["id"]); widths.append(profile.get("width"))
                units = profile.get("units")
                if not isinstance(units, list) or not units: errors.append(f"gate G10 profiles[{index}] units must be non-empty"); continue
                unit_sets.append({str(unit.get("figma_id") if isinstance(unit, dict) else unit) for unit in units})
                for unit in units:
                    if not isinstance(unit, dict): continue
                    unit_id = str(unit.get("figma_id", ""))
                    assertions = unit.get("assertions", [])
                    if assertions is not None and not isinstance(assertions, list):
                        errors.append(f"gate G10 unit {unit_id} assertions must be an array"); continue
                    for assertion in assertions or []:
                        if not isinstance(assertion, dict) or not nonempty(assertion.get("assertion")):
                            errors.append(f"gate G10 unit {unit_id} has invalid assertion"); continue
                        name = assertion["assertion"]
                        if assertion.get("status") == "unobservable": observed_unavailable.add((unit_id, name))
                        if name in ("textColor", "backgroundColor") and assertion.get("status") != "unobservable":
                            expected_color, measured_color = assertion.get("expected"), assertion.get("measured")
                            tolerance = assertion.get("colorChannel")
                            channels = ("red", "green", "blue", "alpha")
                            valid = all(isinstance(color, dict) and all(type(color.get(ch)) in (int, float) and 0 <= color[ch] <= 1 for ch in channels) for color in (expected_color, measured_color))
                            if not valid or type(tolerance) is not int or not 0 <= tolerance <= 255:
                                errors.append(f"gate G10 unit {unit_id} {name} has invalid 0..1 color evidence")
                            elif any(abs(round(expected_color[ch] * 255) - round(measured_color[ch] * 255)) > tolerance for ch in channels):
                                errors.append(f"gate G10 unit {unit_id} {name} exceeds colorChannel tolerance")
            if len(ids) != len(set(ids)): errors.append("gate G10 profile ids must be unique")
            if any(type(width) is not int or width <= 0 for width in widths): errors.append("gate G10 profile widths must be positive integers")
            if len(widths) != len(set(widths)): errors.append("gate G10 profile widths must be different")
            expected = {str(unit.get("figma_id")) for unit in payloads.get("G2", {}).get("units", []) if isinstance(unit, dict) and unit.get("figma_id")}
            if unit_sets and any(unit_set != expected for unit_set in unit_sets): errors.append("gate G10 profile units coverage must equal G2 units and be consistent")
        if observed_unavailable != declared_keys:
            missing = observed_unavailable - declared_keys
            extra = declared_keys - observed_unavailable
            if missing: errors.append(f"gate G10 unobservable missing corresponding entries: {sorted(missing)}")
            if extra: errors.append(f"gate G10 unobservable has no corresponding assertion: {sorted(extra)}")
    if gate in ("G3", "G10") and manifest and payload.get("figmaVersion") != manifest.get("version"): errors.append(f"manifest.version and {gate} figmaVersion mismatch")
    if gate in review_gates: review(gate)
    checks.append({"name": f"gate-{gate}", "status": "pass" if len(errors) == before else "fail"})
    if len(errors) != before: break

checks.append({"name": "reviews", "status": "pass" if not any("review" in e for e in errors) else "fail"})
checks.append({"name": "figma-version", "status": "pass" if not any("figmaVersion" in e for e in errors) else "fail"})
report = {"gate": "G12", "status": "pass" if not errors else "fail", "checks": checks, "evidence": [str(workspace / "manifest.json")], "errors": errors}
report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
if errors:
    for error in errors: print(f"verify: {error}", file=sys.stderr)
    raise SystemExit(1)
print(f"verify: pass ({len(sequence)} gate records, {len(review_gates)} reviews)")
PY
