# Rule: shared chrome

> **Dual-purpose.** When adding new UI, implement to this standard; when accepting, verify against this same standard.

## Applies to

- Any App chrome reused across pages: tab bar, navigation/toolbar, status bar, scroll edge effect, or floating bar.
- Any Figma `INSTANCE` that points to a published/shared component (has `componentId`) and appears on multiple screens.
- Repeated business components inside page content (for example, card cells) are out of scope and follow their own `unit_kind` rules.

## Acceptance criteria

| Check | Expect |
|---|---|
| `component_reuse` | The page references an App-level shared component/view class; reimplementing the same chrome inside the page is forbidden |
| `single_source` | The entire App has exactly one implementation of the chrome; three copied implementations in three view controllers are a defect |
| `state_passed_in` | Selected state/variant is passed by the caller as a parameter (for example, `selectedIndex = 2`); state must not be baked into a page-specific asset |
| `no_page_private_copy` | Exporting or embedding a page-private chrome image to bypass the shared component is forbidden |

## Implementation requirement (new UI)

- During the Figma stage, classify these nodes as `unit_kind: shared-component` and output:
  - `component_ref`: the existing App shared component (class/file name), or `MISSING`.
  - `variant_props`: state that the caller must pass (for example, `selectedIndex` or `tab=2`).
  - `reuse_evidence`: the existing code location (`file:line`).
- If `component_ref = MISSING`, first extract one shared component with a single implementation, then reference it from the page. Never draw a temporary copy inside the page.
- During implementation, the page only passes state; it does not draw the chrome.
- If the existing App already has multiple copied implementations as historical debt, this change must converge them to one shared component and must not add the next copy.

## Acceptance review (verify)

- Search the whole repository for implementation sites of the chrome; more than one non-shared implementation is a finding.
- Check whether a page file contains the chrome image asset name or layer-construction code; either is a finding.
- Check whether selected state is passed as a parameter; otherwise it is a finding.
- Check whether a page-specific chrome asset was added; this is a finding.

## Evidence normalization

Record `component_ref`, `implementation_sites` (repository-wide path + line-number list), `state_source` (parameter name), and `verdict`.
