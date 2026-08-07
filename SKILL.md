---
name: figma-ui-gates
description: Orchestrate the Figma-driven UI gate sequence G0-G12 for new UI implementation and the shared evidence gates for Figma parity review. Use after dev-flow-ui routes a task to Figma UI work; coordinate Figma REST, Review MCP, DebugBridge, physical-device build/runtime checks, screenshot review, and the final verifier.
---

# Figma UI Gates

This skill owns the Figma UI gate contract. dev-flow-ui is only the entry router; it must not duplicate the gate procedures below.

Use this skill for:

- ui_new: Figma-driven iOS UI implementation or restoration.
- ui_review: Figma-to-existing-runtime parity review and an explicitly authorized correction loop.

The normal ui_new sequence is:

~~~text
preflight
→ G0 scope
→ G1 root tree + structure review
→ G2 current group detail + detail review
→ G3 REST design evidence
→ G4 classification/container
→ G5 ordered group sweep
→ G6 asset boundary
→ G7 native implementation
→ G7A leaf runtime review / G7B parent rollup review
→ G8 build
→ G9 runtime semantics
→ G10 screenshot/design review
→ G11 independent orchestrator review
→ G12 final verifier
~~~

Do not skip, reorder, or mark a gate passed from a hand-written summary. A failed or blocked gate stops the sequence.

## Dependencies and ownership

Use these capabilities without duplicating their instructions:

- figma-rest-api: read-only Figma REST data and rendered images.
- orchestrator_mcp: independent structure, detail, runtime, rollup, and final review.
- DebugBridge: physical-device UI actions, UIWindow/UIView inspection, runtime-anchor lookup, and current-run App logs.
- XcodeBuildMCP: session_show_defaults followed by build_run_device.
- scripts/dev-flow-ui-init: create the gate artifact.
- scripts/dev-flow-ui-verify-gate: validate the completed ui_new gate.
- scripts/dev-flow-ui-verify-review-gate: validate the completed ui_review gate.

figma-rest-api is the Figma data source. orchestrator_mcp is the reviewer. Neither is replaced by the other.

## Artifact contract

Before G0, derive a stable workspace from the canonical Figma URL:

~~~text
.devflow-ui/by-url/<sanitized-canonical-figma-url>/
├── manifest.json
├── preflight.json
├── gates/
├── figma/
├── reviews/
├── runtime/
├── lookin/
└── screenshots/
~~~

Keep raw REST responses unchanged. Store derived structure, index, detail, runtime, review, and gate artifacts beside them. Generated workflow artifacts are local evidence and must be ignored by the target repository.

Every gate records the original/canonical URL, file key, root node id, artifact workspace, status, evidence paths, reviewer run information when applicable, and an exact blocker/safe next action when blocked.

## Preflight Connectivity Gate

Before any Figma sweep, review dispatch, source edit, build, or runtime claim:

1. Run figma_rest.py me.
2. Run figma_rest.py nodes --url <original-url> --depth 1 and confirm the requested root id.
3. Call mcp__orchestrator_mcp__orchestrate_effective_config; require a registered stdio session and live PID, then check provider credentials.
4. Require a wired physical device; call DebugBridge ensure_ports and ping.
5. If the App is not running, use XcodeBuildMCP session_show_defaults followed by build_run_device, then repeat the DebugBridge checks.

Preflight passes only when Figma REST, Review MCP, and DebugBridge all pass. Otherwise write preflight.json, mark the workflow blocked, and stop before G0.

## G0 — Scope Lock

Record Figma file key, root node id, original/canonical URL, target screen/state, implementation or review owner, in-scope/out-of-scope states, entry, and artifact workspace. Do not start a sweep with an unresolved root, state, or scope.

## G1 — Root Figma Group Tree

Use figma-rest-api to pull enough root depth to confirm the root and direct children. Save the raw response, then write frame_struct.md and frame_struct_index.json.

Preserve parent/child structure. Sort direct children visually:

