# Rule: corner radius

> **Dual-purpose.** When adding new UI, implement to this standard; when accepting, verify against this same standard.

## Applies to

Any visual unit with rounded corners: button (text / image / text-icon), card, container, or image mask.

## Acceptance criteria

| Check | Expect |
|---|---|
| `effective_radius` | `effective = min(declared, min(width,height)/2)` |
| `capsule_when_overflow` | When `declared >= min(w,h)/2`, the unit must render as a capsule with fully rounded ends; it must not show a straight end edge or sharp point |
| `render_geometry` | Acceptance compares the rendered shape and must not compare only the declared numeric value |

## Background

- Figma visually clamps a corner radius greater than `min(w,h)/2` to `min(w,h)/2`.
- iOS `CALayer.cornerRadius` does **not** clamp. When `cornerRadius > min(w,h)/2`, adjacent corner arcs overlap, the left/right or top/bottom edges degenerate into straight segments, and obvious sharp points appear at the transitions.
- Therefore, equal declared values do not imply equal rendered shapes.

## Implementation requirement (new UI)

- Implement `effective = min(declared, min(bounds.width, bounds.height)/2)`.
- When the declared value is at least half the height/width, implement a capsule with `cornerRadius = min(w,h)/2` and update it from `bounds` in `layoutSubviews`.
- Writing an unclamped declared value directly is forbidden.

## Acceptance review (verify)

- Read runtime `cornerRadius` and `bounds`, then calculate `min(w,h)/2`.
- Assert `cornerRadius <= min(w,h)/2 + 0.5pt`.
- When the design-declared value is at least half the height/width, assert that the actual shape is a capsule (for example, `cornerRadius ≈ min(w,h)/2`).
- `cornerRadius > min(w,h)/2` is a finding because it carries sharp-point risk.

## Evidence normalization

Record `declared_radius`, `runtime_cornerRadius`, `bounds`, `half_min_side`, `is_capsule`, and `verdict`.
