# Rule: button-image

> **Dual-purpose.** When adding new UI, implement to this standard; when accepting, verify against this same standard.

## Applies to

`unit_kind: button-image` — a button whose content is image/icon only.

## Acceptance criteria

| Dimension | Standard | Tolerance |
|---|---|---|
| image identity | configured `evidence.imageIdentity` field matches expected identity | exact match |
| images differ | configured identity field differs between nodes declared visually different | inequality in one run |
| frame origin/size | runtime frame vs Figma frame in points | `±0.5 pt` |

An observable identity mismatch, or equal configured identities for nodes required to differ, is a finding.

## Repair on identity mismatch

When the runtime catalog name differs from the declared asset, export the Figma asset and
replace the runtime image; do not "adjust" the existing asset.

## Implementation requirement (new UI)

Export the asset from Figma, bind it to the interactive control (`UIButton` / project button
wrapper + `setImage`) at the Figma frame in points, and set `accessibilityIdentifier` to
`figma.<node-id>`.

## Acceptance review (verify)

Verify identity through the configured strategy and frame origin/size. Record the selected runtime
identity, pairwise comparisons, and expected/measured frame.

## Evidence normalization

Default `assetName` identity uses DebugBridge `imageAssetName`; null is `unobservable`. `hash` mode
requires `imageHash`, SHA-256 over decoded RGBA8 pixel bytes in row-major order. Pairwise-difference
assertions use the same selected strategy.

```text
image / button-image evidence:
  runtime_path, runtime_asset_name, same_run_image_hash
  expected_frame, measured_frame
  tolerance: { origin_pt, size_pt }
```
