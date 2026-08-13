# Rule: text

> **Dual-purpose.** When adding new UI, implement to this standard; when accepting, verify against this same standard.

## Applies to

`unit_kind: text` — a text leaf (label).

## Acceptance criteria

| Dimension | Standard | Tolerance |
|---|---|---|
| font | resolved PostScript family/name and weight match Figma | exact |
| font size | match Figma point size | `±0.1 pt` |
| color | normalized to extended-sRGB RGBA, each channel | `1/255` per channel |
| x/y origin | origin in root content coordinate space | `±0.5 pt` |
| width/height | **no hard-coded size** — Figma w/h is design render, not a size lock | n/a |
| line count | `numberOfLines = 0` | n/a |
| localization | layout survives string expansion/contraction | n/a |

A mismatch on font / size / color / origin is a finding.

## Implementation requirement (new UI)

Resolve the exact PostScript font, set the point size, apply the extended-sRGB color, place
the origin, leave `numberOfLines = 0`, and avoid hard-coded width/height. Do not clamp the
label to the Figma render box.

## Acceptance review (verify)

Compare point-by-point: for each dimension record `expected` (Figma) vs `measured` (runtime),
the tolerance, and the evidence path. A naked "looks equal" is not evidence.

## Evidence normalization (shared with `ui-review`)

Convert Figma and runtime frames into the target root content coordinate space; record device
scale, safe-area inset, and root origin. Every `ok` row records measured value, expected value,
tolerance, and evidence path. The machine-readable text-evidence shape and these tolerance
limits are enforced mechanically by `ui-review`'s `validate-ui-review-artifacts.py`, so
new-UI implementation and existing-screen parity share one evidence contract.

```text
text / button-text evidence:
  runtime_path
  expected|measured: { font_name, font_size, color_rgba, origin }
  tolerance: { origin_pt, font_size_pt, color_channel }
  layout: { number_of_lines, hardcoded_width, hardcoded_height, localization_safe }
```
