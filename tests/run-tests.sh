#!/usr/bin/env bash
set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$TEST_DIR/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/figma-ui-gates-tests.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
PASS_COUNT=0; FAIL_COUNT=0; LAST_OUTPUT=""

expect() {
  local name="$1" expected="$2" keyword="$3"; shift 3
  set +e
  LAST_OUTPUT="$("$@" 2>&1)"; local code=$?
  set -e
  local ok=0
  if [[ "$expected" == pass && $code -eq 0 ]] || [[ "$expected" == fail && $code -ne 0 ]]; then ok=1; fi
  if [[ -n "$keyword" && "$LAST_OUTPUT" != *"$keyword"* ]]; then ok=0; fi
  if [[ $ok -eq 1 ]]; then printf 'PASS: %s\n' "$name"; PASS_COUNT=$((PASS_COUNT + 1));
  else printf 'FAIL: %s (exit=%s, keyword=%s)\n%s\n' "$name" "$code" "$keyword" "$LAST_OUTPUT"; FAIL_COUNT=$((FAIL_COUNT + 1)); fi
}

json_set() { python3 - "$@" <<'PY'
import json, sys
p, expression = sys.argv[1:]
d=json.load(open(p)); exec(expression, {"d":d}); json.dump(d,open(p,"w"))
PY
}

make_workspace() {
  local root="$1" asset="$2"
  mkdir -p "$root/workspace/gates" "$root/workspace/reviews" "$root/workspace/runtime" "$root/workspace/evidence" "$root/workspace/product" "$root/source"
  printf '{}\n' > "$root/workspace/evidence/proof.json"
  printf 'app\n' > "$root/workspace/product/App.app"
  printf '{"fileKey":"file","rootNodeId":"1:2","version":"v1"}\n' > "$root/workspace/manifest.json"
  printf '{"status":"pass","checks":[{"name":"ready","status":"pass"}]}\n' > "$root/workspace/preflight.json"
  local entries=(G0:G0-scope G1:G1-root-tree G2:G2-detail G3:G3-rest-evidence G4:G4-classification G5:G5-ordered-sweep G6:G6-assets G7:G7-implementation G8:G8-build G6V:G6V-binding-validation G7A:G7A-runtime-review G7B:G7B-parent-rollup G9:G9-runtime-semantics G10:G10-geometry-parity G11:G11-final-review)
  local i=0 gate name
  for entry in "${entries[@]}"; do
    i=$((i+1)); gate="${entry%%:*}"; name="${entry#*:}"
    printf '{"gate":"%s","status":"pass","sequence":%d,"recordedAt":"2026-10-20T00:%02d:00Z","evidence":["evidence/proof.json"]}\n' "$gate" "$i" "$i" > "$root/workspace/gates/$name.json"
  done
  json_set "$root/workspace/gates/G0-scope.json" 'd.update(fileKey="file",rootNodeId="1:2",version="v1")'
  json_set "$root/workspace/gates/G1-root-tree.json" 'd.update(structureArtifact="evidence/proof.json")'
  json_set "$root/workspace/gates/G2-detail.json" 'd.update(units=[{"figma_id":"1:2","collapse":True}])'
  json_set "$root/workspace/gates/G3-rest-evidence.json" 'd.update(figmaVersion="v1")'
  json_set "$root/workspace/gates/G4-classification.json" 'd.update(containerClass="UIScrollView")'
  json_set "$root/workspace/gates/G5-ordered-sweep.json" 'd.update(groups=["1:2"])'
  json_set "$root/workspace/gates/G6-assets.json" "d.update(assets=[{'figma_id':'1:2','collapse':True,'local_asset':'$asset','reason':'fixture'}])"
  json_set "$root/workspace/gates/G7-implementation.json" 'd.update(changedFiles=["App.swift"])'
  json_set "$root/workspace/gates/G8-build.json" 'd.update(exitCode=0,buildId="build-1",productPath="product/App.app",launchedAt="2026-10-20T00:09:30Z")'
  json_set "$root/workspace/gates/G6V-binding-validation.json" 'd.update(buildId="build-1",runtimeSamples=["runtime/unit.json"])'
  json_set "$root/workspace/gates/G7A-runtime-review.json" 'd.update(buildId="build-1",launchedAt="2026-10-20T00:09:30Z")'
  json_set "$root/workspace/gates/G9-runtime-semantics.json" 'd.update(pageId="page",anchorsChecked=1,scrollOwnerCount=1)'
  json_set "$root/workspace/gates/G10-geometry-parity.json" 'd.update(figmaVersion="v1",unobservable=[],profiles=[{"id":"primary","width":402,"units":[{"figma_id":"1:2","assertions":[{"assertion":"textColor","status":"pass","expected":{"red":0.1,"green":0.2,"blue":0.3,"alpha":1.0},"measured":{"red":0.101,"green":0.2,"blue":0.3,"alpha":1.0},"colorChannel":1}]}]},{"id":"secondary","width":393,"units":[{"figma_id":"1:2","assertions":[]}]}])'
  local reviews=(G1 G2 G6 G7A G7B G10 G11)
  for gate in "${reviews[@]}"; do
    if [[ "$gate" == G7A || "$gate" == G7B ]]; then
      printf '{"gate":"%s","reviewer":{"kind":"self","id":"fixture"},"verdict":"pass","findings":[],"parentResults":[{"parentId":"parent","units":["1:2"],"verdict":"pass"}],"evidence":["evidence/proof.json"],"at":"2026-10-20T00:30:00Z"}\n' "$gate" > "$root/workspace/reviews/$gate.json"
    else
      printf '{"gate":"%s","reviewer":{"kind":"self","id":"fixture"},"verdict":"pass","findings":[],"evidence":["evidence/proof.json"],"at":"2026-10-20T00:30:00Z"}\n' "$gate" > "$root/workspace/reviews/$gate.json"
    fi
  done
  printf '{"anchor":"figma.1_2","node":{"className":"UIImageView","accessibilityIdentifier":"figma.1_2","imageAssetName":"%s","imageHash":"abc","imageSize":{"width":10,"height":10}}}\n' "$asset" > "$root/workspace/runtime/unit.json"
  printf 'let image = "%s"\n' "$asset" > "$root/source/App.swift"
}

