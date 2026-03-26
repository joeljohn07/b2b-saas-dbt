# Shared Column Doc Blocks

Canonical doc blocks for columns reused across 2+ models. Per
`docs/doc-block-convention.md`, naming follows `col_{column}` for shared
columns and `col_{domain}_{column}` for domain-qualified columns.

---

## Seed descriptions

{% docs seed_experiment_metadata %}
Experiment definitions for the experiment dimension.
{% enddocs %}

---

## Identifiers

{% docs col_event_id %}
Event identifier. Not unique in staging due to ~0.5% known duplicate events
in the source system. Uniqueness is enforced after dedup in
int_events_normalized.
{% enddocs %}

{% docs col_user_id %}
Authenticated user identifier. Null for anonymous events that occur before
signup or login.
{% enddocs %}

{% docs col_anon_id %}
Anonymous visitor identifier. Assigned on first visit and persists across
sessions until the user authenticates.
{% enddocs %}

{% docs col_account_id %}
Account identifier. Groups users into a shared workspace or billing entity.
Null for pre-signup events.
{% enddocs %}

{% docs col_subscription_event_id %}
Unique identifier for a subscription lifecycle event.
{% enddocs %}

{% docs col_subscription_id %}
Subscription identifier. Groups all lifecycle events for the same
subscription.
{% enddocs %}

{% docs col_invoice_id %}
Unique invoice identifier.
{% enddocs %}

{% docs col_spend_id %}
Unique marketing spend record identifier.
{% enddocs %}

{% docs col_ticket_id %}
Unique support ticket identifier.
{% enddocs %}

{% docs col_campaign_id %}
Marketing campaign identifier.
{% enddocs %}

---

## Timestamps

{% docs col_event_time %}
Timestamp when the event occurred.
{% enddocs %}

{% docs col_ingest_time %}
Timestamp when the event was ingested by the pipeline.
{% enddocs %}

{% docs col__loaded_at %}
Timestamp when the row was loaded into the warehouse.
{% enddocs %}

{% docs col_issued_at %}
Timestamp when the invoice was issued.
{% enddocs %}

{% docs col_paid_at %}
Timestamp when the invoice was paid. Null if unpaid.
{% enddocs %}

{% docs col_created_at %}
Timestamp when the ticket was created.
{% enddocs %}

{% docs col_resolved_at %}
Timestamp when the ticket was resolved. Null if still open.
{% enddocs %}

---

## Dates

{% docs col_event_date %}
Date of the event. Populated by the source system from event_time.
{% enddocs %}

{% docs col_spend_date %}
Date of the marketing spend. Renamed from source 'date' column.
{% enddocs %}

---

## Classification

{% docs col_event_type %}
Type of event. Categorizes the user action or system event that was recorded.
{% enddocs %}

{% docs col_subscription_event_type %}
Type of subscription event (trial_start, trial_end, subscription_start,
upgrade, downgrade, renewal, cancellation, reactivation).
{% enddocs %}

{% docs col_platform %}
Platform where the event occurred (web, ios, android).
{% enddocs %}

{% docs col_channel %}
Acquisition or marketing channel (organic, paid_search, paid_social,
referral, email, direct).
{% enddocs %}

{% docs col_plan_context %}
The user's current plan at the time the event was recorded.
{% enddocs %}

{% docs col_plan %}
Subscription plan at the time of the event (free, starter, pro, enterprise).
{% enddocs %}

{% docs col_previous_plan %}
Previous subscription plan before this event. Null for the first subscription
event on an account.
{% enddocs %}

{% docs col_category %}
Support ticket category (bug, feature_request, billing, onboarding, other).
{% enddocs %}

{% docs col_priority %}
Support ticket priority level (low, medium, high, critical).
{% enddocs %}

{% docs col_ticket_status %}
Support ticket status (open, in_progress, resolved, closed).
{% enddocs %}

{% docs col_invoice_status %}
Invoice payment status (paid, pending, failed, refunded).
{% enddocs %}

---

## UTM

{% docs col_utm_source %}
UTM source parameter from the referring URL. Null when not present.
{% enddocs %}

{% docs col_utm_medium %}
UTM medium parameter from the referring URL. Null when not present.
{% enddocs %}

