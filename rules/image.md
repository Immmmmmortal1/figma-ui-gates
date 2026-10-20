# Rule: image

> **Dual-purpose.** When adding new UI, implement to this standard; when accepting, verify against this same standard.

## Applies to

`unit_kind: image` — a non-interactive image / icon / exported visual.

## Acceptance criteria

| Dimension | Standard | Tolerance |
|---|---|---|
| image identity | configured `evidence.imageIdentity` field matches expected identity | exact match |
| images differ | configured identity field differs between nodes declared visually different | inequality in one run |
| frame origin/size | runtime frame vs Figma frame in points | `±0.5 pt` |

An observable identity mismatch, or equal configured identities for nodes required to differ, is a finding.

## Repair on identity mismatch

Export the Figma asset and bind its catalog name; do not "adjust" the existing asset.

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

Verify identity using the configured strategy and frame origin/size against tolerance; for collapsed
units, confirm the runtime class is image-bearing (not a hand-drawn `UIView`) and the asset
matches the G6 `local_asset`.

## Evidence normalization

Same image-evidence shape as `button-image.md`. Default `assetName` uses `imageAssetName`; null is
`unobservable`. `hash` requires `imageHash`, defined as SHA-256 over decoded RGBA8 pixel bytes in
row-major order. All pairwise-difference assertions use the selected strategy.
