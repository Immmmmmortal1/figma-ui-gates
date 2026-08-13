# Rule: button-text-icon

> **Dual-purpose.** When adding new UI, implement to this standard; when accepting, verify against this same standard.

## Applies to

`unit_kind: button-text-icon` — a button with both text and an icon.

## Acceptance criteria

Expected control model: a `UIView` container + tap gesture, with the text and icon as
subviews under the hit container.

- **text** — checked by `text.md` criteria.
- **icon** — checked by the image SHA-256 hash criteria (see `image.md` / `button-image.md`).
- A wrong control model (e.g. a single rasterized button image, or text+icon fused into one
  exported bitmap) is a finding. An interactive text+icon unit must **not** collapse to one
  exported image.

## Implementation requirement (new UI)

Build a `UIView` + tap gesture; implement the text subview per `text.md` and the icon subview
per the image SHA-256 chain. Do not rasterize the button into a single image.

## Acceptance review (verify)

Verify the control model is `UIView` + gesture (not a single image), then apply `text.md` to
the text and the image-hash rule to the icon.

## Evidence normalization (shared with `ui-review`)

Combined evidence shape enforced by `ui-review`'s `validate-ui-review-artifacts.py`:

```text
button-text-icon evidence:
  text: <text evidence>
  icon: <image evidence>
```
