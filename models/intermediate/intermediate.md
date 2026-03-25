## Product domain

{% docs int_events_normalized %}
Canonical dedup on event_id. Keeps the earliest row by _loaded_at when
duplicates exist (~0.5% of source events). Single source of truth for all
downstream event consumption.
{% enddocs %}

{% docs int_identity_stitched %}
Maps anonymous visitor IDs to authenticated user IDs using half-open time
intervals. 90-day stitch window, deterministic last-touch resolution.
{% enddocs %}

{% docs int_sessions %}
Sessionized events using 30-minute inactivity timeout. Sessions span
midnight. Session ID is a deterministic hash of anon_id and first event ID.
UTM parameters carried forward from the first event in each session.
{% enddocs %}

{% docs int_funnel_staged %}
Highest funnel watermark per user across five stages: page_view, signup,
activation, feature_use, checkout_start. Depends on identity stitching to
attribute anonymous pre-signup page views to users.
{% enddocs %}

{% docs int_account_memberships %}
User-account membership periods derived from member_joined and member_removed
events. Uses int_events_normalized (not staging) to avoid source duplicates.
{% enddocs %}

---

## Billing domain

{% docs int_subscription_lifecycle %}
Account subscription state machine with ordered plan transitions. Derives
is_active status and days since previous event for each subscription event.
{% enddocs %}

{% docs int_mrr_movements %}
MRR decomposition into movement categories: new, expansion, contraction,
churn, reactivation. SUM(mrr_delta) reconciles with net MRR change per
account.
{% enddocs %}

---

## Engagement domain

{% docs int_engagement_states %}
Weekly user engagement classification into four states: pre_active, active,
dormant, disengaged. Tracks re-engagement transitions.
{% enddocs %}

{% docs int_experiment_results %}
User-level experiment exposure and conversion data. Parses experiment_flags
JSON. Enforces 24-hour minimum exposure duration.
{% enddocs %}

{% docs int_experiment_metadata %}
Passthrough of experiment seed definitions into the intermediate layer.
{% enddocs %}

---

## Cross-domain

{% docs int_attribution %}
First-touch and last-touch channel attribution per user within a 30-day
window before activation. Reads activation events directly, not via funnel.
{% enddocs %}

{% docs int_ticket_metrics %}
Per-ticket derived metrics: resolution time in hours, first response time
in hours, and is_resolved flag.
{% enddocs %}

{% docs int_invoices_prep %}
Thin intermediate prep model for invoices. Adds is_paid flag and net_amount
calculation so marts can reference intermediate instead of staging.
{% enddocs %}

{% docs int_marketing_spend_prep %}
Thin intermediate prep model for marketing spend. Pass-through so marts can
reference intermediate instead of staging.
{% enddocs %}

{% docs int_checkout_conversion %}
Links checkout_start events to subscription_start events within a 30-day
conversion window. Accounts for the 14-day trial gap between checkout and
subscription.
{% enddocs %}

{% docs int_account_health %}
Composite weighted health score per account: activity (40%), billing (30%),
support (30%). Trailing 28-day window. Score bounded [0, 100].
{% enddocs %}