VERIFY=(bash "$SKILL_DIR/scripts/verify-gate-record.sh")
VALIDATE=(bash "$SKILL_DIR/scripts/validate-g6-asset-binding.sh")

# 1 turns red if a required reviewed-gate record is accepted when absent.
c="$TMP/1"; make_workspace "$c" a; rm "$c/workspace/reviews/G2.json"; expect "1 missing G2 review" fail "G2 missing review" "${VERIFY[@]}" --workspace "$c/workspace" --source-root "$c/source"
# 2 turns red if a non-pass review verdict is ignored.
c="$TMP/2"; make_workspace "$c" a; json_set "$c/workspace/reviews/G2.json" 'd["verdict"]="fail"'; expect "2 failed verdict" fail "verdict" "${VERIFY[@]}" --workspace "$c/workspace" --source-root "$c/source"
# 3 turns red if gate status is not checked.
c="$TMP/3"; make_workspace "$c" a; json_set "$c/workspace/gates/G4-classification.json" 'd["status"]="fail"'; expect "3 failed gate status" fail "status" "${VERIFY[@]}" --workspace "$c/workspace" --source-root "$c/source"
# 4 turns red if missing Swift asset literals are accepted.
c="$TMP/4"; make_workspace "$c" wanted; printf 'let image = "other"\n' > "$c/source/App.swift"; expect "4 missing asset literal" fail "source lacks" "${VALIDATE[@]}" --workspace "$c/workspace" --source-root "$c/source"
# 5 turns red if literals inside arrays are not recognized.
c="$TMP/5"; make_workspace "$c" wanted; printf 'let images = ["wanted", "other"]\n' > "$c/source/App.swift"; expect "5 array asset literal" pass "G6V binding: pass" "${VALIDATE[@]}" --workspace "$c/workspace" --source-root "$c/source"
# 6 turns red if collapse rows can omit local asset declarations.
c="$TMP/6"; make_workspace "$c" a; json_set "$c/workspace/gates/G6-assets.json" 'd["assets"]=[{"figma_id":"1:2","collapse":True}]'; expect "6 collapse missing local asset" fail "requires local_asset" "${VALIDATE[@]}" --workspace "$c/workspace" --source-root "$c/source"
# 7 turns red if empty assets are accepted while G2 has collapsed units.
c="$TMP/7"; make_workspace "$c" a; json_set "$c/workspace/gates/G6-assets.json" 'd["assets"]=[]'; expect "7 empty assets with collapse" fail "non-empty array" "${VALIDATE[@]}" --workspace "$c/workspace" --source-root "$c/source"
# 8 turns red if a non-array assets value is accepted.
c="$TMP/8"; make_workspace "$c" a; json_set "$c/workspace/gates/G6-assets.json" 'd["assets"]={}'; expect "8 assets wrong type" fail "must be an array" "${VALIDATE[@]}" --workspace "$c/workspace" --source-root "$c/source"
# 9 turns red if local_assets accepts a scalar.
c="$TMP/9"; make_workspace "$c" a; json_set "$c/workspace/gates/G6-assets.json" 'd["assets"]=[{"figma_id":"1:2","collapse":True,"local_assets":"a"}]'; expect "9 local_assets wrong type" fail "string array" "${VALIDATE[@]}" --workspace "$c/workspace" --source-root "$c/source"
# 10 turns red if reviewer identity is optional.
c="$TMP/10"; make_workspace "$c" a; json_set "$c/workspace/reviews/G2.json" 'd["reviewer"].pop("id")'; expect "10 missing reviewer id" fail "reviewer.id" "${VERIFY[@]}" --workspace "$c/workspace" --source-root "$c/source"
# 11 turns red if manifest/G3 version drift is ignored.
c="$TMP/11"; make_workspace "$c" a; json_set "$c/workspace/gates/G3-rest-evidence.json" 'd["figmaVersion"]="v2"'; expect "11 G3 version mismatch" fail "figmaVersion mismatch" "${VERIFY[@]}" --workspace "$c/workspace" --source-root "$c/source"
# 12 turns red if subagent mode resolves without an agent.
printf '{"build":{"workspace":"A.xcworkspace","derivedDataPath":".build","scheme":"A"},"review":{"nodeGate":{"mode":"subagent"}}}\n' > "$TMP/bad-subagent.json"; expect "12 subagent missing agent" fail "required" python3 "$SKILL_DIR/scripts/resolve-config.py" "$TMP/bad-subagent.json"
# 13 turns red if command verifier mode accepts an empty command.
printf '{"build":{"workspace":"A.xcworkspace","derivedDataPath":".build","scheme":"A"},"finalVerifier":{"mode":"command","command":""}}\n' > "$TMP/bad-command.json"; expect "13 empty verifier command" fail "non-empty" python3 "$SKILL_DIR/scripts/resolve-config.py" "$TMP/bad-command.json"
# 14 turns red if the complete valid gate/review baseline does not pass.
c="$TMP/14"; make_workspace "$c" a; expect "14 complete baseline" pass "verify: pass" "${VERIFY[@]}" --workspace "$c/workspace" --source-root "$c/source"
# 15 turns red if G8 can omit exitCode.
c="$TMP/15"; make_workspace "$c" a; json_set "$c/workspace/gates/G8-build.json" 'd.pop("exitCode")'; expect "15 G8 missing exitCode" fail "exitCode" "${VERIFY[@]}" --workspace "$c/workspace" --source-root "$c/source"
# 16 turns red if G10 accepts fewer than two profiles.
c="$TMP/16"; make_workspace "$c" a; json_set "$c/workspace/gates/G10-geometry-parity.json" 'd["profiles"]=d["profiles"][:1]'; expect "16 one profile" fail "at least 2 profiles" "${VERIFY[@]}" --workspace "$c/workspace" --source-root "$c/source"
# 17 turns red if profile unit coverage differs.
c="$TMP/17"; make_workspace "$c" a; json_set "$c/workspace/gates/G10-geometry-parity.json" 'd["profiles"][1]["units"]=[{"figma_id":"other"}]'; expect "17 profile coverage mismatch" fail "coverage" "${VERIFY[@]}" --workspace "$c/workspace" --source-root "$c/source"
# 18 turns red if G6V is detached from the G8 build.
c="$TMP/18"; make_workspace "$c" a; json_set "$c/workspace/gates/G6V-binding-validation.json" 'd["buildId"]="other"'; expect "18 G6V build mismatch" fail "buildId must equal" "${VERIFY[@]}" --workspace "$c/workspace" --source-root "$c/source"
# 19 turns red if review evidence is absent.
c="$TMP/19"; make_workspace "$c" a; json_set "$c/workspace/reviews/G2.json" 'd.pop("evidence")'; expect "19 review missing evidence" fail "evidence" "${VERIFY[@]}" --workspace "$c/workspace" --source-root "$c/source"
# 20 turns red if a finding can omit message.
c="$TMP/20"; make_workspace "$c" a; json_set "$c/workspace/reviews/G2.json" 'd["findings"]=[{"id":"F1","severity":"blocking"}]'; expect "20 finding missing message" fail "missing message" "${VERIFY[@]}" --workspace "$c/workspace" --source-root "$c/source"
# 21 turns red if sequence has a gap.
c="$TMP/21"; make_workspace "$c" a; json_set "$c/workspace/gates/G4-classification.json" 'd["sequence"]=99'; expect "21 sequence discontinuity" fail "sequence is not continuous" "${VERIFY[@]}" --workspace "$c/workspace" --source-root "$c/source"
# 22 turns red if recordedAt goes backwards.
c="$TMP/22"; make_workspace "$c" a; json_set "$c/workspace/gates/G4-classification.json" 'd["recordedAt"]="2026-10-19T00:00:00Z"'; expect "22 recordedAt reverse" fail "earlier than previous" "${VERIFY[@]}" --workspace "$c/workspace" --source-root "$c/source"
# 23 turns red if empty assets are rejected when G2 collapse set is empty.
c="$TMP/23"; make_workspace "$c" a; json_set "$c/workspace/gates/G2-detail.json" 'd["units"]=[{"figma_id":"1:2","collapse":False}]'; json_set "$c/workspace/gates/G6-assets.json" 'd["assets"]=[]'; expect "23 empty assets allowed" pass "G6V binding: pass" "${VALIDATE[@]}" --workspace "$c/workspace" --source-root "$c/source"
# 24 turns red if collapse=false can omit nativeMapping.
c="$TMP/24"; make_workspace "$c" a; json_set "$c/workspace/gates/G2-detail.json" 'd["units"]=[{"figma_id":"1:2","collapse":False}]'; json_set "$c/workspace/gates/G6-assets.json" 'd["assets"]=[{"figma_id":"1:2","collapse":False}]'; expect "24 split missing native mapping" fail "nativeMapping" "${VALIDATE[@]}" --workspace "$c/workspace" --source-root "$c/source"
# 25 turns red if an empty build.scheme is accepted.
printf '{"build":{"workspace":"A.xcworkspace","derivedDataPath":".build","scheme":""}}\n' > "$TMP/empty-scheme.json"; expect "25 empty scheme" fail "必须配置 build.scheme" python3 "$SKILL_DIR/scripts/resolve-config.py" "$TMP/empty-scheme.json"
# 26 turns red if a non-URI bridge baseUrl is accepted.
printf '{"runtime":{"bridge":{"baseUrl":"not-a-uri"}},"build":{"workspace":"A.xcworkspace","derivedDataPath":".build","scheme":"A"}}\n' > "$TMP/bad-uri.json"; expect "26 invalid URI" fail "http:// or https:// URI" python3 "$SKILL_DIR/scripts/resolve-config.py" "$TMP/bad-uri.json"
# 27 turns red if colorChannel outside 0...255 is accepted.
printf '{"build":{"workspace":"A.xcworkspace","derivedDataPath":".build","scheme":"A"},"evidence":{"tolerances":{"colorChannel":999}}}\n' > "$TMP/bad-color.json"; expect "27 invalid color channel" fail "colorChannel must be <= 255" python3 "$SKILL_DIR/scripts/resolve-config.py" "$TMP/bad-color.json"
# 28 turns red if device runtime can omit deviceId.
printf '{"runtime":{"target":"device"},"build":{"workspace":"A.xcworkspace","derivedDataPath":".build","scheme":"A","destination":"platform=iOS,id=abc"},"evidence":{"profiles":[{"id":"a","width":402,"destination":"platform=iOS,id=abc"},{"id":"b","width":393,"destination":"platform=iOS,id=def"}]}}\n' > "$TMP/device-no-id.json"; expect "28 device missing id" fail "deviceId" python3 "$SKILL_DIR/scripts/resolve-config.py" "$TMP/device-no-id.json"
# 29 turns red if workspace and project are both empty.
printf '{"build":{"scheme":"A","derivedDataPath":".build"}}\n' > "$TMP/no-project.json"; expect "29 no project source" fail "exactly one non-empty" python3 "$SKILL_DIR/scripts/resolve-config.py" "$TMP/no-project.json"
# 30 turns red if defaults falsely resolve without project build configuration.
expect "30 defaults blocked" fail "必须配置 build.scheme" python3 "$SKILL_DIR/scripts/resolve-config.py"

