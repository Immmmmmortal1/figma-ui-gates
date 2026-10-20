# Rule: text

> **Dual-purpose.** When adding new UI, implement to this standard; when accepting, verify against this same standard.

## Applies to

`unit_kind: text` — a text leaf (label).

## Acceptance criteria

| Dimension | Standard | Tolerance |
|---|---|---|
| font | resolved PostScript family/name and weight match Figma | exact |
| font size | match Figma point size | `±0.1 pt` |
| text color | DebugBridge `textColor:{red,green,blue,alpha}` with 0..1 floating-point channels | configured `colorChannel` after `round(channel*255)` |
| x/y origin | origin in root content coordinate space | `±0.5 pt` |
| width/height | preserve the confirmed anchor relationship across two runtime profiles | `±0.5 pt` |
| line count | `numberOfLines = 0` | n/a |
| localization | layout survives string expansion/contraction | n/a |

A mismatch on font / size / color / origin is a finding.

## Implementation requirement (new UI)

Resolve the exact PostScript font, set the point size, apply the text color, place
the origin, and leave `numberOfLines = 0`. Do not clamp the label to the Figma render box.

## Acceptance review (verify)

Compare point-by-point: for each dimension record `expected` (Figma) vs `measured` (runtime),
the tolerance, and the evidence path. A naked "looks equal" is not evidence.

## Evidence normalization

Convert Figma and runtime frames into the target root content coordinate space; record device
scale, safe-area inset, and root origin. Every `ok` row records measured value, expected value,
tolerance, and evidence path. The machine-readable text-evidence shape and these tolerance
limits are checked by this skill's final verifier and reviewed gate records.

```text
text / button-text evidence:
  runtime_path
  expected|measured: { font_name, font_size, textColor:{red,green,blue,alpha}, origin }
  tolerance: { origin_pt, font_size_pt, color_channel }
  layout: { number_of_lines, localization_safe, profiles[] }
```

Before comparison, normalize every `textColor` 0..1 channel with `round(channel * 255)`; the
configured tolerance is the resulting 0..255 single-channel delta. `backgroundColor` is not text
foreground evidence. Image identity is asserted separately with `imageAssetName`; `imageHash` is
never compared with an exported-file hash.
