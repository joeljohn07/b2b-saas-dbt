# Common Mistakes

Anti-patterns to catch during review and audit. Ordered by frequency.

## Documentation

1. **Inline descriptions in _models.yml** — Every description must use `{{ doc() }}` blocks. Enforced by `scripts/lint-doc-blocks.sh`.
2. **Duplicate doc blocks** — Same column described twice with different wording. One canonical block per concept.
3. **Missing doc blocks for new columns** — Column added to model but no `col_` block created in `docs/columns.md`.
4. **Wrong doc block scope** — Using `col_status` when the column is domain-specific (should be `col_ticket_status`).

## Layer Violations

5. **`source()` in intermediate or marts** — Intermediate must use `ref()` to staging. Marts must `ref()` intermediate.
6. **`ref()` staging from marts** — Marts must go through intermediate. If the staging model is needed directly, create a thin `int_*_prep` model.
7. **Business logic in staging** — No joins, aggregations, window functions, or derived columns in staging. Only 1:1 shaping.
8. **`contract.enforced` on intermediate** — Intermediate is internal; contracts not needed. Only staging + fct_/dim_/bridge_ marts.
9. **Wrong materialization** — Staging = view. Intermediate = view (exception: int_events_normalized is incremental). Marts = table.

## Testing

10. **Missing PK tests** — Every model needs `not_null` + `unique` on its primary key. No exceptions.
11. **`accepted_values` on BigQuery BOOL** — Doesn't work. BigQuery BOOL is native; use `contract.enforced` with `data_type: boolean` instead.
12. **Missing FK relationship tests** — Every FK column should have a `relationships` test. Prefer testing in staging (cheaper).
13. **Missing `accepted_values` on categoricals** — Every CASE WHEN output and status/type/category column needs `accepted_values`.
14. **Wrong severity** — PK violations and contract enforcement must be `error`. Data quality alerts and large-table relationship tests should be `warn`.

## Naming

15. **Wrong prefix** — staging: `stg_{source}__{entity}`, intermediate: `int_{concept}` (subdirectory provides domain context), marts: `fct_`/`dim_`/`bridge_`/`agg_`/`rpt_`/`mart_`.
16. **Single underscore in staging** — Must be double: `stg_{source}__{entity}`.
17. **Column name drift** — Same concept must use same column name everywhere.

## Marts-Specific

18. **Missing `meta`** — All marts models require: owner, pii (boolean), sla, tier (1-5).
19. **Missing contracts on fct_/dim_/bridge_** — These model types always need `contract.enforced: true`.
20. **Non-conformed dimension keys** — Fact tables must use shared dim keys, not local FK columns.

## Locked Business Logic Violations

These decisions are frozen. Any model that contradicts them is wrong.

21. **Identity stitching** — Must use 90-day stitch window, half-open intervals `[valid_from, valid_to)`, deterministic last-touch join. Join: `LEFT JOIN ... ON anon_id AND event_time >= valid_from AND event_time < valid_to`.

22. **Sessionization** — 30-minute inactivity timeout. Sessions span midnight. Session ID = `hash(anon_id + first_event_id)` — immutable, no stitched identity in the key.

23. **Engagement states** — 4 mutually exclusive states: `pre_active`, `active`, `dormant`, `disengaged`. `is_re_engaged` is a boolean flag, NOT a state. Thresholds: active (14d), dormant (14-42d), disengaged (42d+).

24. **Attribution** — User-level only (account-level in dim_accounts only). First-touch + last-touch, 30-day window before activation. Conversion event = `activation` event_type.

25. **Retention** — Pre-computed in dbt as `fct_retention_cohorts`. Activation-week cohorts, `cohort_week_start_date` (DATE, always Monday). `is_period_complete` guard with 7-day buffer.

26. **Canonical activation** — `activation` event_type is THE definition everywhere: funnel, attribution, retention, engagement.
