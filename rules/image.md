# Rule: image

> **Dual-purpose.** When adding new UI, implement to this standard; when accepting, verify against this same standard.

## Applies to

`unit_kind: image` — a non-interactive image / icon / exported visual.

## Acceptance criteria

| Dimension | Standard | Tolerance |
|---|---|---|
| image identity | SHA-256 identity chain: `runtime node → bundle asset name → Figma source export hash` | exact hash match |
| frame origin/size | runtime frame vs Figma frame in points | `±0.5 pt` |

A hash mismatch is a finding. **Figma export is authoritative.**

## Repair on hash mismatch

Export the Figma asset and replace the runtime image; do not "adjust" the existing asset.

## Implementation requirement (new UI)

Use `UIImageView` (or image-bearing control) with the exported Figma asset at the Figma frame
in points; set `accessibilityIdentifier` to `figma.<node-id>` on the parent runtime unit.

## Asset-collapse rule (consistent with G6)

When G6 marks a non-interactive image/vector/icon/Symbol/RECTANGLE minimum unit
`collapse: true`:

- the collapsed unit **must** use an exported Figma asset at runtime (appear in G6);
- **never** implement it with a custom `UIView` subclass and `draw(_:)`, vector recomposition,
  or ad-hoc `UIImage(systemName:)`;
- a RECTANGLE minimum unit must not be replaced by a native gradient or solid fill;
- if a rectangle shares bounds with visible parent stroke/dash chrome, the exported asset (or
  equivalent overlay) preserves that chrome.

## Acceptance review (verify)

Verify the SHA-256 chain end-to-end and the frame origin/size against tolerance; for collapsed
units, confirm the runtime class is image-bearing (not a hand-drawn `UIView`) and the asset
matches the G6 `local_asset`.

## Evidence normalization (shared with `ui-review`)

Same image-evidence shape and SHA-256 chain as `button-image.md`, enforced by `ui-review`'s
`validate-ui-review-artifacts.py`.
