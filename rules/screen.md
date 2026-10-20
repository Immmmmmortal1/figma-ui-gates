# Rule: screen

> **Dual-purpose.** When adding new UI, implement to this standard; when accepting, verify against this same standard.

## Applies to

Screen-level checks (not a minimum unit): `screen.background` and `screen.base_layout`.

## Acceptance criteria

| Check | Expect |
|---|---|
| `screen.background` | Screen / root content background color matches Figma |
| `screen.base_layout` | **Has list/repeated data → `UICollectionView`** as the overall host; **no list → `UIScrollView`** whose content height adapts to content. One primary vertical scroll owner only |

`screen.base_layout` is **decided from Figma structure** (list vs non-list, per G4 container
classification) and only **verified** on the live UI.

## Implementation requirement (new UI)

Classify the screen container per G4: real repeated data → `UICollectionView`; non-list
vertical content → the project scroll base (e.g. `BaseScrolleController`); fixed/system-owned
content → `BaseViewController` or the required system controller with evidence. For non-list
pages record one primary vertical scroll owner, safe-area strategy, bottom-control strategy,
and content-layout contract. Reject a plain base controller with a manually positioned vertical
stack, nested competing vertical scroll views, fixed artboard-height assumptions, or a final
control not sealed to the content-container bottom.

## Acceptance review (verify)

Confirm the live root/content background color matches Figma, and the live container matches
the expected layout (collection-based for list screens; single adaptive-height scroll owner for
non-list screens). Competing vertical scrollers or ambiguous ownership is a finding.

## Evidence normalization

Screen rows use the generic `runtime_path, expected, measured` evidence shape. Background color is
read from DebugBridge `backgroundColor` and checked by this skill's reviewed gate records.