1. use centerY only to detect same-row nodes;
2. sort rows by centerY top-to-bottom;
3. sort nodes in a row by original x left-to-right;
4. keep original x/y/w/h as the only implementation coordinates.

Do not promote nested children to root rows. The index binds every written row to its parent, structure artifact, depth, and child-structure artifact when applicable.

### G1 Review MCP

Call orchestrator_mcp immediately after G1. The reviewer checks root identity, direct-child completeness, parent/child preservation, visual ordering, original coordinates, and index coverage.

G1 passes only with a real run id, role, provider/model, verdict pass, and copied findings. Otherwise stop before G2.

## G2 — Current Group Detail

Process exactly the first unprocessed direct child in the current parent frame_struct.md. Do not jump to a later sibling.

Record the current parent structure and group line before writing detail JSON. Bind metadata id, source parent, source structure artifact, node type, frame, ownership, hit testing, runtime id, structure kind, effective child count, minimum-unit decision, content kind, text/localization state, asset-collapse eligibility, child artifact, next action, split/implementation counters, pending child ids, runtime artifact, and review verdict.

A minimum unit is a leaf, or a pure non-interactive asset composite explicitly marked asset-collapse-eligible. A composite containing localizable text or interaction must continue splitting.

### G2 Review MCP

Call orchestrator_mcp immediately after the current detail is written. The reviewer checks current-parent binding, field completeness/reasonableness, anchor derivation, minimum-unit decision, post-order completion fields, and frame-index binding. A non-pass verdict stops the sequence.

## Split and Implementation Completion

Keep split completion separate from implementation completion:

- A leaf, collapsed asset, or system-excluded node may be split-complete at its boundary.
- A non-minimum node is split-complete only when every direct child that must be split is complete.
- A minimum unit is implementation-complete only after G7A passes.
- A non-minimum node is implementation-complete only after all direct children are implementation-complete and G7B passes.
- Parents trust direct-child completion summaries; do not recount grandchildren.
- Do not begin the next sibling until the current sibling has both statuses complete, or is explicitly blocked.

## G3 — REST Design Evidence

Derive design evidence from unchanged REST metadata and rendered image. Record styles, text, assets, instance internals, and any design-context limitation. Never claim Figma MCP metadata or design-context calls when REST was used.

## G4 — Group Classification and Container

Write the complete grouped tree table before implementation. Every root direct child appears with order, parent, id, name, node type, frame, ownership, scope, action, child policy, and status.

Classify the screen container:

- real repeated data: UITableView or UICollectionView;
- non-list vertical content: the project scroll base, such as BaseScrolleController;
- intentionally fixed/system-owned content: BaseViewController or the required system controller, with evidence and exception rationale.

For non-list pages, record one primary vertical scroll owner, safe-area strategy, bottom-control strategy, content-layout contract, and shortest/tallest/long-content evidence. Unknown ownership blocks implementation.

## G5 — Ordered Group Sweep

Process groups top-to-bottom and siblings left-to-right according to the current parent structure. For each group record Figma values, source artifact, ownership, scope, native mapping, asset/text/localization mapping, runtime expectation, runtime anchor, screenshot expectation, split result, and implementation result.

Do not use a screenshot or intuition as a substitute for current group evidence.

## G6 — Asset Boundary

Decide combined asset versus split assets and record 2x/3x evidence.

- A localizable text node is not an asset-collapse candidate.
- An SF Symbol glyph is icon/asset content, not localizable text.
- A non-interactive image/vector/icon/Symbol/RECTANGLE minimum unit uses an exported Figma asset and appears in G6.
- A RECTANGLE minimum unit must not be replaced by a native gradient or solid fill.
- If a rectangle shares bounds with visible parent stroke/dash chrome, the exported asset or equivalent overlay preserves that chrome.
- Size-critical exported assets use a native control/view whose runtime bounds equal the Figma frame in points; use UIButton for interactive icon/button units rather than resizing bar-item slots.

## G7 — Native Implementation

Only after G1-G6 pass may source edits begin. Record source files, exact changes, affected states, native mappings, and runtime anchors.

