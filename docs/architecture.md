# Architecture

System design for the `b2b-saas-dbt` analytics platform.

## Goals

A single source of truth for B2B SaaS analytics where business logic is defined exactly once. Five raw source domains feed a Kimball star schema. Every metric that appears in any consumer — dashboard, ad-hoc query, agent answer — resolves back to one definition in this repo.

## Source Domains

| Domain | Raw dataset | Entities |
|---|---|---|
| Product / funnel | `raw_funnel` | events |
| Billing | `raw_billing` | subscription_events, invoices |
| Marketing | `raw_marketing` | spend |
| Support | `raw_support` | tickets |

Source contracts are declared in `models/staging/<domain>/_sources.yml` with freshness SLAs on `_loaded_at`.

## Three Layers

```
raw sources           staging              intermediate            marts
───────────          ─────────            ──────────────         ─────────
raw_funnel     ───►  stg_*__events   ───► int_events_normalized ──► fct_sessions
raw_billing    ───►  stg_*__subs     ───► int_mrr_movements     ──► fct_mrr_movements
               ───►  stg_*__invoices ───► int_attribution       ──► dim_users
raw_marketing  ───►  stg_*__spend    ───► int_engagement_states ──► dim_accounts
raw_support    ───►  stg_*__tickets  ───► int_account_health    ──► dim_date

                     view, 1:1            view (default), logic    table, star schema
                     contracts enforced   incremental on events    contracts on fct/dim/bridge
```

### Staging — interface

One model per source table. Renames, casts, JSON shreds. No joins, no aggregations, no derived columns. Materialized as views with `contract.enforced: true`, so any breaking source-schema change fails fast.

Reference: [`docs/layers/layer-contract.md`](layers/layer-contract.md).

### Intermediate — logic

All non-trivial business decisions live here. Each is anchored in one model with one canonical definition:

| Decision | Model | Lookback / window var |
|---|---|---|
| Event dedup + late-arrival handling | `int_events_normalized` | `events_incremental_lookback_hours` (36h) |
| Anonymous→known user stitching | `int_identity_stitched` | `identity_stitching_lookback_days` (90d) |
| Sessionization | `int_sessions` | `session_timeout_seconds` (1800s) |
| Marketing attribution | `int_attribution` | `attribution_lookback_days` (30d) |
| Subscription state machine | `int_subscription_lifecycle` | — |
| MRR movement classification | `int_mrr_movements` | — |
| Weekly engagement state | `int_engagement_states` | `engagement_active_threshold_days`, `engagement_dormant_threshold_days` |
| Account health score | `int_account_health` | `account_health_trailing_days` (28d) |
| Checkout→subscription conversion | `int_checkout_conversion` | `checkout_conversion_window_days` (30d) |

Every business policy is a project variable, not a hardcoded interval. Changing one of them is a `dbt_project.yml` edit plus a `decisions.md` entry, not a code search.

Materialized as views by default; `int_events_normalized` is the only incremental model. References staging or other intermediate models via `ref()` — never `source()`.

### Marts — consumer surface

Kimball star schema. Three model types carry `contract.enforced: true`:

- **Facts** (`fct_*`): one row per business event or snapshot. Grain declared in model description.
- **Dimensions** (`dim_*`): one row per entity. SCD Type 1 only — history lives in intermediate snapshot models.
- **Bridges** (`bridge_*`): one row per many-to-many relationship.

Optional model types (`agg_`, `rpt_`, `mart_`) sit on top of facts and dimensions for query patterns that need pre-aggregation, dashboard-specific denormalization, or dim+fact blends. Contracts on these are opt-in.

Conformed dimensions live in `marts/core/`. Domain-specific dimensions (e.g., `dim_sessions`, `dim_experiments`) live with their domain. All surrogate keys use `farm_fingerprint()` for INT64 hashes — consistent across the star, no UUID strings.

Reference: [`docs/layers/dimensional-modeling-guidelines.md`](layers/dimensional-modeling-guidelines.md).

## Materialization Policy

| Layer | Default | Exception |
|---|---|---|
| staging | `view` | — |
| intermediate | `view` | `int_events_normalized` is `incremental` (merge on `event_id`, 36h lookback on `_loaded_at`) |
| marts | `table` | — |

Views minimise BigQuery storage cost in dev; tables on marts give stable query performance for downstream consumers.

## DAG Boundaries

Enforced by `dbt-project-evaluator` (rules in `dbt_project.yml`, severity = `error`):

- `fct_*` and `dim_*` never reference staging or source directly.
- Marts never join to a source.
- Intermediate is the only layer that can both `ref()` staging and produce inputs for marts.

Violations fail CI.

## Naming

- Staging: `stg_<source>__<entity>` (double underscore separates source from entity).
- Intermediate: `int_<concept>`, with optional suffixes `_prep` (source-specific rules before union) and `_unioned` (union of multiple sources).
- Marts: `fct_<event>`, `dim_<entity>`, `bridge_<relationship>`, `agg_<grain>`, `rpt_<consumer>`, `mart_<entity>`.

Subdirectories provide domain context, never role-played in the model name itself.

## Documentation Ownership

Every column description lives once. Authored in `_<scope>__docs.md` files using dbt's `docs` Jinja blocks; referenced from `schema.yml` via the `doc(...)` macro. Pass-through columns reuse the same doc tag across layers; transformed columns get a new doc block authored where the transformation lives.

Reference: [`docs/doc-block-convention.md`](doc-block-convention.md).

## Testing Strategy

Four test directories, each with a clear charter:

- `tests/invariants/` — things that must always be true (e.g., session boundaries don't overlap, retention rates ∈ [0,1]).
- `tests/reconciliation/` — mart row counts and totals reconcile to upstream intermediate (e.g., `fct_mrr_movements` net = `int_mrr_movements` sum).
- `tests/fanout/` — guards against unintended grain expansion (e.g., `fct_sessions` row count = `int_sessions` row count).
- `tests/contracts/` — populated-table assertions for the production marts.

Plus per-column tests in `_models.yml`: `unique`, `not_null`, `accepted_values`, `relationships`, dbt-utils helpers.

Reference: [`docs/quality-gates.md`](quality-gates.md).

## CI

Two workflows in `.github/workflows/`:

- `ci.yml` — runs on every PR: dbt parse, sqlfluff lint, dbt-project-evaluator, full build into a per-PR BigQuery dataset, then `dbt test`. Per-PR dataset isolation prevents cross-PR collision; teardown handled by `pr-teardown.yml` on PR close.
- `pr-teardown.yml` — drops the per-PR dataset.

CI runs against BigQuery (no DuckDB stand-in). The synthetic dataset is ~50K users × 24 months — large enough to surface incremental-strategy and join-grain bugs.

## Cross-Repo Position

This repo is the data foundation. Two sibling repos (planned, not yet built) consume it:

- `b2b-saas-lightdash` — BI semantic layer over the marts.
- `analytics-agent` — agentic Q&A over the BigQuery + dbt + Lightdash MCP surfaces.

Marts are the contract surface for both. The dbt semantic layer (not yet enabled) will be the canonical metric definitions.

## See Also

- [`README.md`](../README.md) — the elevator-pitch version of this doc.
- [`decisions.md`](../decisions.md) — every architectural call with rationale and alternatives considered.
- [`docs/event-contract.md`](event-contract.md) — exact event schema.
- [`docs/metric-contract.md`](metric-contract.md) — canonical metric definitions.
- [`RUNBOOK.md`](../RUNBOOK.md) — setup, build, and incident response.
