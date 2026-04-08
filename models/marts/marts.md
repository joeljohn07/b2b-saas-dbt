## dim_channels

{% docs dim_channels %}
Conformed channel dimension derived from attribution and marketing spend data.
Grain: one row per unique channel. Serves as FK target for first-touch,
last-touch, and acquisition channel role-playing keys.
{% enddocs %}

{% docs col_channel_key %}
Surrogate key for the channel dimension. farm_fingerprint hash of the
channel string.
{% enddocs %}

---

## dim_users

{% docs dim_users %}
User dimension joining attribution, engagement, account membership, and signup
data. Grain: one row per user (SCD Type 1 — current state). The most complex
dimension in the star schema.
{% enddocs %}

{% docs col_user_key %}
Surrogate key for the user dimension. farm_fingerprint hash of the
user ID.
{% enddocs %}

{% docs col_signup_at %}
Timestamp of the user's first signup event.
{% enddocs %}

{% docs col_first_touch_channel_key %}
Foreign key to dim_channels for the first attribution touchpoint channel.
{% enddocs %}

{% docs col_last_touch_channel_key %}
Foreign key to dim_channels for the last attribution touchpoint channel.
{% enddocs %}

---

## dim_accounts

{% docs dim_accounts %}
Account dimension joining subscription lifecycle, health scores, member counts,
and acquisition attribution. Grain: one row per account (SCD Type 1 — current
state).
{% enddocs %}

{% docs col_account_key %}
Surrogate key for the account dimension. farm_fingerprint hash of the
account ID.
{% enddocs %}

{% docs col_user_count %}
Number of currently active members in the account.
{% enddocs %}

{% docs col_acquisition_channel_key %}
Foreign key to dim_channels for the account acquisition channel, derived
from the first activated user's first-touch channel.
{% enddocs %}

{% docs col_acquisition_date %}
Date when the account was acquired, based on the first activated user's
activation timestamp.
{% enddocs %}

{% docs col_lifecycle_stage %}
Account lifecycle stage derived from the latest subscription event
(trial, active, churned, reactivated).
{% enddocs %}

---

## fct_signups

{% docs fct_signups %}
Signup event fact sourced from normalized product events. Grain: one row per
signup event. Includes channel, UTM, and device attributes as degenerate
dimensions.
{% enddocs %}

{% docs col_signup_key %}
Surrogate key for the signup fact. farm_fingerprint hash of the event ID.
{% enddocs %}

{% docs col_signup_date_key %}
Foreign key to dim_date for the signup event date.
{% enddocs %}

---

## fct_activations

{% docs fct_activations %}
Activation event fact sourced from attribution data. Grain: one row per user
activation. Only activated users appear (filtered upstream in int_attribution).
{% enddocs %}

{% docs col_activation_key %}
Surrogate key for the activation fact. farm_fingerprint hash of the user ID.
{% enddocs %}

{% docs col_activation_date_key %}
Foreign key to dim_date for the activation event date.
{% enddocs %}

---

## fct_retention_cohorts

{% docs fct_retention_cohorts %}
Pre-computed retention cohort fact sourced from attribution and normalized
event data. Grain: one row per activation-week cohort x retention period.
Eight retention periods (W1-W4, M2, M3, M6, M12) measured as 7-day activity
windows at fixed day offsets from the cohort week start date (always a
Monday). Only activated users are included in cohorts.
{% enddocs %}

{% docs col_retention_cohort_key %}
Surrogate key for the retention cohort fact. farm_fingerprint hash of the
concatenation of cohort week start date and retention period.
{% enddocs %}

{% docs col_cohort_week_start_date %}
Monday of the ISO week in which users activated. Defines the retention
cohort boundary.
{% enddocs %}

{% docs col_cohort_week_date_key %}
Foreign key to dim_date for the cohort week start date (always a Monday).
{% enddocs %}

{% docs col_retention_period %}
Retention measurement period label. Eight fixed periods: W1 through W4
(weekly), M2, M3, M6, M12 (monthly milestones measured as 7-day windows).
{% enddocs %}

{% docs col_period_offset_days %}
Number of days from the cohort week start date to the beginning of the
7-day retention measurement window.
{% enddocs %}

{% docs col_period_end_date %}
Last date of the 7-day retention measurement window. Equals
cohort_week_start_date plus period_offset_days plus 6.
{% enddocs %}

{% docs col_period_end_date_key %}
Foreign key to dim_date for the retention period end date.
{% enddocs %}

{% docs col_cohort_size %}
Number of users who activated during the cohort week.
{% enddocs %}

{% docs col_retained_count %}
Number of cohort users who had at least one event during the retention
measurement window. Always less than or equal to cohort_size.
{% enddocs %}

{% docs col_retention_rate %}
Fraction of cohort users retained in the measurement window. Equals
retained_count divided by cohort_size, bounded between 0 and 1.
{% enddocs %}

{% docs col_is_period_complete %}
Whether the retention measurement window has fully elapsed plus a 7-day
buffer for late-arriving events. False for recent periods where data may
still be incomplete.
{% enddocs %}

---

## dim_sessions

{% docs dim_sessions %}
Session dimension built from sessionized product events. Grain: one row per
session. Includes device, UTM, and session duration attributes.
{% enddocs %}

