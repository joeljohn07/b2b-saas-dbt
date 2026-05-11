# dbt Guidelines

dbt-specific conventions for this repo. Every rule here is either enforced by a hook, a CI check, or a `dbt-project-evaluator` rule. The goal is that an agent or a new contributor can write a correct model without reading every existing one.

## Naming

### Models

| Layer | Pattern | Example |
|---|---|---|
| Staging | `stg_<source>__<entity>` (double underscore) | `stg_funnel__events`, `stg_billing__invoices` |
| Intermediate | `int_<concept>` | `int_mrr_movements`, `int_identity_stitched` |
| Intermediate — source-specific prep | `int_<source>_prep` | `int_invoices_prep`, `int_marketing_spend_prep` |
| Intermediate — union of multiple sources | `int_<entity>_unioned` | (none current) |
| Mart fact | `fct_<entity>` | `fct_signups`, `fct_mrr_movements` |
| Mart dimension | `dim_<entity>` | `dim_users`, `dim_accounts` |
| Mart bridge | `bridge_<m2m>` | `bridge_user_experiments` |
| Mart aggregation | `agg_<entity>_<grain>` | `agg_sessions_weekly` (not yet built) |
| Mart report | `rpt_<topic>` | `rpt_funnel_summary` (not yet built) |
| Mart blend | `mart_<entity>` | `mart_account_summary` (not yet built) |

Subdirectories provide domain context. The model name itself never repeats the directory: `marts/billing/fct_invoices.sql`, not `marts/billing/fct_billing_invoices.sql`.

### Columns

- snake_case throughout.
- No abbreviations. `subscription_id`, never `sub_id`. `user_id`, never `uid` or `userId`.
- Same business concept = same column name in every model that surfaces it.
- Surrogate keys end in `_key`, always `INT64`, always built with `farm_fingerprint()`.
- Foreign keys are surrogate keys named for the dimension they point to (`account_key`, `user_key`, `date_key`).
- Role-playing FKs are suffixed (`signup_date_key`, `activation_date_key`, `first_touch_channel_key`).
- Boolean columns start with `is_`, `has_`, or `was_`.

## `ref()` vs `source()`

Enforced by `dbt-project-evaluator` DAG rules at `severity: error`:

| Layer | May `ref()` | May `source()` |
|---|---|---|
| Staging | seeds only | yes — the only layer that may |
| Intermediate | staging, other intermediate, seeds | no |
| Marts (`fct_`, `dim_`, `bridge_`) | intermediate, seeds, conformed dimensions | no |
| Marts (`agg_`, `rpt_`, `mart_`) | intermediate, marts, seeds | no |

Violations are caught by `fct_marts_or_intermediate_dependent_on_source` and friends in CI.

## Materialisation

Defaults configured in `dbt_project.yml`:

| Layer | Default | Why |
|---|---|---|
| staging | `view` | Source shapes only — storage cost > query cost. |
| intermediate | `view` | Logic is composable; tables would freeze stale state. |
| marts | `table` | Stable query performance for downstream consumers. |

**The one incremental model:** `int_events_normalized`. Strategy: `merge` on `event_id`; lookback window from `events_incremental_lookback_hours` (36h) anchored on `max(_loaded_at)` of the last run — **not** `current_timestamp` and **not** `event_time`.

When to deviate from defaults:

- **Intermediate → table** — only when a downstream model rebuilds frequently and the view is expensive (BQ slot pressure, repeated joins). Note the reason in `decisions.md`.
- **Marts → incremental** — only when the table grows large enough that full rebuilds violate the build-time budget. Choose `merge` on the natural PK; never `insert_overwrite` without a partition column.
- **Staging → anything other than view** — don't. Staging is a contract; a non-view staging model means the contract is doing transformation work it shouldn't.

## Contracts

`contract.enforced: true` is mandatory on:
- All staging models — the project's interface to its sources.
- All mart `fct_`, `dim_`, `bridge_` models — the project's interface to its consumers.

Contracts are **optional** on mart `agg_`, `rpt_`, `mart_` models. Use them where the model is consumed by an external system that benefits from a stable schema.

Contracts are **forbidden** on intermediate models — intermediate is internal scaffolding and locking the schema would block routine refactors.

## Documentation

### The single rule

**Every column and model description uses `doc(...)` blocks.** Inline `description: "..."` strings are banned. Enforced by `scripts/lint-doc-blocks.sh` at pre-commit and in CI.

Full convention: [`docs/doc-block-convention.md`](doc-block-convention.md).

### Where the doc blocks live

| Layer | File |
|---|---|
| Staging | `models/staging/staging.md` |
| Intermediate | `models/intermediate/intermediate.md` |
| Marts | `models/marts/marts.md` |

dbt resolves doc tags globally, so a doc tag created in `staging.md` can be referenced from any layer downstream.

### Naming pattern

| Scope | Pattern |
|---|---|
| Shared column | `col_<column>` |
| Domain-qualified column | `col_<domain>_<column>` |
| Model | `<model_name>` |
| Source | `src_<source>` |
| Source table | `src_<source>_<table>` |
| Seed | `seed_<seed_name>` |

### When to reuse vs create

- Column flows unchanged through layers → reuse the existing `col_` block via `doc('col_x')`.
- Column is transformed or gains new meaning → create a new block.
- Same column name, different semantics across domains → domain-qualify (`col_billing_status` vs `col_ticket_status`).

