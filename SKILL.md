---
name: figma-ui-gates
description: Orchestrate the self-contained Figma-driven iOS UI gates G0-G12, including G7A/G7B, with configurable reviewers, runtime geometry evidence, and simulator or device execution.
---

# Figma UI Gates

## Scope

This skill covers one-time implementation and geometric acceptance of a newly created UI from
Figma. Business states such as loading, empty, error, retry, offline, and permission are owned by
the target project's approved requirements and `ui-review`; this skill does not duplicate them,
and their absence is not by itself a blocker here.

Shortest and tallest viewport coverage comes from `evidence.profiles`. Short/long-content coverage
requires a project data fixture. If none is provided, G9 records `n/a` and the reason; that absence
alone is not blocked.

This skill owns new Figma-driven iOS UI implementation. Existing-screen parity remains owned by
`ui-review`. `SKILL_DIR` means the directory containing this file; every bundled rule and script is
resolved relative to it.

Use this sequence without skipping or reordering:

```text
preflight → G0 scope → G1 root tree → G2 detail → G3 REST evidence
→ G4 classification/container → G5 ordered sweep → G6 asset declaration
→ G7 implementation → G8 build + launch → G6V asset binding validation
→ G7A unit runtime review → G7B parent rollup review
→ G9 runtime semantics → G10 geometry parity → G11 final review → G12 final verify
```

A failed or blocked gate stops the sequence. A gate is not passed by a prose summary.

State chain and verifier order are identical:

| Order | State required before advancing |
|---|---|
| preflight, G0, G1, G2, G3, G4, G5, G6, G7, G8 | `pass` in listed order |
| G6V, G7A, G7B, G9, G10, G11, G12 | `pass` in listed order |

At the first missing, failed, or blocked state, stop; later records cannot compensate for it.

## Dependencies and ownership

- `figma-rest-api` is the read-only design data source.
- A reviewer adapter performs configured node and final reviews: current-agent self review, a child
  agent, or a custom command.
- DebugBridge supplies UI actions, UIWindow/UIView hierarchy, runtime nodes, geometry, and current-run
  App logs.
- XcodeBuildMCP builds and launches the configured simulator or device target.
- The resolved `build` configuration supplies the executable build command; this skill provides
  the default final verifier.

## Configuration

The optional configuration is `<project>/.devflow-ui/figma-ui-gates.config.json`. First merge the
optional partial file with built-in defaults by running `scripts/resolve-config.py`; then validate
the complete result against `${SKILL_DIR}/config.schema.json`.

```json
{
  "artifacts": { "root": ".devflow-ui" },
  "runtime": {
    "target": "simulator",
    "deviceId": null,
    "bridge": { "baseUrl": "http://127.0.0.1:37777" }
  },
  "build": {
    "command": "xcodebuild {workspace|project} -scheme {scheme} -configuration {configuration} -derivedDataPath {derivedDataPath} -destination {destination} build",
    "scheme": "",
    "workspace": null,
    "project": null,
    "configuration": "Debug",
    "derivedDataPath": null,
    "destination": "platform=iOS Simulator,name=iPhone 16"
  },
  "review": {
    "nodeGate": { "mode": "self" },
    "finalGate": { "mode": "subagent", "agent": "ui-reviewer" },
    "requireIndependentNodeGate": false
  },
  "evidence": {
    "mode": "runtime-geometry",
    "imageIdentity": "assetName",
    "tolerances": {
      "origin": 0.5,
      "size": 0.5,
      "font": 0.1,
      "colorChannel": 1,
      "radius": 0.5
    },
    "profiles": [
      { "id": "primary", "width": 402, "destination": "platform=iOS Simulator,name=iPhone 16 Pro" },
      { "id": "secondary", "width": 393, "destination": "platform=iOS Simulator,name=iPhone 16" }
    ]
  },
  "finalVerifier": { "mode": "builtin", "command": "" }
}
```

