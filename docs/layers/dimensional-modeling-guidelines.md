# Dimensional Modeling Guidelines

Reference for Kimball patterns used in the marts layer.

## Conformed Dimensions

Conformed dimensions are shared across multiple fact tables via foreign keys. They live in `marts/core/`.

| Dimension | Key | Description |
|-----------|-----|-------------|
| `dim_users` | `user_key` | User attributes, engagement_state, re-engagement flag |
| `dim_accounts` | `account_key` | Account attributes, health_score, MRR, acquisition channel |
| `dim_date` | `date_key` | Calendar dimension (generated from date spine seed) |
| `dim_channels` | `channel_key` | Marketing channel attributes |

Domain-specific dimensions (`dim_sessions`, `dim_experiments`) live in `marts/product/`.

### Role-Playing Foreign Keys

When a fact table references the same dimension multiple times, use suffixed keys:
- `session_date_key` → `dim_date.date_key`
- `acquisition_date_key` → `dim_date.date_key`
- `first_touch_channel_key` → `dim_channels.channel_key`
- `last_touch_channel_key` → `dim_channels.channel_key`

## Fact Table Patterns

### Transaction Facts
One row per business event. Grain is the event itself.
- `fct_signups` — one row per signup event
- `fct_activations` — one row per activation event
- `fct_invoices` — one row per invoice
- `fct_support_tickets` — one row per ticket

### Periodic Snapshot Facts
One row per entity per period. Captures state at regular intervals.
- `fct_account_mrr_snapshot` — one row per account per month
- `fct_retention_cohorts` — one row per cohort_week × retention_period

### Factless Facts
Record events with no measurable metrics — only FK relationships.
- `fct_experiment_exposures` — records which users were exposed to which experiments

## Additional Model Types

### Aggregation Models (`agg_`)
When a fact table's grain is too fine for a common query pattern, create a pre-aggregated model at a coarser grain.

**When to use:** Query patterns consistently roll up a fact to a coarser grain. The aggregation is reusable across multiple consumers.

**When NOT to use:** If only one dashboard needs the rollup, use `rpt_` instead. If the BI tool handles aggregation efficiently, skip it.

### Report Models (`rpt_`)
Consumer-specific denormalized tables built for a specific dashboard or use case. Not meant for reuse. Replaces the `exp_` (export) concept.

**When to use:** A specific consumer needs a pre-joined, pre-filtered, or pivoted output that doesn't generalize. Complex dashboard logic that would clutter fact/dim queries.

**When NOT to use:** If the view is reusable across consumers, it belongs as `fct_`, `dim_`, or `agg_`.

### Mart Models (`mart_`)
Dimension tables blended with fact aggregations. Combines descriptive attributes with pre-computed metrics.

**When to use:** A common access pattern needs both dimension attributes and aggregate measures in one table (e.g., customer dimension with total revenue, lifetime sessions).

**When NOT to use:** If the BI layer can join dims and facts efficiently. Prefer clean separation when possible.

## Dimension Patterns

### SCD Type 1 (Current State Only)
All dimensions in this project use SCD Type 1 — only the current state is stored. Historical changes are tracked in intermediate layer models (e.g., `int_engagement_states` stores weekly snapshots of user engagement state).

### SCD Type 2 (Historical Tracking) — Future Pattern
If historical dimension tracking becomes necessary:
- Use dbt snapshots in a `snapshots/` directory
- Snapshot close to raw data (staging layer adjacency)
- Config: `strategy='timestamp'`, `updated_at` column
- Not currently implemented — all dims are Type 1

### Degenerate Dimensions
Dimension attributes stored directly on fact tables (no separate dim table).
- Example: `variant` on `fct_experiment_exposures`

## Column Naming

### Consistency Rule
All columns referring to the same business concept must use the same name across every model in the project.

| Concept | Canonical Name | NOT |
|---------|---------------|-----|
| User identifier | `user_id` | `uid`, `user_identifier`, `usr_id` |
| Account identifier | `account_id` | `acct_id`, `workspace_id` |
| Event timestamp | `event_time` | `event_ts`, `timestamp`, `created` |
| Load timestamp | `_loaded_at` | `loaded_timestamp`, `ingest_time` |
| Currency code | `currency` | `currency_code`, `curr` |
