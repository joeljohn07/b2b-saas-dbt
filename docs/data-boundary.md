# Data Boundary

What this project owns, what it consumes, and what it does not touch. The boundary is intentionally narrow: the project's job is to model five raw source domains into a Kimball star schema. Anything outside that is somebody else's system.

## Ownership

### Owned by this project

- The five staging models (`stg_*`) that define the contract between the raw datasets and the rest of the warehouse.
- All intermediate models — every business rule that turns raw events into measurable behaviour.
- All mart models — facts, dimensions, bridges, and any aggregations or reports built on top.
- All test logic in `tests/` and per-model tests in `_models.yml`.
- The doc-tag library in `models/<layer>/<layer>.md`.
- Project variables in `dbt_project.yml`.
- The synthetic data generator (`scripts/generate_synthetic_data.py`) — the canonical reproducer for the raw datasets.

If a column changes shape inside any of the above, that's a change to this project.

### Not owned by this project

- The raw datasets themselves (`raw_funnel`, `raw_billing`, `raw_marketing`, `raw_support`). In a real organisation these would be produced by upstream ingestion (Fivetran, Segment, application events). For this portfolio project, the synthetic generator stands in for those producers — but the *contract* (column names, types, semantics) is what this project depends on, not the implementation.
- BI dashboards, agents, and downstream applications consuming the marts. Declared as `exposures` (see below) but not implemented in this repo.
- The Lightdash semantic layer (planned in `b2b-saas-lightdash`).
- The agent / Q&A surface (planned in `analytics-agent`).

## Sources and SLAs

All sources land via the same five raw tables. Freshness SLAs are uniform — declared in `_sources.yml` per table.

| Source | Table | Freshness warn | Freshness error | Producer (notional) |
|---|---|---|---|---|
| `funnel` | `events` | 24h since `_loaded_at` | 48h | Product event collector |
| `billing` | `subscriptions` | 24h | 48h | Subscription management system |
| `billing` | `invoices` | 24h | 48h | Billing system |
| `marketing` | `spend` | 24h | 48h | Marketing platform exports |
| `support` | `tickets` | 24h | 48h | Support ticketing system |

Every source row carries `_loaded_at` — the row's BigQuery arrival time. It is the freshness anchor and the incremental anchor for any model downstream.

When a source breaches the warn threshold, the source-freshness test surfaces in CI as a warning. The error threshold blocks merge.

## Meta Tags on Marts

Every mart model declares four meta keys. They make ownership, sensitivity, cadence, and importance machine-readable.

| Key | Domain | Value seen in repo |
|---|---|---|
| `owner` | Team / role accountable for the model | `analytics` |
| `pii` | `true` if any column contains PII | `false` everywhere |
| `sla` | Build cadence: `hourly`, `daily`, `weekly` | `daily` |
| `tier` | Importance: 1 (critical) – 5 (experimental) | `1`, `2`, or `3` |

The tier values in use:
- **Tier 1** — conformed dimensions (`dim_users`, `dim_accounts`, `dim_date`, `dim_channels`) and the headline facts they support (`fct_signups`, `fct_activations`, `fct_mrr_movements`, `fct_subscriptions`, `fct_invoices`, `fct_retention_cohorts`).
- **Tier 2** — domain-specific operational facts (`fct_sessions`, `fct_feature_usage`, `fct_support_tickets`, `fct_marketing_spend`).
- **Tier 3** — experimentation surface (`fct_experiment_exposures`, `dim_experiments`, `bridge_user_experiments`, `dim_sessions`).

In a real organisation the tier would drive on-call response and incident escalation. In this project it documents priority for build-time budgeting and selective `--select` strategies.

## PII

The synthetic dataset contains no real personal data. The generator produces fabricated identifiers, fabricated event payloads, and fabricated marketing UTMs. Every mart model carries `pii: false`.

If this project were adapted to ingest a real production source, the boundary would shift as follows:

- Columns to classify as PII: `user_id` (if it maps to a real person), `email` (if present in source), `ip_address`, `user_agent` when combined with stable identifiers, and any free-text `properties` payload from product events.
- Staging would be the layer responsible for hashing, tokenisation, or column-dropping. Marts should never see raw PII.
- The `pii: true` flag on a mart model would trigger downstream access controls (row-level security, masking policies) that this repo does not currently implement.

`docs/event-contract.md` documents the exact source columns; classifying which would be PII in a real ingest is straightforward from that surface.

## Retention

The project does not implement retention or deletion of source data — that is the upstream producer's responsibility. The marts are derived state and can be rebuilt from sources at any time.

For the synthetic dataset:
- Generator produces 24 months of history with a fixed `--seed`, so any "retention" question is answered by re-running the generator at a different `--months` value.
- The CI per-PR BQ dataset is deleted by `pr-teardown.yml` on PR close.
- Dev and prod datasets are user-managed (no in-project lifecycle policy).

For a real adaptation: GDPR-style erasure would land at the staging layer (delete the rows in `raw_*`, rebuild downstream with `dbt build --full-refresh`). Marts contain no source-of-record state that exists nowhere else, so erasure is always a re-derivation, never a manual mart edit.

## Downstream Consumers (Exposures)

Three exposures are declared in `models/marts/exposures.yml`. They serve as documented downstream dependencies — every model they `depends_on` is protected from breaking changes without the consumer being part of the conversation.

| Exposure | Type | Depends on |
|---|---|---|
| `product_analytics_dashboard` | dashboard | `fct_sessions`, `fct_feature_usage`, `fct_signups`, `fct_activations`, `dim_users`, `dim_accounts`, `dim_sessions` |
| `revenue_dashboard` | dashboard | `fct_mrr_movements`, `fct_subscriptions`, `fct_invoices`, `dim_accounts` |
| `growth_and_retention_dashboard` | dashboard | `fct_retention_cohorts`, `fct_marketing_spend`, `fct_experiment_exposures`, `dim_channels`, `dim_experiments` |

All three are notional — they document the intended consumer surface for the planned Lightdash project, not actual hosted dashboards.

## What Crossing the Boundary Looks Like

A change is "outside this project" if it would require:
- Editing a raw dataset (run the generator instead).
- Adding a consumer (declare an exposure, build the consumer in the sibling repo).
- Changing the contract on a source (coordinate with the notional upstream producer — for this project, the generator script).

A change is "inside this project" if it would require:
- Adding or modifying a staging, intermediate, or mart model.
- Adding or modifying a test.
- Changing a project variable.
- Adding a doc tag or updating an existing one.

## See Also

- [`docs/architecture.md`](architecture.md) — three-layer system design.
- [`docs/event-contract.md`](event-contract.md) — exact source schemas.
- [`docs/metric-contract.md`](metric-contract.md) — what each canonical metric is.
- [`models/marts/exposures.yml`](../models/marts/exposures.yml) — the executable exposure declarations.
