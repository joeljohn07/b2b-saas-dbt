# Metric Contract

Canonical metric definitions. Every headline KPI in this project resolves to exactly one model and one column. If a number on a dashboard, in an answer, or in an ad-hoc query doesn't match one of these definitions, the dashboard is wrong.

## Conventions

- **Grain** — what one row represents at the source-of-truth model.
- **Formula** — the computation. Where it's an aggregation, the aggregation is named.
- **Source model** — the model where the metric is canonically computed. Downstream consumers reference this.
- **Owner** — the team / role accountable for the definition. Changes require their sign-off and a `decisions.md` entry.
- **Test evidence** — the test file proving the metric holds invariants.

Currency: all monetary values are `NUMERIC`, normalised to USD-equivalent in the synthetic dataset (single-currency assumption). Multi-currency support deferred.

---

## Activation & Acquisition

### Signups

| Field | Value |
|---|---|
| Definition | Distinct users with a `signup` event in the funnel. |
| Grain | One row per signup event (a user signs up exactly once). |
| Formula | `count(*) from fct_signups` over a time window. |
| Source model | `models/marts/core/fct_signups.sql` |
| Time anchor | `signup_date_key` |
| Owner | Growth analytics |
| Test evidence | `_models.yml` `unique` + `not_null` on `user_key`. |

### Activations

| Field | Value |
|---|---|
| Definition | Users who completed an activation action within the activation window. |
| Activation actions | `complete_onboarding`, `create_first_report`, `invite_teammate`, `connect_datasource` (see `event-contract.md`). |
| Grain | One row per user per activation date. |
| Formula | `count(*) from fct_activations` over a time window. |
| Source model | `models/marts/core/fct_activations.sql` |
| Owner | Growth analytics |
| Test evidence | `_models.yml` `unique` on `farm_fingerprint(concat(user_id, '|', date))`. |

### Time to Activate

| Field | Value |
|---|---|
| Definition | Hours from `signup` event to first `activation` event for the same user. |
| Grain | One row per activated user. |
| Formula | Carried on the `activation` event as `time_to_activate_hours` (set by the producing system). |
| Source model | `fct_activations.time_to_activate_hours` |
| Owner | Growth analytics |

### Activation Rate

| Field | Value |
|---|---|
| Definition | Activated users ÷ signed-up users, for a cohort. |
| Grain | Aggregation over a signup cohort (defined by signup week or month). |
| Formula | `count(distinct activated_user_id) / count(distinct signup_user_id)` within cohort. |
| Source model | Computed at consumption time from `fct_signups` and `fct_activations`. Pre-aggregated form available in `fct_retention_cohorts` for cohort-week × period. |
| Owner | Growth analytics |

---

## Revenue (MRR)

The MRR motion model is the single source of truth for all revenue movement. Anywhere MRR appears, it resolves to a sum over `fct_mrr_movements.mrr_delta`.

### MRR Movements

| Field | Value |
|---|---|
| Definition | Every change in monthly recurring revenue, classified into one of five types. |
| Grain | One row per subscription state change per account. |
| Movement types | `new`, `expansion`, `contraction`, `churn`, `reactivation`. |
| Source model | `models/marts/billing/fct_mrr_movements.sql` |
| Classification logic | `models/intermediate/billing/int_mrr_movements.sql` — based on prior MRR, new MRR, and subscription `event_type`. |
| Owner | Revenue / finance analytics |
| Test evidence | `tests/invariants/invariants_fixture_session_boundary_split.sql` (movement arithmetic), `tests/reconciliation/reconciliation_fct_mrr_movements_vs_int.sql`, `tests/fanout/fanout_fct_mrr_movements_vs_int_mrr_movements.sql`. |

Classification rules (canonical, lifted from `int_mrr_movements`):

| Subscription `event_type` | MRR delta | `movement_type` |
|---|---|---|
| `subscription_start` (first ever) | > 0 | `new` |
| `reactivation` | > 0 | `reactivation` |
| `cancellation` | full prior MRR → 0 | `churn` |
| `upgrade` / plan change | > 0 | `expansion` |
| `downgrade` / plan change | < 0 | `contraction` |

### Net MRR

| Field | Value |
|---|---|
| Definition | Cumulative sum of `mrr_delta` over time. |
| Formula | `sum(mrr_delta)` from `fct_mrr_movements`. |
| Owner | Revenue analytics |

### Net Revenue Retention (NRR)

| Field | Value |
|---|---|
| Definition | (Starting MRR + expansion − contraction − churn) ÷ Starting MRR, per cohort. |
| Grain | One row per account cohort × period. |
| Formula | Computed from `fct_mrr_movements` filtered to a starting-MRR cohort. |
| Source model | Computed at consumption time. Pre-aggregated form planned in `rpt_nrr_by_cohort` (not yet built). |
| Owner | Revenue analytics |

### Invoices

| Field | Value |
|---|---|
| Definition | One row per invoice issued. |
| `is_paid` rule | `true` iff `paid_at IS NOT NULL AND refunded_at IS NULL`. Refunded invoices flip back to `false`. |
| Source model | `models/marts/billing/fct_invoices.sql` |
| Test evidence | `tests/invariants/invariants_fct_invoices_is_paid_consistency.sql`. |

---

## Engagement

### Sessions

| Field | Value |
|---|---|
| Definition | A user's contiguous activity in the product, split by 30 minutes of inactivity. |
| Sessionisation rule | A new session starts after `session_timeout_seconds` (1800) of inactivity. |
| Grain | One row per session. |
| Source model | `models/marts/product/fct_sessions.sql` (from `int_sessions`). |
| Owner | Product analytics |
| Test evidence | `tests/invariants/invariants_int_sessions_no_overlap.sql`, `tests/fanout/fanout_fct_sessions_vs_int_sessions.sql`. |