# 31 turns red if hash identity accepts a bridge capability set without imageHash.
printf '{"nodeFields":["imageAssetName"]}\n' > "$TMP/caps-no-hash.json"
printf '{"build":{"workspace":"A.xcworkspace","derivedDataPath":".build","scheme":"A"},"evidence":{"imageIdentity":"hash"}}\n' > "$TMP/hash-mode.json"
expect "31 hash mode requires imageHash" fail "supports imageHash" python3 "$SKILL_DIR/scripts/resolve-config.py" "$TMP/hash-mode.json" --capabilities "$TMP/caps-no-hash.json"
# 32 turns red if assetName=null cannot be represented as an accepted explicit G10 unobservable assertion.
c="$TMP/32"; make_workspace "$c" a; json_set "$c/workspace/gates/G10-geometry-parity.json" 'd["unobservable"]=[{"unit":"1:2","assertion":"imageIdentity","missingCapability":"imageAssetName"}]; d["profiles"][0]["units"][0]["assertions"].append({"assertion":"imageIdentity","status":"unobservable"})'; expect "32 assetName null explicit unobservable" pass "verify: pass" "${VERIFY[@]}" --workspace "$c/workspace" --source-root "$c/source"
# 33 turns red if an unobservable assertion has no corresponding top-level entry.
c="$TMP/33"; make_workspace "$c" a; json_set "$c/workspace/gates/G10-geometry-parity.json" 'd["profiles"][0]["units"][0]["assertions"].append({"assertion":"imageIdentity","status":"unobservable"})'; expect "33 missing unobservable record" fail "missing corresponding entries" "${VERIFY[@]}" --workspace "$c/workspace" --source-root "$c/source"
# 34 turns red if G7A is detached from the G8 build.
c="$TMP/34"; make_workspace "$c" a; json_set "$c/workspace/gates/G7A-runtime-review.json" 'd["buildId"]="other"'; expect "34 G7A build mismatch" fail "G7A buildId must equal" "${VERIFY[@]}" --workspace "$c/workspace" --source-root "$c/source"
# 35 baseline proves 0..1 colors normalize within tolerance; mutation turns red only after normalized delta exceeds colorChannel.
c="$TMP/35"; make_workspace "$c" a; json_set "$c/workspace/gates/G10-geometry-parity.json" 'd["profiles"][0]["units"][0]["assertions"][0]["measured"]["red"]=0.11'; expect "35 normalized color over tolerance" fail "exceeds colorChannel" "${VERIFY[@]}" --workspace "$c/workspace" --source-root "$c/source"

printf 'TOTAL: %d passed, %d failed\n' "$PASS_COUNT" "$FAIL_COUNT"
[[ "$FAIL_COUNT" -eq 0 ]]