{% docs col_utm_campaign %}
UTM campaign parameter from the referring URL. Null when not present.
{% enddocs %}

{% docs col_utm_term %}
UTM term parameter from the referring URL. Null when not present.
{% enddocs %}

{% docs col_utm_content %}
UTM content parameter from the referring URL. Null when not present.
{% enddocs %}

---

## Device

{% docs col_device_type %}
Device type used for the event (desktop, mobile, tablet).
{% enddocs %}

{% docs col_browser %}
Browser name used for the event.
{% enddocs %}

{% docs col_os %}
Operating system of the device used for the event.
{% enddocs %}

{% docs col_user_agent %}
Raw user agent string from the HTTP request.
{% enddocs %}

---

## Financial

{% docs col_mrr_amount %}
Monthly recurring revenue amount in the subscription currency.
{% enddocs %}

{% docs col_billing_cycle %}
Billing cycle (monthly, annual).
{% enddocs %}

{% docs col_currency %}
ISO 4217 currency code (e.g., USD, EUR).
{% enddocs %}

{% docs col_amount %}
Invoice total amount in the invoice currency.
{% enddocs %}

{% docs col_refund_amount %}
Refund amount applied to the invoice. Zero if no refund.
{% enddocs %}

{% docs col_spend_amount %}
Amount spent on the campaign for the given date.
{% enddocs %}

{% docs col_cancel_reason %}
Reason for cancellation. Null for non-cancellation events.
{% enddocs %}

{% docs col_is_voluntary %}
Whether the cancellation was initiated by the customer (true) or by the
system (false). Null for non-cancellation events.
{% enddocs %}

---

## Metrics

{% docs col_impressions %}
Number of ad impressions served.
{% enddocs %}

{% docs col_clicks %}
Number of ad clicks received.
{% enddocs %}

{% docs col_csat_score %}
Customer satisfaction score (1-5). Null if the customer has not yet rated
the interaction.
{% enddocs %}

{% docs col_first_response_seconds %}
Time to first agent response in seconds. Null if no response has been sent.
{% enddocs %}

---

## Event-specific columns

{% docs col_page_url %}
Page URL visited. Populated for page_view events only.
{% enddocs %}

{% docs col_referrer %}
Referrer URL for the page view. Populated for page_view events only.
{% enddocs %}

{% docs col_signup_method %}
Method used to sign up (e.g., email, google, github). Populated for signup
events only.
{% enddocs %}

{% docs col_activation_action %}
The specific action that qualified as activation. Populated for activation
events only.
{% enddocs %}

{% docs col_time_to_activate_hours %}
Hours elapsed from signup to activation. Populated for activation events only.
{% enddocs %}

{% docs col_feature_name %}
Name of the feature used. Populated for feature_use events only.
{% enddocs %}

{% docs col_feature_duration_seconds %}
Duration of feature use in seconds. Populated for feature_use events only.
{% enddocs %}

{% docs col_source_page %}
Page that triggered a paywall view. Populated for paywall_view events only.
{% enddocs %}

{% docs col_target_plan %}
Target plan for a checkout or upgrade action. Populated for checkout_start
and upgrade_click events.
{% enddocs %}

{% docs col_member_role %}
Role assigned to a team member. Populated for member_joined events only.
{% enddocs %}

{% docs col_member_reason %}
Reason for removing a team member. Populated for member_removed events only.
{% enddocs %}

{% docs col_experiment_flags %}
JSON-serialized array of experiment assignments. Each element contains
experiment_id and variant. Unnested downstream in int_experiment_results.
{% enddocs %}

{% docs col_campaign_name %}
Human-readable marketing campaign name.
{% enddocs %}

{% docs col_line_items %}
Raw JSON string of invoice line items. Kept as-is for downstream processing.
{% enddocs %}

---

## Interval columns

{% docs col_valid_from %}
Start of an effective-dated interval (inclusive). Used in identity stitching
and account membership periods.
{% enddocs %}

{% docs col_valid_to %}
End of an effective-dated interval (exclusive). Null means the interval is
current/open-ended. Used in identity stitching and account membership periods.
{% enddocs %}

---

## Intermediate-derived columns

