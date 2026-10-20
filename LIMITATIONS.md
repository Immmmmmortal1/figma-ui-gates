# Limitations

This skill makes the checks that can be deterministic hard gates. It does not claim to prove the
following items mechanically.

| Limitation | Reason | Current substitute |
|---|---|---|
| Semantic correctness of review judgments | A record cannot prove that a reviewer genuinely inspected or understood the evidence. | Require reviewer identity, verdict, findings shape, and existing evidence paths; these records are not tamper-proof. |
| Design intent and business correctness | The skill accepts geometry, assets, and declared runtime semantics, not product meaning. | Approved project requirements and product review remain authoritative. |
| Short/long-content coverage | Content boundaries require project-specific data fixtures. | Use the supplied fixture and record both states; without one, record `n/a` plus the reason in G9. |
| No `previousGateDigest` chain | A digest chain is intentionally not implemented in this version. | Require consecutive `sequence` values and non-decreasing `recordedAt` timestamps. |
| Runtime color observability | Color checks depend on the App bridge exposing `textColor` and `backgroundColor`. | If the bridge lacks either field, record that item explicitly as `unobservable` in G10; never silently pass it. |
| Runtime image identity observability | Default identity depends on non-null `imageAssetName`; hash mode depends on `imageHash`. | A null asset name is explicitly `unobservable` in G10; selecting hash mode without `imageHash` blocks preflight. |