## Meta Tags (Marts)

Every mart model declares `meta:` with four keys. Required, validated by review.

```yaml
- name: fct_signups
  description: '{{ doc("fct_signups") }}'
  config:
    contract:
      enforced: true
  meta:
    owner: analytics      # team / role accountable
    pii: false            # true if any column contains PII
    sla: daily            # build cadence: hourly | daily | weekly
    tier: 1               # 1=critical, 2=important, 3=convenience, 4=internal, 5=experimental
```

Values currently in use across the marts:
- `owner: analytics` (single owner — see [`docs/data-boundary.md`](data-boundary.md))
- `pii: false` everywhere (the synthetic dataset contains no real PII)
- `sla: daily` everywhere
- `tier: 1` (conformed dims + core facts), `tier: 2`, `tier: 3` (less critical)

## Tests

The full strategy lives in [`docs/quality-gates.md`](quality-gates.md). The short version:

| Test category | Where | Severity policy |
|---|---|---|
| PK (`unique` + `not_null`) | `_models.yml` | always `error` |
| `accepted_values` | `_models.yml` | `error` |
| `relationships` (FK) | `_models.yml` | `warn` (cost-aware) |
| Invariants | `tests/invariants/` | `error` |
| Reconciliation | `tests/reconciliation/` | `error` with declared tolerance |
| Fanout | `tests/fanout/` | `error` if ratio > 1.01 |
| Contracts smoke | `tests/contracts/` | `error`, CI-only |
| Source freshness | `_sources.yml` | warn 24h, error 48h |

Test file naming: `tests/<category>/<category>_<scope>_<intent>.sql`. Example: `invariants_fct_invoices_is_paid_consistency.sql`.

### TDD gate

`scripts/tdd-gate.sh` runs on `pre-push`. A model change without a corresponding test change blocks the push. To bypass for genuinely test-only or doc-only changes, the script auto-detects the diff shape — no flag needed.

## SQL Style

Enforced by sqlfluff (`.sqlfluff`). The hand-rules below are the ones the linter doesn't catch.

- Lowercase keywords (`select`, `from`, `where`).
- 4-space indent, trailing commas.
- No `select *` — explicit column lists in every model. The lint rule catches this; the convention catches it earlier.
- CTEs over subqueries. Name CTEs for what they hold, not what they do (`active_users`, not `filter_active`).
- One CTE per concept. A 12-CTE model is fine if each CTE is named and ~5–15 lines; a 3-CTE model with one 80-line CTE is not.
- Prefer `group by all` over column ordinals.
- Multi-source unions use `union all` with **explicit matching column lists** — never `select *` even if the upstream models agree today.
- Surrogate keys: `farm_fingerprint(concat(a, '|', b))` with a literal pipe separator. Never bare concatenation (collision risk).

## Custom Macros

Two custom macros, both in `macros/`:

- `dedup_events_row_number.sql` — canonical row-number dedup used by `int_events_normalized`. Defined once; never re-implement.
- `generate_schema_name.sql` — schema-name override so per-PR CI runs land in their own dataset.

**No other custom macros.** If a transformation feels macro-worthy, first check whether `dbt_utils` or `dbt_expectations` already provides it; both packages are installed.

## Project Variables

All business-policy constants are project variables, defined once in `dbt_project.yml`. Changing one requires a `decisions.md` entry.

| Variable | Default | Owner |
|---|---|---|
| `session_timeout_seconds` | 1800 | Sessionisation policy |
| `attribution_lookback_days` | 30 | Marketing attribution window |
| `account_health_trailing_days` | 28 | Account health snapshot window |
| `engagement_active_threshold_days` | 14 | Engagement state classifier |
| `engagement_dormant_threshold_days` | 42 | Engagement state classifier |
| `events_incremental_lookback_hours` | 36 | Incremental dedup window |
| `identity_stitching_lookback_days` | 90 | Bounded anon→user stitch |
| `checkout_conversion_window_days` | 30 | Checkout→sub conversion |
| `retention_maturity_guard_days` | 7 | Cohort completeness gate |
| `project_start_date` | `2024-01-01` | Sentinel for activity-less users |

Never hardcode these values in model SQL.

## Pre-Commit Hooks (Summary)

Run on every commit. Full config in `.pre-commit-config.yaml`. Order matters:

1. File hygiene (whitespace, EOF, YAML syntax, merge markers)
2. `sqlfluff` lint (Jinja templater for speed; CI uses dbt templater for full accuracy)
3. `dbt-parse`, `check-model-has-tests`, `check-model-has-properties`, `check-model-has-description`
4. Doc-block lint
5. Secret scan
6. Conventional-commit message (commit-msg hook)
7. TDD gate (pre-push hook)

Never bypass with `--no-verify`. If a hook is wrong, fix the hook.

## See Also

- [`docs/architecture.md`](architecture.md) — system design.
- [`docs/layers/layer-contract.md`](layers/layer-contract.md) — the executable layer rules.
- [`docs/doc-block-convention.md`](doc-block-convention.md) — full doc-block convention.
- [`docs/quality-gates.md`](quality-gates.md) — test severity matrix.
- [`docs/review/pr-checklist.md`](review/pr-checklist.md) — what a PR review looks at.
- [`docs/review/common-mistakes.md`](review/common-mistakes.md) — patterns to avoid.