{% docs col_session_key %}
Surrogate key for the session dimension. farm_fingerprint hash of the
session ID.
{% enddocs %}

{% docs col_session_date_key %}
Foreign key to dim_date for the session start date.
{% enddocs %}

---

## dim_experiments

{% docs dim_experiments %}
Experiment dimension sourced from the experiment_metadata seed. Grain: one row
per experiment. Contains experiment definitions and status.
{% enddocs %}

{% docs col_experiment_key %}
Surrogate key for the experiment dimension. farm_fingerprint hash of
the experiment ID.
{% enddocs %}

---

## bridge_user_experiments

{% docs bridge_user_experiments %}
Bridge table resolving the many-to-many relationship between users and
experiments. Grain: one row per user-experiment combination. Includes variant
assignment and first exposure timestamp.
{% enddocs %}

---

## fct_feature_usage

{% docs fct_feature_usage %}
Feature usage event fact sourced from normalized product events. Grain: one row
per feature_use event. Tracks feature name, duration, and device context.
{% enddocs %}

{% docs col_feature_usage_key %}
Surrogate key for the feature usage fact. farm_fingerprint hash of the
event ID.
{% enddocs %}

{% docs col_usage_date_key %}
Foreign key to dim_date for the feature usage event date.
{% enddocs %}

{% docs col_usage_at %}
Timestamp when the feature usage event occurred.
{% enddocs %}

---

## fct_sessions

{% docs fct_sessions %}
Session fact sourced from sessionized product events. Grain: one row per
session. Carries session duration, event counts, and page view counts as
measures. Device and UTM attributes included as degenerate dimensions.
{% enddocs %}

---

## fct_experiment_exposures

{% docs fct_experiment_exposures %}
Experiment exposure factless fact sourced from experiment results. Grain: one
row per user x experiment. Extends bridge_user_experiments with conversion
metrics (converted, conversion_at) and exposure duration. Composite PK
(user_key + experiment_key).
{% enddocs %}

{% docs col_exposure_date_key %}
Foreign key to dim_date for the experiment first-exposure date.
{% enddocs %}

---

## fct_subscriptions

{% docs fct_subscriptions %}
Subscription lifecycle event fact sourced from subscription lifecycle. Grain:
one row per subscription event. Tracks plan changes, MRR, billing cycle, and
cancellation details.
{% enddocs %}

{% docs col_subscription_event_key %}
Surrogate key for the subscription event fact. farm_fingerprint hash of the
subscription event ID.
{% enddocs %}

{% docs col_event_date_key %}
Foreign key to dim_date for the subscription event date.
{% enddocs %}

---

## fct_mrr_movements

{% docs fct_mrr_movements %}
MRR movement fact sourced from MRR movements intermediate. Grain: one row per
MRR movement event per account. Tracks movement type, MRR before/after, and
delta for cohort-based MRR analysis.
{% enddocs %}

{% docs col_mrr_movement_key %}
Surrogate key for the MRR movement fact. farm_fingerprint hash of the
concatenation of account ID and subscription event ID.
{% enddocs %}

{% docs col_movement_date_key %}
Foreign key to dim_date for the MRR movement date.
{% enddocs %}

---

## fct_invoices

{% docs fct_invoices %}
Invoice fact sourced from invoices prep. Grain: one row per invoice. Tracks
amounts, payment status, refunds, and net revenue.
{% enddocs %}

{% docs col_invoice_key %}
Surrogate key for the invoice fact. farm_fingerprint hash of the invoice ID.
{% enddocs %}

{% docs col_issued_date_key %}
Foreign key to dim_date for the invoice issue date.
{% enddocs %}

---

## fct_marketing_spend

{% docs fct_marketing_spend %}
Marketing spend fact sourced from marketing spend prep. Grain: one row per
spend record (channel x campaign x date). Tracks spend amount, impressions,
and clicks.
{% enddocs %}

{% docs col_spend_key %}
Surrogate key for the marketing spend fact. farm_fingerprint hash of the
spend ID.
{% enddocs %}

{% docs col_spend_date_key %}
Foreign key to dim_date for the marketing spend date.
{% enddocs %}

---

## fct_support_tickets

{% docs fct_support_tickets %}
Support ticket fact sourced from ticket metrics. Grain: one row per ticket.
Carries resolution time, first response time, CSAT score, and resolution
status.
{% enddocs %}

{% docs col_is_product_user %}
Whether this user has at least one event in the product event stream
(int_events_normalized). False for billing-only or support-only users.
{% enddocs %}

{% docs col_is_billing_user %}
Whether this user appears in the subscription lifecycle data
(int_subscription_lifecycle). False for users known only from product
events or support tickets.
{% enddocs %}

{% docs col_is_support_user %}
Whether this user has at least one support ticket in the ticket metrics
(int_ticket_metrics). False for users known only from product events or
billing data.
{% enddocs %}

{% docs col_ticket_key %}
Surrogate key for the support ticket fact. farm_fingerprint hash of the
ticket ID.
{% enddocs %}

{% docs col_created_date_key %}
Foreign key to dim_date for the ticket creation date.
{% enddocs %}