{% docs col_is_active %}
Whether the subscription is currently active, derived from the event type.
{% enddocs %}

{% docs col_days_since_previous_event %}
Calendar days since the previous subscription lifecycle event for this
account.
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

{% docs col_is_paid %}
Whether the invoice has been paid.
{% enddocs %}

{% docs col_net_amount %}
Invoice amount minus refund amount.
{% enddocs %}

---

## MRR movement columns

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

## Attribution columns

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

## Checkout conversion columns

{% docs col_checkout_event_id %}
Event ID of the checkout_start event.
{% enddocs %}

{% docs col_checkout_at %}
Timestamp of the checkout_start event.
{% enddocs %}

{% docs col_subscription_at %}
Timestamp of the matched subscription_start. Null if not converted.
{% enddocs %}

{% docs col_converted %}
Whether the checkout led to a subscription within 30 days, or whether a
user activated after experiment exposure.
{% enddocs %}

{% docs col_time_to_conversion_days %}
Days between checkout and subscription. Null if not converted.
{% enddocs %}

---

## Account health columns

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

---

## Engagement columns

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

## Experiment columns

{% docs col_experiment_id %}
Experiment identifier from experiment_flags JSON.
{% enddocs %}

{% docs col_variant %}
Experiment variant assigned to the user.
{% enddocs %}

{% docs col_first_exposure_at %}
Timestamp of the user's first exposure to the experiment.
{% enddocs %}

{% docs col_conversion_at %}
Timestamp of activation after experiment exposure. Null if not converted.
{% enddocs %}

{% docs col_exposure_duration_hours %}
Hours between first and last exposure event. Only rows with 24+ hours are
included (24h exclusion rule).
{% enddocs %}

---

## Identity columns

{% docs col_stitch_source %}
How the identity stitch was determined (last_touch or historical).
{% enddocs %}

## Session columns

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

## Funnel columns

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

## Membership columns

{% docs col_membership_duration_days %}
Duration of account membership in calendar days.
{% enddocs %}

---

## Surrogate key columns

{% docs col_date_key %}
Surrogate key for the date dimension. Integer in YYYYMMDD format.
{% enddocs %}

{% docs col_channel_key %}
Surrogate key for the channel dimension. farm_fingerprint hash of the
channel string.
{% enddocs %}

{% docs col_session_key %}
Surrogate key for the session dimension. farm_fingerprint hash of the
session ID.
{% enddocs %}

{% docs col_experiment_key %}
Surrogate key for the experiment dimension. farm_fingerprint hash of
the experiment ID.
{% enddocs %}

{% docs col_user_key %}
Surrogate key for the user dimension. farm_fingerprint hash of the
user ID.
{% enddocs %}

{% docs col_account_key %}
Surrogate key for the account dimension. farm_fingerprint hash of the
account ID.
{% enddocs %}

{% docs col_signup_key %}
Surrogate key for the signup fact. farm_fingerprint hash of the event ID.
{% enddocs %}

{% docs col_activation_key %}
Surrogate key for the activation fact. farm_fingerprint hash of the user ID.
{% enddocs %}

{% docs col_feature_usage_key %}
Surrogate key for the feature usage fact. farm_fingerprint hash of the
event ID.
{% enddocs %}

{% docs col_spend_key %}
Surrogate key for the marketing spend fact. farm_fingerprint hash of the
spend ID.
{% enddocs %}

{% docs col_ticket_key %}
Surrogate key for the support ticket fact. farm_fingerprint hash of the
ticket ID.
{% enddocs %}

{% docs col_subscription_event_key %}
Surrogate key for the subscription event fact. farm_fingerprint hash of the
subscription event ID.
{% enddocs %}

{% docs col_mrr_movement_key %}
Surrogate key for the MRR movement fact. farm_fingerprint hash of the
concatenation of account ID and subscription event ID.
{% enddocs %}

{% docs col_invoice_key %}
Surrogate key for the invoice fact. farm_fingerprint hash of the invoice ID.
{% enddocs %}

{% docs col_retention_cohort_key %}
Surrogate key for the retention cohort fact. farm_fingerprint hash of the
concatenation of cohort week start date and retention period.
{% enddocs %}

---

## Date dimension columns