- `artifacts.root` is project-relative unless absolute and defaults to `.devflow-ui`.
- `runtime.target` is `simulator | device`, default `simulator`; `runtime.bridge.baseUrl` selects the
  DebugBridge endpoint. Device mode requires `runtime.deviceId`.
- `build.command` is a non-empty complete command or template using
  `{workspace|project}/{scheme}/{configuration}/{derivedDataPath}/{destination}`. The first token
  resolves to `-workspace <path>` or `-project <path>`. Preflight must resolve it
  to one executable command; an unresolved or absent command is blocked.
- `review.nodeGate.mode` is `self | subagent | custom`, default `self` (the current executing agent).
- `review.finalGate.mode` is `self | subagent | custom`, default `subagent`; its default `agent` is
  `ui-reviewer`.
- A reviewer in `custom` mode carries its own non-empty `command`; a reviewer in `subagent` mode
  carries a non-empty `agent`.
- If `review.requireIndependentNodeGate` is `true`, `review.nodeGate.mode` must not be `self`.
- `evidence.mode` only permits `runtime-geometry`. Tolerances are in points except `colorChannel`,
  which is a single-channel delta after converting both 0...1 runtime values with
  `round(channel * 255)`.
- `evidence.imageIdentity` is `assetName | hash`, default `assetName`. `assetName` compares
  `imageAssetName`; a null value makes that unit's identity assertion `unobservable`. `hash`
  compares `imageHash` (SHA-256 over decoded RGBA8 bytes in row-major order) and elevates
  `imageHash` to a preflight requirement.
- `evidence.profiles` has at least two entries with unique non-empty `id`, unique positive integer
  `width`, and a destination matching `runtime.target`.
- `finalVerifier.mode` is `builtin | command`, default `builtin`. `command` is used only for the
  command mode.

## Artifact contract

Derive the workspace from the canonical design identity:

```text
<configured-artifacts-root>/<fileKey>-<rootNodeId>/
├── manifest.json
├── preflight.json
├── gates/
├── figma/
├── runtime/
├── reviews/
└── assets/
```

Sanitize path separators in `rootNodeId` without changing the value recorded in `manifest.json`.
Keep original REST responses unchanged. Workflow artifacts are local evidence and must not be
committed to the target repository. **Invariant I4:** the artifact directory must be ignored by
Git; when the source root is a Git repository and the directory is not ignored, preflight is blocked.

Every gate records canonical URL, file key, root node id, workspace, status, evidence paths, and an
exact blocker/safe next action when blocked. Use these gate record names:

```text
G0-scope.json, G1-root-tree.json, G2-detail.json, G3-rest-evidence.json,
G4-classification.json, G5-ordered-sweep.json, G6-assets.json,
G7-implementation.json, G8-build.json, G6V-binding-validation.json,
G7A-runtime-review.json, G7B-parent-rollup.json, G9-runtime-semantics.json,
G10-geometry-parity.json, G11-final-review.json, G12-final-verify.json
```

## Review record contract

Each reviewed gate writes `reviews/<gate>.json`:

```json
{
  "gate": "G2",
  "reviewer": {
    "kind": "self|subagent|custom",
    "id": "<agent role or command>",
    "model": "<optional>"
  },
  "verdict": "pass|fail|blocked",
  "findings": [
    { "id": "F1", "severity": "blocking|non-blocking", "message": "..." }
  ],
  "parentResults": [
    { "parentId": "<figma parent id>", "units": ["<unit id>"], "verdict": "pass|fail|blocked" }
  ],
  "evidence": ["<path>"],
  "at": "<ISO8601>"
}
```

A reviewed gate passes only when this file exists and `verdict` is `pass`. Reviewer identity is
recorded; independence is required only when `requireIndependentNodeGate` is true. Each reviewed
gate produces exactly one `reviews/<gate>.json` for G1, G2, G6, G7A, G7B, G10, and G11. G7A and
G7B each invoke review once; their one record aggregates all parents in `parentResults`.

