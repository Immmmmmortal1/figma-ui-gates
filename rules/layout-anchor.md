# Rule: layout-anchor

> **Dual-purpose.** When adding new UI, implement to this standard; when accepting, verify
> against the same standard.

## Applies to

Every minimum unit (`text`, `button-text`, `button-image`, `button-text-icon`, `image`) and every
container node that owns children.

Layout anchoring is judged **per node, against its direct parent container's box** — never against
the root frame or the screen. Judging against the root hides the real anchor whenever a parent
container is itself positioned.

## The three principles

Every node that sits on a layout baseline is exactly one of:

| `layout_anchor` | Meaning | Implementation |
|---|---|---|
| `left` | 靠左 — pinned to the parent's left edge | `leadingAnchor` + `topAnchor` + width + height |
| `right` | 靠右 — pinned to the parent's right edge | `trailingAnchor` + `topAnchor` + width + height |
| `center` | 居中 — horizontally centered in the parent | `centerXAnchor` + `topAnchor` + width + height |
| `fill` | 撑满 — both margins fixed, width flexes | `leadingAnchor` + `trailingAnchor` + `topAnchor` + height |

`fill` is the flexing variant of `center`: both margins are equal, but the width must follow the
container. Use `fill` for containers, backgrounds, dividers and full-width rows; use `center` for
content whose width is intrinsic (text, icon, image, fixed-size control).

The acceptance criterion is the resulting anchor relationship across two runtime widths; runtime
evidence does not claim the source constraint type.

## Judgement

For node `N` inside parent `P` (all values in `P`'s coordinate space):

```text
leftMargin   = N.x - P.x
rightMargin  = (P.x + P.w) - (N.x + N.w)
centerOffset = (N.x + N.w / 2) - (P.x + P.w / 2)

centerTolerance = 1 pt     # how far off-center still counts as centered
edgeZone        = 24 pt    # margin at or below this counts as "pinned to that edge"
fillRatio       = 0.7      # width >= this fraction of the parent reads as "fills it"
snapTolerance   = 0.5 pt   # margin at or below this is an exact edge snap
```

Evaluate in order; the first rule that matches wins:

1. `|centerOffset| ≤ centerTolerance`
   → `fill` when the width is at least `fillRatio` of `P.w` **and** both margins are equal
     (within `centerTolerance`); otherwise `center`.
2. `leftMargin ≤ snapTolerance` → `left`.
3. `rightMargin ≤ snapTolerance` → `right`.
4. `leftMargin ≤ edgeZone` **and** `rightMargin > edgeZone` → `left`.
5. `rightMargin ≤ edgeZone` **and** `leftMargin > edgeZone` → `right`.
6. Both margins `≤ edgeZone` → the **smaller** margin decides the anchor (`left` when
   `leftMargin < rightMargin`, `right` otherwise). Record the measured margins as a design
   deviation alongside the anchor.
7. Anything else → **`ambiguous`**.

Rule 1 separates `center` from `fill` by whether the node stretches with its container. A text
block or a full-width container spanning the parent's inner width is `fill`; a fixed-width icon,
image or control centred in the parent is `center`.

Rules 4 and 5 exist because a node pinned to an edge usually carries the design system's edge
inset (16pt, 24pt, …), not zero. Treating only `margin = 0` as "pinned" misclassifies the most
common layout in real design files.

A node judged `ambiguous` under rule 7 has no defensible anchor; see the next section.

## `ambiguous` is a stop, not a guess

A node that matches none of the rules has left the layout contract:

- Do **not** invent an anchor.
- Do **not** average the margins or pick the nearest edge by feel.
- Do **not** silently fall back to "leading plus fixed width".

Record `layout_anchor: "ambiguous"` with the measured `leftMargin`, `rightMargin` and
`centerOffset`, and **raise it as a blocking question for human confirmation during the split
(G2)**. Implementation (G6/G7) must not start for that node until the confirmed anchor is written
back into the detail JSON.

### Designed groups

A sibling pair offset from centre by mirrored amounts (a collage, a stacked pair of cards) is
`ambiguous` node by node, and the correct answer is not an anchor on each child: it is a shared
parent container that is `center` with equal margins, with the children positioned relative to
that container.

That grouping is a **design decision**, because the design file exposes the children as
independent siblings and gives no structural hint that they belong together. It is therefore
confirmed by a human, never inferred. Record the confirmed group as `group-center` with the
group's union box, the shared margins, and each child's offset from the group.

## Acceptance

Verify at two actual App launches: the default profile and a second profile. Record `profileId`,
container `width`, and measurements for each; both must be within tolerance:

```text
left   → leftMargin constant
right  → rightMargin constant
center → centerOffset constant
fill   → both margins constant
```

A node whose edge relationship changes when the container width changes fails acceptance even
when its frame matches the design at the design width.

## Evidence normalization (shared with `ui-review`)

```text
layout evidence:
  figma_id, parent_id, parent_frame
  expected: { layout_anchor, left_margin, right_margin, center_offset }
  profiles: [{ profileId, width, left_margin, right_margin, center_offset }]
```

## Rollback check

An anchor judgement is only useful if it reproduces the design position at the design width.
After confirming anchors, re-derive each node's design-width position from its anchor:

```text
left   → x = P.x + leftMargin
right  → x = P.x + P.w - rightMargin - N.w
center → x = P.x + P.w / 2 + centerOffset - N.w / 2
fill   → x = P.x + leftMargin, w = P.w - leftMargin - rightMargin
```

If the re-derived position differs from the Figma bbox by more than the node's acceptance
tolerance (`±0.5pt` for frame origin/size), the anchor or its recorded margin is wrong — fix it
before implementation. This catches an anchor that "looks right" but silently shifts the node.