{% docs col_date_day %}
Calendar date.
{% enddocs %}

{% docs col_day_of_week %}
ISO day of week (1=Monday through 7=Sunday).
{% enddocs %}

{% docs col_day_name %}
Name of the day of week (Monday through Sunday).
{% enddocs %}

{% docs col_day_of_month %}
Day of the month (1-31).
{% enddocs %}

{% docs col_day_of_year %}
Day of the year (1-366).
{% enddocs %}

{% docs col_week_start_date %}
Monday start date of the ISO week containing this date.
{% enddocs %}

{% docs col_month_start_date %}
First day of the month containing this date.
{% enddocs %}

{% docs col_month_name %}
Name of the month (January through December).
{% enddocs %}

{% docs col_month_number %}
Month number (1-12).
{% enddocs %}

{% docs col_quarter_number %}
Quarter number (1-4).
{% enddocs %}

{% docs col_quarter_start_date %}
First day of the quarter containing this date.
{% enddocs %}

{% docs col_year_number %}
Calendar year.
{% enddocs %}

{% docs col_is_weekend %}
Whether the date falls on Saturday or Sunday.
{% enddocs %}

---

## Role-playing foreign key columns

{% docs col_session_date_key %}
Foreign key to dim_date for the session start date.
{% enddocs %}

{% docs col_first_touch_channel_key %}
Foreign key to dim_channels for the first attribution touchpoint channel.
{% enddocs %}

{% docs col_last_touch_channel_key %}
Foreign key to dim_channels for the last attribution touchpoint channel.
{% enddocs %}

{% docs col_acquisition_channel_key %}
Foreign key to dim_channels for the account acquisition channel, derived
from the first activated user's first-touch channel.
{% enddocs %}

{% docs col_signup_date_key %}
Foreign key to dim_date for the signup event date.
{% enddocs %}

{% docs col_activation_date_key %}
Foreign key to dim_date for the activation event date.
{% enddocs %}

{% docs col_usage_date_key %}
Foreign key to dim_date for the feature usage event date.
{% enddocs %}

{% docs col_created_date_key %}
Foreign key to dim_date for the ticket creation date.
{% enddocs %}

{% docs col_event_date_key %}
Foreign key to dim_date for the subscription event date.
{% enddocs %}

{% docs col_movement_date_key %}
Foreign key to dim_date for the MRR movement date.
{% enddocs %}

{% docs col_issued_date_key %}
Foreign key to dim_date for the invoice issue date.
{% enddocs %}

{% docs col_spend_date_key %}
Foreign key to dim_date for the marketing spend date.
{% enddocs %}

{% docs col_exposure_date_key %}
Foreign key to dim_date for the experiment first-exposure date.
{% enddocs %}

{% docs col_cohort_week_date_key %}
Foreign key to dim_date for the cohort week start date (always a Monday).
{% enddocs %}

{% docs col_period_end_date_key %}
Foreign key to dim_date for the retention period end date.
{% enddocs %}

---

## Marts dimension columns

{% docs col_experiment_name %}
Human-readable experiment name.
{% enddocs %}

{% docs col_experiment_status %}
Current experiment status (active, completed, paused).
{% enddocs %}

{% docs col_experiment_description %}
Description of the experiment's purpose and hypothesis.
{% enddocs %}

{% docs col_experiment_start_date %}
Date when the experiment started.
{% enddocs %}

{% docs col_experiment_end_date %}
Date when the experiment ended. Null if still active.
{% enddocs %}

{% docs col_signup_at %}
Timestamp of the user's first signup event.
{% enddocs %}

{% docs col_acquisition_date %}
Date when the account was acquired, based on the first activated user's
activation timestamp.
{% enddocs %}

{% docs col_lifecycle_stage %}
Account lifecycle stage derived from the latest subscription event
(trial, active, churned, reactivated).
{% enddocs %}

{% docs col_user_count %}
Number of currently active members in the account.
{% enddocs %}

{% docs col_usage_at %}
Timestamp when the feature usage event occurred.
{% enddocs %}

---

## Retention columns

{% docs col_cohort_week_start_date %}
Monday of the ISO week in which users activated. Defines the retention
cohort boundary.
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