## DebugBridge capability contract

Preflight probes both tiers below. A missing required route, field, or behavior writes the exact
deficiency to `preflight.json`, sets `status: blocked`, and stops before G0. A missing optional
field does not block, but it must be recorded as unavailable and every affected G10 assertion must
be `unobservable`.

Required GET routes (4): `/ping`, `/debug/page`, `/debug/windows`, `/debug/runtime/node`.

Required POST routes (2): `/debug/tap`, `/debug/scroll`.

Required node fields are `className`, `accessibilityIdentifier`, `frameInWindow{x,y,width,height}`,
`bounds`, `hidden`, `alpha`, `cornerRadius`, `rotationDegrees`, `anchorPoint{x,y}`, `gestureCount`,
`imageSize`, `text`, `fontName`, `fontSize`, and `numberOfLines`.

Optional node fields are `textColor`, `backgroundColor`, `imageAssetName`, and `imageHash`.
`textColor` and `backgroundColor`, when present, have shape
`{red,green,blue,alpha}` with every channel a floating-point value in 0...1. Compare colors only
after converting each channel with `round(channel * 255)`. UILabel/UIButton foreground checks use
`textColor`; surface checks use `backgroundColor`.

Image identity and every pairwise-difference assertion use `evidence.imageIdentity`. In default
`assetName` mode, equal names mean the same asset and different names mean different assets; null
`imageAssetName` is `unobservable`. In `hash` mode, `imageHash` is required during preflight; if the
field is absent, block with the message that this mode needs a bridge version supporting
`imageHash`. Run the resolver with `--capabilities <probed-capabilities.json>` after probing so this
mode is mechanically checked.

Required behavior:

- `/debug/scroll` responds with `contentOffset`, `contentSize`, and
  `adjustedContentInset{top,left,bottom,right}`.
- `/debug/tap` accepts optional `repeat` in 1...20 (default 1), returns `repeat` and `invoked`, and
  reports `success` only when `invoked == repeat`.
- When G10 evaluates z-order, `/debug/windows` child order is interpreted as z-order. Occlusion is
  proven only when both nodes share an ancestor, the cover follows the target in that ancestor's
  child order, and the target `frameInWindow` lies completely inside the cover frame.

Required capabilities are the only observation mechanism for these assertions. Missing a required
capability is blocked; source inspection cannot replace runtime observation. Missing an optional
capability is not blocked under the default strategy, but cannot silently pass G10.

## Preflight Connectivity Gate

Before design sweep, review, source edit, build, or runtime claim:

1. Run the Figma REST identity request and a depth-1 node request; confirm the root and record the
   live file version.
2. Run `python3 "${SKILL_DIR}/scripts/resolve-config.py" [config]`: merge defaults first, then
   validate. Resolve one executable command from `build` and store it in `preflight.json`; resolver
   failure (including default empty `build.scheme`) makes preflight blocked. Also verify reviewer
   adapter availability.
3. Build/launch only if needed for capability probing, using `runtime.target`.
4. Probe both DebugBridge capability tiers at `runtime.bridge.baseUrl`. For `imageIdentity=hash`,
   pass the probe artifact to the resolver and require `imageHash`.
5. If the target is a Git repository, run `git check-ignore` for the artifact workspace. If it is
   not ignored, preflight is blocked.
6. Write `preflight.json` with non-empty `checks[{name,status}]`; every check must pass.

## G0 — Scope Lock

Record file key, root node id, original/canonical URL, target screen/state, owner, in-scope and
out-of-scope states, entry, workspace, and Figma file `version` in `manifest.json`. Later gates
compare the live version against this scope-lock version. Unresolved root, state, or scope blocks.

## G1 — Root Figma Group Tree

