# Rule: button-text

> **Dual-purpose.** When adding new UI, implement to this standard; when accepting, verify against this same standard.

## Applies to

`unit_kind: button-text` — a button whose content is text only.

## Acceptance criteria

Inherit **all** `text` criteria (see `text.md`), plus:

| Dimension | Standard |
|---|---|
| hit target | the button must meet the project minimum touch target, anchored at the Figma origin |

Font, font size, color, x/y origin, no hard-coded width/height, `numberOfLines = 0`, and
localization-safety are checked exactly as `text`. A mismatch on any `text` criterion, or a
missing/undersized hit target, is a finding.

## Implementation requirement (new UI)

Implement the label per `text.md`, then bind it to an interactive control whose hit target
satisfies the project minimum at the Figma origin.

## Acceptance review (verify)

Apply `text.md` point-by-point, then verify the hit target.

## Evidence normalization (shared with `ui-review`)

Same text-evidence shape as `text.md`; the hit target is recorded as additional runtime
evidence. Enforced by `ui-review`'s `validate-ui-review-artifacts.py`.
