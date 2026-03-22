# Layer Contract

Rules and conventions for each layer of the dbt project.

## Staging

### Purpose
1:1 shaping of raw sources. Enforces types, naming, and semantic consistency. No business logic.

### Rules
- Materialized: `view`
- `contract.enforced: true` on all staging models
- Only `source()` references — never `ref()`
- No joins, aggregations, window functions, or derived columns
- Explicit column lists — no `select *`

### Naming
- Pattern: `stg_{source}__{entity}` (double underscore separates source from entity)
- Column naming: snake_case, no abbreviations, same concept = same column name across all staging models

### File Organization
- Subdirectories by source system: `funnel/`, `billing/`, `marketing/`, `support/`
- Each subdirectory contains `_sources.yml` (source declarations) and `_models.yml` (schema definitions)

### Transformations
- Column renaming and type casting to canonical types (TIMESTAMP, DATE, STRING, INT64, NUMERIC)
- JSON shredding (properties → flat columns, experiment_flags passed through for downstream unnesting)
- Exception: `line_items` on invoices passed through as raw JSON — shredded in int_invoices_prep
- Null handling for optional fields

---

## Intermediate

### Purpose
All business logic lives here. Dedup, sessionization, identity stitching, attribution, lifecycle state machines, cross-domain joins.

### Rules
- Materialized: `view` (default). Exception: `int_events_normalized` is incremental (merge on event_id, 36h lookback)
- `ref()` staging or other intermediate models only — never `source()`
- No `contract.enforced` (intermediate is internal)

### Naming
- Pattern: `int_{domain}_{concept}`
- Optional suffixes:
  - `_prep` — source-specific business rules applied before joining/unioning (e.g., `int_billing_subscriptions_prep`)
  - `_unioned` — union of multiple sources into one entity (e.g., `int_product_events_unioned`)

### File Organization
- Subdirectories by domain: `product/`, `billing/`, `engagement/`, `cross_domain/`
- Each subdirectory contains one `_models.yml` with all model schemas

### What Belongs Here
- Deduplication and normalization (canonical dedup point: int_events_normalized)
- Sessionization, identity stitching, funnel staging, account memberships
- Attribution, engagement states, experiment results
- Subscription lifecycle, MRR movements
- Cross-domain joins (checkout conversion, ticket metrics, account health)

---

## Marts

### Purpose
Kimball star schema. Consumer-facing facts and dimensions. The most important layer — these tables are what stakeholders access.

### Rules
- Materialized: `table`
- `contract.enforced: true` on `fct_`, `dim_`, `bridge_` models. Optional on `agg_`, `rpt_`, `mart_`
- `ref()` intermediate models for `fct_`, `dim_`, `bridge_` — never `source()`, never staging
- `agg_`, `rpt_`, `mart_` may also `ref()` other marts models (facts, dimensions)
- `meta` required on all models: owner, pii (boolean), sla, tier (1-5)
- Conformed dimensions: shared dim keys across all facts
- Role-playing FKs use suffixed keys (e.g., `session_date_key`, `acquisition_date_key`)

### Model Types

| Prefix | Purpose | Grain | Example |
|--------|---------|-------|---------|
| `fct_` | Measurable business events | One row per event/snapshot | `fct_signups`, `fct_account_mrr_snapshot` |
| `dim_` | Descriptive context, conformed, reusable | One row per entity | `dim_users`, `dim_accounts` |
| `bridge_` | Many-to-many relationship resolution | One row per relationship | `bridge_user_experiments` |
| `agg_` | Pre-aggregated fact at coarser grain | Coarser than parent fact | `agg_sessions_weekly` |
| `rpt_` | Consumer-specific denormalized table | Dashboard-specific | `rpt_funnel_summary` |
| `mart_` | Dimension blended with fact aggregations | One row per entity | `mart_account_summary` |

Facts and dimensions should be built first. Other model types (`agg_`, `rpt_`, `mart_`) reference them and are built after.

### File Organization
- Subdirectories by business area: `core/`, `product/`, `billing/`, `marketing/`, `support/`
- Each subdirectory contains one `_models.yml` with all model schemas
- `core/` holds conformed dimensions and cross-domain facts (e.g., retention cohorts spans product + billing, not owned by either domain)

### What Does Not Belong Here
- Heavy transformations (push to intermediate)
- Raw source references
- Business logic beyond FK assembly in `fct_`, `dim_`, `bridge_` models (aggregation logic is allowed in `agg_`, `rpt_`, `mart_`)