Pull enough root depth to confirm root and direct children. Save the raw response, then write
`frame_struct.md` and `frame_struct_index.json`. Preserve parent/child structure. Sort direct
children visually: centerY only determines same-row membership; rows are top-to-bottom; nodes in a
row use original x left-to-right. Original x/y/w/h remain the only implementation coordinates.
Never promote nested children to root rows. Bind every index row to parent, source artifact, depth,
and child artifact.

Run the configured node reviewer (default self) immediately and write `reviews/G1.json`. It checks
root identity, direct-child completeness, hierarchy, order, original coordinates, and index
coverage.

## Minimum Unit Rules (按需加载)

Rules live in `${SKILL_DIR}/rules/`. Supported `unit_kind` values are `text`, `button-text`,
`button-image`, `button-text-icon`, `image`, and `shared-component`. Rule files are `text.md`,
`image.md`, `button-text.md`, `button-image.md`, `button-text-icon.md`, `shared-chrome.md`,
`corner-radius.md`, `screen.md`, and `layout-anchor.md`. They are dual-purpose implementation and
acceptance standards.

- G2 records every minimum unit's `unit_kind` and writes the exact deduplicated set to
  `rules_used.json`.
- G7/G7A load only mapped files. `shared-component` maps to `shared-chrome.md`; rounded units also
  load `corner-radius.md`.
- `${SKILL_DIR}/rules/layout-anchor.md` is always loaded. Its left/right/center/fill semantics,
  direct-parent judgment, and ambiguous stop rule are mandatory.
- A kind absent from the page is not loaded.

```json
{
  "rules_used": ["text", "image"],
  "producer": "figma-ui-gates",
  "schema_version": 1
}
```

## G2 — Current Group Detail

Process exactly the first unprocessed direct child in the current parent structure. Record parent
and group line, metadata id, source bindings, type, original frame, layout anchor and measured
margins/offset, ownership, hit testing, runtime id, structure kind, effective child count,
minimum-unit decision, content kind, localization, asset-collapse eligibility, child artifact,
next action, split/implementation counters, pending child ids, runtime artifact, and verdict.

A minimum unit is a leaf or a pure non-interactive asset composite explicitly eligible for
collapse. Localizable text or interaction forces continued splitting. Classify buttons by content:
text, image/icon, or text+icon. Interactive text+icon never collapses. A localizable text node is
never an image.

Shared chrome and multi-screen component instances use `unit_kind: shared-component` with
`component_ref`, `variant_props`, and `reuse_evidence`. If missing, first extract one App-level
shared component; do not create a page-local copy.

An `ambiguous` anchor per `${SKILL_DIR}/rules/layout-anchor.md` is a blocking human question. Record
measurements and do not advance that node until the confirmed anchor is written back.

Run the configured node reviewer and write `reviews/G2.json`. It checks parent/source binding,
field completeness, anchor derivation, minimum-unit decision, post-order fields, and frame-index
binding. Ambiguity must stop for human confirmation.

## Split and Implementation Completion

- A leaf, collapsed asset, or system-excluded node may be split-complete at its boundary.
- A non-minimum node is split-complete only when every required direct child is complete.
- A minimum unit becomes implementation-complete only after G7A passes.
- A non-minimum parent becomes implementation-complete only after direct children complete and
  G7B passes.
- Parents trust direct-child summaries and do not recount grandchildren.
- Do not start the next sibling until the current sibling is complete or explicitly blocked.

## G3 — REST Design Evidence

Derive evidence from unchanged REST metadata and design renders. Record styles, text, assets,
instance internals, and limitations. Do not claim a different design API. Re-fetch the live Figma
version; drift from G0 blocks and requires scope reevaluation.

## G4 — Group Classification and Container

Write the complete grouped tree table before implementation: order, parent, id, name, type, frame,
ownership, scope, action, child policy, and status. Shared chrome is not the content container.

- repeated data: `UITableView` or `UICollectionView` according to project convention;
- non-list vertical content: the project's scroll base;
- intentionally fixed/system-owned content: required fixed/system controller with evidence.

