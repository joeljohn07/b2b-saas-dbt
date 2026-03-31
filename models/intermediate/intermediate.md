## int_events_normalized

{% docs int_events_normalized %}
Canonical dedup on event_id. Keeps the earliest row by _loaded_at when
duplicates exist (~0.5% of source events). Single source of truth for all
downstream event consumption. Incremental merge on event_id with a 36-hour
lookback from the last processed _loaded_at, catching late arrivals without
a full-refresh.
{% enddocs %}

---

## int_identity_stitched

{% docs int_identity_stitched %}
Maps anonymous visitor IDs to authenticated user IDs using half-open time
intervals. 90-day stitch window, deterministic last-touch resolution.
{% enddocs %}

{% docs col_valid_from %}
Start of an effective-dated interval (inclusive). Used in identity stitching
and account membership periods.
{% enddocs %}

{% docs col_valid_to %}
End of an effective-dated interval (exclusive). Null means the interval is
current/open-ended. Used in identity stitching and account membership periods.
{% enddocs %}

{% docs col_stitch_source %}
How the identity stitch was determined (last_touch or historical).
{% enddocs %}

---

## int_account_memberships

{% docs int_account_memberships %}
User-account membership periods derived from member_joined and member_removed
events. Uses int_events_normalized (not staging) to avoid source duplicates.
{% enddocs %}

{% docs col_membership_duration_days %}
Duration of account membership in calendar days.
{% enddocs %}

---

## int_sessions

{% docs int_sessions %}
Sessionized events using 30-minute inactivity timeout. Sessions span
midnight. Session ID is a deterministic hash of anon_id and first event ID.
UTM parameters carried forward from the first event in each session.
{% enddocs %}

{% docs col_session_id %}
Deterministic hash of anon_id and first event ID within the session.
{% enddocs %}

{% docs col_stitched_user_id %}
Authenticated user ID resolved via identity stitching. Null for anonymous
sessions.
{% enddocs %}

{% docs col_session_start_at %}
Timestamp of the first event in the session.
{% enddocs %}

{% docs col_session_end_at %}
Timestamp of the last event in the session.
{% enddocs %}

{% docs col_session_duration_seconds %}
Duration of session in seconds (end minus start).
{% enddocs %}

{% docs col_event_count %}
Number of events in the session.
{% enddocs %}

{% docs col_page_view_count %}
Number of page_view events in the session.
{% enddocs %}

{% docs col_session_date %}
Date of the session start.
{% enddocs %}

---

## int_funnel_staged

{% docs int_funnel_staged %}
Highest funnel watermark per user across five stages: page_view, signup,
activation, feature_use, checkout_start. Depends on identity stitching to
attribute anonymous pre-signup page views to users.
{% enddocs %}

{% docs col_stage %}
Funnel stage name (page_view, signup, activation, feature_use,
checkout_start).
{% enddocs %}

{% docs col_stage_reached_at %}
Timestamp when this funnel stage was first reached.
{% enddocs %}

{% docs col_is_current_stage %}
Whether this is the user's highest funnel stage.
{% enddocs %}

---

## int_subscription_lifecycle

{% docs int_subscription_lifecycle %}
Account subscription state machine with ordered plan transitions. Derives
is_active status and days since previous event for each subscription event.
{% enddocs %}

{% docs col_is_active %}
Whether the subscription is currently active, derived from the event type.
{% enddocs %}

{% docs col_days_since_previous_event %}
Calendar days since the previous subscription lifecycle event for this
account.
{% enddocs %}

---

## int_mrr_movements

{% docs int_mrr_movements %}
MRR decomposition into movement categories: new, expansion, contraction,
churn, reactivation. SUM(mrr_delta) reconciles with net MRR change per
account.
{% enddocs %}

{% docs col_movement_date %}
Date of the MRR movement event.
{% enddocs %}

{% docs col_movement_type %}
Category of MRR change (new, expansion, contraction, churn, reactivation).
{% enddocs %}

{% docs col_mrr_before %}
MRR amount before this movement.
{% enddocs %}

{% docs col_mrr_after %}
MRR amount after this movement.
{% enddocs %}

{% docs col_mrr_delta %}
Change in MRR (mrr_after minus mrr_before).
{% enddocs %}

---

## int_engagement_states

{% docs int_engagement_states %}
Weekly user engagement classification into four states: pre_active, active,
dormant, disengaged. Tracks re-engagement transitions.
{% enddocs %}

{% docs col_snapshot_week_start %}
Monday start date of the snapshot week.
{% enddocs %}

{% docs col_engagement_state %}
Weekly engagement classification: pre_active (before activation), active
(activity within 14d), dormant (14-42d), disengaged (42d+).
{% enddocs %}

{% docs col_is_re_engaged %}
Whether the user transitioned from dormant or disengaged to active this
week.
{% enddocs %}

{% docs col_days_since_last_activity %}
Calendar days since the user's last activity as of snapshot week.
{% enddocs %}

{% docs col_last_activity_at %}
Timestamp of the user's most recent activity before snapshot week.
{% enddocs %}