Anonymous sessions (`user_id IS NULL`) are allowed in the fact — the `not_null` test on `user_id` is intentionally relaxed.

### Engagement State

| Field | Value |
|---|---|
| Definition | A user's engagement classification snapshot, computed weekly. |
| States | `new`, `active`, `at_risk`, `dormant`, `churned`. |
| Boundaries | `active` if last activity ≤ `engagement_active_threshold_days` (14d) from snapshot end; `dormant` if > `engagement_dormant_threshold_days` (42d). |
| Time anchor | `snapshot_week_end` (week_start + 6) — not `snapshot_week_start`. |
| Source model | `models/intermediate/engagement/int_engagement_states.sql` |
| Surfaced in | `dim_users.engagement_state` (current state), `int_engagement_states` (historical). |
| Owner | Product analytics |

### Re-engagement

| Field | Value |
|---|---|
| Definition | A previously dormant or churned user who returns to active state. |
| Flag | `dim_users.is_re_engaged` (BOOLEAN). |
| Owner | Product analytics |

### Feature Usage

| Field | Value |
|---|---|
| Definition | Count of `feature_use` events per user per feature. |
| Grain | One row per `(user_id, feature_name, event_date)`. |
| Source model | `models/marts/product/fct_feature_usage.sql` |
| Filter | Anonymous events excluded (`user_id IS NOT NULL`). |
| Owner | Product analytics |

---

## Retention

### Retention Cohorts

| Field | Value |
|---|---|
| Definition | Of users activated in cohort week W, the share returning to perform a session-generating action by period P (W1, W2, W3, W4, M2, M3, M6, M12). |
| Grain | One row per `(cohort_week_start_date, retention_period)`. |
| Source model | `models/marts/core/fct_retention_cohorts.sql` |
| Maturity guard | A cohort × period is only reported if the period is at least `retention_maturity_guard_days` (7) past the snapshot date. Otherwise `is_period_complete = false` and the rate is NULL. |
| Owner | Growth analytics |
| Test evidence | `tests/invariants/invariants_fct_retention_cohorts_rate_bounds.sql`, `tests/fanout/fanout_fct_retention_cohorts_period_count.sql`. |

The maturity guard exists because incomplete trailing periods otherwise render as artificial 0% retention — a chart cliff that does not reflect reality.

---

## Marketing

### Marketing Spend

| Field | Value |
|---|---|
| Definition | Spend, impressions, clicks, CPC, and CTR per channel × day. |
| Grain | One row per `(channel, spend_date)`. |
| Source model | `models/marts/marketing/fct_marketing_spend.sql` |
| Derived fields | `cost_per_click = spend_amount / nullif(clicks, 0)`, `click_through_rate = clicks / nullif(impressions, 0)`. |
| Owner | Marketing analytics |

### Attribution

| Field | Value |
|---|---|
| First-touch channel | First UTM-tagged channel observed for an anon_id/user_id, within the attribution window. |
| Last-touch channel | Most recent UTM-tagged channel before activation. |
| Window | `attribution_lookback_days` (30d) pre-activation. |
| Source model | `models/intermediate/cross_domain/int_attribution.sql`. Surfaced as FKs on `dim_users`. |
| Owner | Growth + marketing analytics |

---

## Support

### Tickets

| Field | Value |
|---|---|
| Definition | One row per support ticket. |
| Source model | `models/marts/support/fct_support_tickets.sql` |
| Resolution | A ticket is resolved iff `resolved_at IS NOT NULL`. |
| Test evidence | `tests/invariants/invariants_fct_support_tickets_resolved_has_time.sql`. |
| Owner | Support analytics |

### CSAT

| Field | Value |
|---|---|
| Definition | Customer satisfaction score, 1-5, captured per ticket via post-resolution survey. |
| Source field | `fct_support_tickets.csat` (NULL if no survey response). |
| Aggregation | Mean over responded tickets. Non-response handling: excluded from numerator and denominator. |
| Owner | Support analytics |

### Account Health Score

| Field | Value |
|---|---|
| Definition | Composite 0-100 score blending product usage, billing posture, and support signals over a trailing window. |
| Window | `account_health_trailing_days` (28d). |
| Source model | `models/intermediate/cross_domain/int_account_health.sql`. Surfaced as `dim_accounts.health_score`. |
| CSAT handling | Accounts with no support data contribute the neutral score (70), not a perfect 5. |
| Owner | Customer success analytics |

---

## Experiments

### Experiment Exposures

| Field | Value |
|---|---|
| Definition | A user was exposed to variant V of experiment E at time T. |
| Grain | Factless — one row per `(user_id, experiment_id, variant_id, exposure_time)`. |
| Source model | `models/marts/product/fct_experiment_exposures.sql` |
| Many-to-many bridge | `bridge_user_experiments` |
| Owner | Product analytics |

### Experiment Results

| Field | Value |
|---|---|
| Definition | Per-variant conversion rate against a declared activation event, scoped to users exposed before activation. |
| Source model | `models/intermediate/engagement/int_experiment_results.sql` |
| Owner | Product analytics |

---

## Changing a Metric

A metric in this contract is treated as a public API. Changing one requires:

1. A `decisions.md` entry describing what changed and why.
2. Updating this file with the new definition and a dated note.
3. The owner's sign-off.
4. A migration plan if downstream consumers (Lightdash, agents) need to be updated in lockstep.

Adding a metric requires the same: source model, grain, owner, test evidence. No metric ships without all four.