For non-list pages, record one vertical scroll owner, safe-area strategy, bottom-control strategy,
content-layout contract, and shortest/tallest/long-content evidence. Search existing analogous pages
before declaring ownership unknown.

## G5 — Ordered Group Sweep

Process top-to-bottom and siblings left-to-right. Record design values, source artifact, ownership,
scope, native mapping, asset/text/localization mapping, runtime expectation and anchor, split result,
and implementation result. Apply only the matching `${SKILL_DIR}/rules/*.md` files. Runtime geometry
or intuition cannot replace current design evidence.

## G6 — Asset Declaration

Decide combined versus split assets, import selected exports into the target asset directory, and
record dimensions plus 2x/3x scale evidence. G6 is design-side declaration only: it does not inspect
source references or runtime nodes.

- Localizable text is never collapsed; an SF Symbol glyph is icon content.
- Non-interactive image/vector/icon/Symbol/RECTANGLE minimum units use exported Figma assets.
- A RECTANGLE is not replaced by a native gradient or fill; preserve coincident stroke/dash chrome.
- Size-critical exports use image-bearing views/controls at original point bounds.
- Shared chrome reuses an App-level component, never a page-private asset.
- A collapsed visual is not custom-drawn or natively recomposed.
Write `gates/G6-assets.json`; each row has `figma_id`, `collapse`, and `reason`. A collapsed row
requires non-empty `local_asset` or `local_assets`, proof that each asset exists in the target asset
directory, and complete export dimensions/scale; a split row requires native mapping in G5/G7.
Background+Symbol button subtrees without independent text/badge/chrome collapse as one parent
export bound to the interactive control. Figma export is authoritative when identity is ambiguous.

Run the configured node reviewer once for G6 and write `reviews/G6.json`.

## G7 — Native Implementation

Only after G1-G6 pass may source edits begin. Record changed files,
exact changes, states, native mappings, and runtime anchors. Load mapped rules from
`${SKILL_DIR}/rules/`, plus required anchor/radius rules. Use original design x/y/w/h; do not adjust
by visual judgment.

Collapsed assets use `UIImageView` or `UIButton` at the parent Figma anchor, with deterministic
identifier `figma.<node-id>` where every non-alphanumeric scalar becomes `_`. Child instance
anchors remain evidence-only. Non-list pages use the selected single scroll owner and adaptive
content contract; reject competing scrollers, fixed artboard-height assumptions, and unsealed final
controls.

## G8 — Build and Launch

Resolve the command from the preflight-approved `build` configuration, execute it for the configured
`runtime.target`, and launch that artifact. Write `gates/G8-build.json` with the exact command, exit
code, product path, build id, launch time, and launched App identity. Compilation alone does not prove
UI parity.

## G6V — Asset Binding Validation

After G8 has launched the implementation, run:

```bash
bash "${SKILL_DIR}/scripts/validate-g6-asset-binding.sh" \
  --workspace <artifact-workspace> \
  --source-root <target-project-root>
```

It checks G2/G6 collapse-set equality, declaration types, complete Swift string literals (including
arrays/constants but not concatenation), absence of custom drawing in anchor-binding files, and
image-bearing runtime bindings with image evidence. Write `gates/G6V-binding-validation.json`.

## G7A — Unit Runtime Review

Using the same launched App instance identified by G8's build id and launch time, query every
implementation-complete minimum-unit anchor, require exactly one node, and save runtime JSON.
Perform one configured review total and aggregate every parent into `parentResults` in the single
`reviews/G7A.json`; also write `gates/G7A-runtime-review.json`. That gate record must copy G8's
`buildId` and `launchedAt` exactly.