---

## int_experiment_results

{% docs int_experiment_results %}
User-level experiment exposure and conversion data. Parses experiment_flags
JSON. Enforces 24-hour minimum exposure duration.
{% enddocs %}

{% docs col_variant %}
Experiment variant assigned to the user.
{% enddocs %}

{% docs col_first_exposure_at %}
Timestamp of the user's first exposure to the experiment.
{% enddocs %}

{% docs col_converted %}
Whether the checkout led to a subscription within 30 days, or whether a
user activated after experiment exposure.
{% enddocs %}

{% docs col_conversion_at %}
Timestamp of activation after experiment exposure. Null if not converted.
{% enddocs %}

{% docs col_exposure_duration_hours %}
Hours between first and last exposure event. Only rows with 24+ hours are
included (24h exclusion rule).
{% enddocs %}

---

## int_experiment_metadata

{% docs int_experiment_metadata %}
Passthrough of experiment seed definitions into the intermediate layer.
{% enddocs %}

---

## int_ticket_metrics

{% docs int_ticket_metrics %}
Per-ticket derived metrics: resolution time in hours, first response time
in hours, and is_resolved flag.
{% enddocs %}

{% docs col_resolution_time_hours %}
Hours between ticket creation and resolution.
{% enddocs %}

{% docs col_first_response_hours %}
Hours between ticket creation and first agent response.
{% enddocs %}

{% docs col_is_resolved %}
Whether the ticket has been resolved or closed.
{% enddocs %}

---

## int_invoices_prep

{% docs int_invoices_prep %}
Thin intermediate prep model for invoices. Adds is_paid flag and net_amount
calculation so marts can reference intermediate instead of staging.
{% enddocs %}

{% docs col_is_paid %}
Whether the invoice has been paid.
{% enddocs %}

{% docs col_net_amount %}
Invoice amount minus refund amount.
{% enddocs %}

---

## int_marketing_spend_prep

{% docs int_marketing_spend_prep %}
Thin intermediate prep model for marketing spend. Pass-through so marts can
reference intermediate instead of staging.
{% enddocs %}

---

## int_attribution

{% docs int_attribution %}
First-touch and last-touch channel attribution per user within a 30-day
window before activation. Reads activation events directly, not via funnel.
{% enddocs %}

{% docs col_first_touch_channel %}
Channel of the first touchpoint within 30 days of activation.
{% enddocs %}

{% docs col_first_touch_source %}
UTM source of the first touchpoint. Null for organic users.
{% enddocs %}

{% docs col_first_touch_medium %}
UTM medium of the first touchpoint. Null for organic users.
{% enddocs %}

{% docs col_first_touch_campaign %}
UTM campaign of the first touchpoint. Null for organic users.
{% enddocs %}

{% docs col_first_touch_at %}
Timestamp of the first touchpoint.
{% enddocs %}

{% docs col_last_touch_channel %}
Channel of the last touchpoint before activation.
{% enddocs %}

{% docs col_last_touch_source %}
UTM source of the last touchpoint. Null for organic users.
{% enddocs %}

{% docs col_last_touch_medium %}
UTM medium of the last touchpoint. Null for organic users.
{% enddocs %}

{% docs col_last_touch_campaign %}
UTM campaign of the last touchpoint. Null for organic users.
{% enddocs %}

{% docs col_last_touch_at %}
Timestamp of the last touchpoint before activation.
{% enddocs %}

{% docs col_activation_at %}
Timestamp of the user's first activation event.
{% enddocs %}

---

## int_checkout_conversion

{% docs int_checkout_conversion %}
Links checkout_start events to subscription_start events within a 30-day
conversion window. Accounts for the 14-day trial gap between checkout and
subscription.
{% enddocs %}

{% docs col_checkout_event_id %}
Event ID of the checkout_start event.
{% enddocs %}

{% docs col_subscription_at %}
Timestamp of the matched subscription_start. Null if not converted.
{% enddocs %}

{% docs col_time_to_conversion_days %}
Days between checkout and subscription. Null if not converted.
{% enddocs %}

{% docs col_checkout_at %}
Timestamp of the checkout_start event.
{% enddocs %}

---

## int_account_health

{% docs int_account_health %}
Composite weighted health score per account: activity (40%), billing (30%),
support (30%). Trailing 28-day window. Score bounded [0, 100].
{% enddocs %}

{% docs col_health_score %}
Composite weighted health score bounded [0, 100]. Activity 40%, billing
30%, support 30%.
{% enddocs %}

{% docs col_activity_score %}
Activity component of health score (40% weight). Based on session count
in trailing window.
{% enddocs %}

{% docs col_billing_score %}
Billing component of health score (30% weight). Based on subscription
status and recency.
{% enddocs %}

{% docs col_support_score %}
Support component of health score (30% weight). Based on ticket volume
and CSAT scores.
{% enddocs %}

{% docs col_calculated_at %}
Timestamp when the health score was calculated.
{% enddocs %}

{% docs col_trailing_window_days %}
Number of trailing days used for the score calculation.
{% enddocs %}