For non-list pages, reject a plain base controller with a manually positioned vertical stack, nested competing vertical scroll views, fixed Figma artboard-height assumptions, content bypassing the selected scroll container, or a final control not sealed to the content-container bottom.

Adaptive acceptance covers the shortest viewport, a taller viewport, short content, and long/dynamic content. Fixed bottom overlays require safe-area anchoring plus matching scroll/content inset.

## G7A — Minimum-Unit Runtime Review MCP

For every implementation-complete minimum unit:

1. Query DebugBridge by the exact runtime-anchor/accessibility identifier.
2. Require exactly one runtime node.
3. Save runtime detail JSON.
4. Call Review MCP with the current G2 detail, runtime detail, frame index, anchor, and source evidence.

The reviewer checks anchor binding, unique node, type/content mapping, frame position/size, text/font/color, asset evidence, control behavior, native geometry, and frame-index binding as applicable. The verdict must be pass.

Use this deterministic anchor:

~~~swift
enum FigmaRuntimeAnchor {
    static func make(from figmaNodeID: String) -> String {
        var output = "figma."
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
        for scalar in figmaNodeID.unicodeScalars {
            if allowed.contains(scalar) { output.unicodeScalars.append(scalar) }
            else { output.append("_") }
        }
        return output
    }
}
~~~

## G7B — Parent Completion Rollup Review MCP

For every non-minimum parent:

1. Write a rollup JSON containing direct children in current parent order.
2. Include each child's split status, implementation status, and child review verdicts.
3. Call Review MCP with the parent detail, child structure, frame index, and rollup JSON.

The reviewer checks direct-child coverage/order, child completion and verdicts, parent counters, completion kind, and frame-index binding. The verdict must be pass.

## G8 — Build

Build the target with XcodeBuildMCP and record a success marker. A compile result alone does not prove UI completion.

## G9 — Runtime Semantics

On the wired physical device, use DebugBridge to verify page id, stable runtime anchors, type, label, enabled state, visibility, reachability, and interaction. For scroll pages, identify exactly one primary vertical scroll owner, content container, content/visible heights, and final-control reachability.

For Home proof states, use only the production navigation path with -oursProofHomeState <state> and the local /v1/home mock payload path. After proof validation, relaunch without the proof argument.

## G10 — Screenshot / Design Review

When visual parity, exact layout, overlap, clipping, or final UI completion is claimed:

- obtain the Figma reference image through figma-rest-api;
- compare the target state on the shortest supported viewport and one taller viewport for adaptive pages;
- check top layout, bottom reachability, content end, safe area, and fixed-overlay inset;
- block if the exact target state cannot be launched.

## G11 — Independent Orchestrator Review MCP

Run a real orchestrator_mcp review after implementation and evidence exist. Provide compact actual content: task summary, changed files, curated diff, gate status, artifact paths under validation, runtime/screenshot results, and known risks.

Require a real run id, role, provider/model, verdict, and copied findings. Self-review, main-session, or hand-written reviewer rows are invalid.

## G12 — Final Verify

Run the project verifier:

~~~bash
scripts/dev-flow-ui-verify-gate <artifact-workspace>/gates/<gate>.md
~~~

For ui_review, use the review verifier and record comparison scope, device/state coverage, finding severity, fix queue, reviewer result, and verifier result. A failed or blocked-valid verifier is not completion.

## Review Entry

ui_review reuses preflight, G0-G3 evidence, group binding, and runtime anchors. It does not create fake implementation-complete records. It additionally applies:

- Figma-to-existing-runtime binding;
- the label rule: app-owned UILabel uses SnapKit, numberOfLines = 0, and no fixed-height constraint;
- runtime extra scan after binding;
- authorized finding-scoped correction and recheck only.

## Result Contract

Return entry and target, artifact workspace, completed/blocked gate, changed files when source was edited, Review MCP run ids and verdicts, build result, runtime result or exact blocker, screenshot/design result, and final verifier result.

Do not claim completion when a required gate is missing, blocked, or has a non-pass reviewer verdict.