Compare `frameInWindow`, `bounds`, `rotationDegrees`, `anchorPoint`, `cornerRadius`, `alpha`,
`imageSize`, `fontName`, and `fontSize`, plus the applicable unit rules and confirmed layout anchor.
Collapsed units must bind the parent id to an image-bearing control and exported asset. Shared
chrome must have one repository-wide implementation. Rounded units use effective/capsule geometry.

## G7B — Parent Rollup Review

Create ordered direct-child rollups for all non-minimum parents, including split status,
implementation status, and child verdicts. Perform one configured review total and aggregate all
parents into `parentResults` in the single `reviews/G7B.json`; also write
`gates/G7B-parent-rollup.json`. Check coverage, order, completion, counters, completion kind, and
frame-index binding.

## G9 — Runtime Semantics

Using DebugBridge, verify page id; anchor uniqueness; node type; text; visibility and alpha;
enabled/user-interaction state; gesture/control behavior; exactly one vertical scroll owner; scroll
content/viewport/insets; final-control reachability; and shortest/tallest boundary values from every
configured profile. Short/long-content values use the project fixture; without one, record `n/a`
and its reason. Use repeated tap to prove one user action does not duplicate navigation pushes.

## G10 — Geometry Parity

Compare every G2 minimum unit's design values with runtime values using configured tolerances.
Required checks are origin/size, rotation, anchor point, corner radius, alpha, image size, font
family/name, font size, color, and z-order. Confirm occlusion with the shared-ancestor children-order
and full-frame-containment rule. For rounded units assert `cornerRadius <= min(width,height)/2 + 0.5`; when the declared
radius reaches half the minimum side, require capsule geometry.

Container-width behavior requires one separate launch for every configured `evidence.profiles`
entry. `gates/G10-geometry-parity.json` contains `profiles[]`; each entry has `id`, `width`, and a
non-empty `units[]` covering every G2 unit. Profile ids and widths are unique, there are at least two
profiles, and all unit sets equal the G2 set. Require every capture within tolerance. Do not assert
constraint type or hard-coded width/height from runtime data; instead verify
that the confirmed anchor relationship remains stable across the two widths.

All units within tolerance is pass. Any excess is fail and `gates/G10-geometry-parity.json` must
contain a `unit / expected / measured / delta` table. Captured-screen evidence, pixel similarity,
and pixel color sampling are forbidden and cannot be cited as evidence. Run the configured node
reviewer once and write `reviews/G10.json`. Re-fetch Figma `version`; drift from G0 blocks pending
scope reevaluation.

If an optional runtime field is unavailable, the affected unit assertion is explicitly
`unobservable`; it must not be silently recorded as pass. `gates/G10-geometry-parity.json` must
contain `unobservable[]`, with one matching `{unit, assertion, missingCapability}` entry for every
unobservable unit assertion. The verifier rejects an unobservable assertion without its matching
entry (and rejects an unmatched entry). See `LIMITATIONS.md` for all non-mechanical boundaries.

## G11 — Final Review

Run the configured `finalGate` reviewer (default child agent `ui-reviewer`) once and write
`reviews/G11.json` and `gates/G11-final-review.json`. Provide changed files, gate statuses, runtime
conclusions, G6V validation output, geometry result, and known risks. The gate passes only on the
recorded pass verdict.

## G12 — Final Verify

Default mode runs the bundled verifier:

```bash
bash "${SKILL_DIR}/scripts/verify-gate-record.sh" \
  --workspace <artifact-workspace> \
  --source-root <target-project-root>
```

If `finalVerifier.mode` is `command`, run its configured command instead and record exact command,
exit code, and output. The bundled verifier checks all prior records and writes
`gates/G12-final-verify.json`; G12 therefore does not require that output before invocation. A
project without its own verifier uses the bundled verifier and is not blocked for that reason.

## Result Contract

Return entry/target, workspace, completed or blocked gate, changed files, reviewer identities and
verdicts, G6V validation, build result, runtime result or blocker, geometry result, and final verifier
result. Never claim completion while a required gate is missing, blocked, or non-pass.
