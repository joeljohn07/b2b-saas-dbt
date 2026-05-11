# Event Contract

Schema, types, and semantics for events flowing into this project. The contract is enforced in the staging layer via dbt model contracts (`contract.enforced: true`), so any drift in a source surface fails the build.

## Sources

Five raw tables across four BigQuery datasets feed the staging layer. All carry `_loaded_at` for ingestion-time tracking and dbt source freshness (warn 24h, error 48h).

| Dataset | Table | Grain | Volume (synthetic) |
|---|---|---|---|
| `raw_funnel` | `events` | one row per product event | ~5.5M / 24mo / 50K users |
| `raw_billing` | `subscriptions` | one row per subscription event | ~150K |
| `raw_billing` | `invoices` | one row per invoice | ~200K |
| `raw_marketing` | `spend` | one row per channel × day | ~30K |
| `raw_support` | `tickets` | one row per ticket | ~40K |

## `raw_funnel.events`

The product event stream. Every user interaction with the application lands here.

### Identifiers

| Field | Type | Nullable | Notes |
|---|---|---|---|
| `event_id` | STRING | NO | Stable, unique. Dedup key in `int_events_normalized`. |
| `user_id` | STRING | YES | NULL for anonymous events (pre-signup). |
| `anon_id` | STRING | NO | Always present. Stitches to `user_id` via `int_identity_stitched`. |
| `account_id` | STRING | YES | NULL until the user joins or creates an account. |

### Timestamps

| Field | Type | Semantics |
|---|---|---|
| `event_time` | TIMESTAMP | When the event happened, per the client. May be backdated by late delivery. |
| `ingest_time` | TIMESTAMP | When the collector received the event. |
| `_loaded_at` | TIMESTAMP | When the row landed in BigQuery. Anchors incremental lookbacks. |
| `event_date` | DATE | Partition key. Derived from `event_time`. |

**`event_time` vs `_loaded_at`** — `int_events_normalized` is incremental and uses a 36-hour lookback anchored to `_loaded_at`, not `event_time`. A late-arriving event has an old `event_time` but a recent `_loaded_at`; anchoring to `event_time` would miss it entirely. The `events_incremental_lookback_hours` var controls the window.

### Event Classification

| Field | Type | Domain |
|---|---|---|
| `event_type` | STRING | See enum below. |
| `platform` | STRING | `web`, `ios`, `android`, `api`. |
| `channel` | STRING | First-touch acquisition channel (organic, paid, referral, direct). |
| `plan_context` | STRING | Plan the user was on when the event fired (free, trial, starter, growth, enterprise). |

#### `event_type` enum

| Value | Phase | Required properties |
|---|---|---|
| `page_view` | navigation | `page_url`, `referrer` |
| `signup` | acquisition | `signup_method` |
| `activation` | activation | `activation_action`, `time_to_activate_hours` |
| `feature_use` | engagement | `feature_name`, `duration_seconds` |
| `paywall_view` | monetization | `source_page` |
| `upgrade_click` | monetization | `source_page`, `target_plan` |
| `checkout_start` | monetization | `target_plan`, `billing_cycle` |
| `member_invited` | team | `role` (invited role) |
| `member_joined` | team | `role` (joined role) |
| `member_removed` | team | `reason` |

The `properties` JSON column carries event-specific payloads. The staging model shreds the per-event-type keys into typed columns (`signup_method`, `activation_action`, `feature_name`, etc.); each is NULL when not applicable.

### Marketing Attribution

UTM parameters carried on every event for last-touch attribution. NULL for organic/direct.

| Field | Type |
|---|---|
| `utm_source` | STRING |
| `utm_medium` | STRING |
| `utm_campaign` | STRING |
| `utm_term` | STRING |
| `utm_content` | STRING |

### Device

`device_type`, `browser`, `os`, `user_agent` — all STRING, all nullable.

### Experiments

`experiment_flags` — JSON string holding `{experiment_id: variant_id}` pairs active at event time. Passed through staging unchanged; unnested in `int_experiment_results` and surfaced in `fct_experiment_exposures` / `bridge_user_experiments`.

## `raw_billing.subscriptions`

Subscription state-change events. One row per change.

