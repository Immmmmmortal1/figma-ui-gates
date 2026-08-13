# Rule: button-image

> **Dual-purpose.** When adding new UI, implement to this standard; when accepting, verify against this same standard.

## Applies to

`unit_kind: button-image` — a button whose content is image/icon only.

## Acceptance criteria

| Dimension | Standard | Tolerance |
|---|---|---|
| image identity | SHA-256 identity chain: `runtime node → bundle asset name → Figma source export hash` | exact hash match |
| frame origin/size | runtime frame vs Figma frame in points | `±0.5 pt` |

A hash mismatch is a finding. **Figma export is authoritative.**

## Repair on hash mismatch

When the runtime asset hash differs from the Figma export hash, export the Figma asset and
replace the runtime image; do not "adjust" the existing asset.

## Implementation requirement (new UI)

Export the asset from Figma, bind it to the interactive control (`UIButton` / project button
wrapper + `setImage`) at the Figma frame in points, and set `accessibilityIdentifier` to
`figma.<node-id>`.

## Acceptance review (verify)

Verify the SHA-256 chain end-to-end and the frame origin/size against tolerance. Record
`figma_sha256`, `source_asset_sha256`, `runtime_asset_name`, and expected/measured frame.

## Evidence normalization (shared with `ui-review`)

Hash the original Figma export file and the source asset file before asset-catalog compilation
using SHA-256. Do not claim a live pixel hash unless DebugBridge explicitly returns bytes and
the hash algorithm/input are recorded. Machine-readable shape enforced by `ui-review`'s
`validate-ui-review-artifacts.py`:

```text
image / button-image evidence:
  runtime_path, figma_sha256, source_asset_sha256, runtime_asset_name
  expected_frame, measured_frame
  tolerance: { origin_pt, size_pt }
```