| Field | Type | Notes |
|---|---|---|
| `subscription_event_id` | STRING | PK. |
| `subscription_id` | STRING | Stable across the lifetime of a subscription. |
| `user_id` | STRING | Buyer of record. |
| `account_id` | STRING | Account the subscription belongs to. |
| `event_type` | STRING | See enum below. |
| `event_time` | TIMESTAMP | When the change took effect. |
| `_loaded_at` | TIMESTAMP | Ingestion timestamp. |
| `plan` | STRING | Plan after the change. |
| `previous_plan` | STRING | Plan before. NULL on `subscription_start`. |
| `billing_cycle` | STRING | `monthly` or `annual`. |
| `mrr_amount` | NUMERIC | Normalized monthly revenue after the change. |
| `currency` | STRING | ISO 4217. |
| `cancel_reason` | STRING | NULL except on `cancellation`. |
| `is_voluntary` | BOOLEAN | NULL except on `cancellation`. |

`event_type` enum: `trial_start`, `trial_end`, `subscription_start`, `renewal`, `upgrade`, `downgrade`, `cancellation`, `reactivation`.

These are not classified into MRR movements at the raw level — that classification (`new`, `expansion`, `contraction`, `churn`, `reactivation`) is the job of `int_mrr_movements` and is the single source of truth for MRR motion.

## `raw_billing.invoices`

One row per invoice issued. `line_items` is passed through as raw JSON (variable-length structure consumed directly by reporting tools) — not shredded in staging.

Key fields: `invoice_id` (PK), `subscription_id`, `account_id`, `issued_at`, `paid_at` (NULL until paid), `refunded_at` (NULL unless refunded), `amount_due`, `amount_paid`, `currency`, `line_items` (JSON).

`is_paid` semantics: `true` iff `paid_at IS NOT NULL AND refunded_at IS NULL`. Refunded invoices count as recognised revenue at the time of payment, not as payment history — i.e., once refunded, `is_paid` flips back to `false`. Documented in the `col_is_paid` doc block.

## `raw_marketing.spend`

One row per channel × day. Spend, impressions, clicks. No user-level data — joined to `fct_marketing_spend` for attribution rollups via `dim_channels`.

Key fields: `spend_id` (PK), `spend_date` (DATE), `channel`, `campaign`, `spend_amount`, `currency`, `impressions`, `clicks`.

## `raw_support.tickets`

One row per support ticket.

Key fields: `ticket_id` (PK), `account_id`, `user_id`, `created_at`, `resolved_at` (NULL until resolved), `category`, `priority`, `csat` (1-5, NULL if no survey response).

## Conventions Across All Sources

### `_loaded_at` is mandatory

Every source row carries `_loaded_at`. It's the freshness anchor (declared in `_sources.yml` per table) and the incremental anchor for any model materialising downstream of that source.

### Naming

- Snake_case throughout. No abbreviations (`subscription_id`, not `sub_id`).
- Same concept = same column name in every model that surfaces it. `user_id` is always `user_id`, never `uid` or `userId`.

### Type Canonicalisation

Staging casts to one of: `TIMESTAMP`, `DATE`, `STRING`, `INT64`, `NUMERIC`, `BOOL`. No `FLOAT64` for monetary values — all currency uses `NUMERIC`. No `JSON` outside the two declared exceptions (`properties`, `line_items`).

### Late Arrivals

Anchored on `_loaded_at`, not source-event time. The 36-hour lookback on `int_events_normalized` is the authoritative dedup window for the funnel; events older than 36h that arrive late will not be picked up by the incremental run and require a `--full-refresh`.

### Identity

A user has at most one `user_id`. They may have many `anon_id`s (one per browser/device). `int_identity_stitched` resolves anon→user with a 90-day lookback (`identity_stitching_lookback_days`). Beyond that window, stitches do not propagate — see `decisions.md` for rationale.

## Generating Synthetic Data

The reference dataset is produced by `scripts/generate_synthetic_data.py`. It generates 50K users × 24 months and uploads to the raw datasets. Run targets:

```
uv run python scripts/generate_synthetic_data.py --users 50000 --months 24 --upload
```

Determinism is required: a fixed `--seed` produces byte-identical output. CI uses a deterministic small dataset for build verification.

## See Also

- [`docs/architecture.md`](architecture.md) — where these events flow once they hit staging.
- [`docs/metric-contract.md`](metric-contract.md) — what we measure from these events.
- [`models/staging/<domain>/_models.yml`](../models/staging) — the executable contract (enforced at parse time).
