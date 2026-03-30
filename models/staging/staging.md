## Source descriptions

{% docs src_billing %}
Billing system data — subscriptions and invoices.
{% enddocs %}

{% docs src_billing_subscriptions %}
Subscription lifecycle events: trial starts/ends, subscription starts,
upgrades, downgrades, renewals, cancellations, and reactivations.
{% enddocs %}

{% docs src_billing_invoices %}
Invoices generated from subscriptions. Includes payment status,
amounts, and line item details.
{% enddocs %}

{% docs src_support %}
Customer support ticket data.
{% enddocs %}

{% docs src_support_tickets %}
Support tickets with category, priority, resolution status,
CSAT scores, and response times.
{% enddocs %}

{% docs src_funnel %}
Product analytics event stream.
{% enddocs %}

{% docs src_funnel_events %}
Raw product events covering the full user lifecycle: page views,
signups, activations, feature usage, paywall views, checkout starts,
upgrade clicks, and team member management.
{% enddocs %}

{% docs src_marketing %}
Marketing spend data by channel and campaign.
{% enddocs %}

{% docs src_marketing_spend %}
Daily marketing spend by channel and campaign, including impressions
and clicks.
{% enddocs %}

---

## dim_date

{% docs dim_date %}
Calendar date dimension seeded from a static CSV. Covers 2024-01-01 through
2029-12-31. Grain: one row per calendar date. Used as the conformed date
dimension for all date-keyed facts. Regenerate the seed CSV before the end
date to prevent FK test failures on newer data.
{% enddocs %}

{% docs col_date_key %}
Surrogate key for the date dimension. Integer in YYYYMMDD format.
{% enddocs %}

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

## experiment_metadata

{% docs seed_experiment_metadata %}
Experiment definitions for the experiment dimension.
{% enddocs %}

{% docs col_experiment_id %}
Experiment identifier from experiment_flags JSON.
{% enddocs %}

{% docs col_experiment_name %}
Human-readable experiment name.
{% enddocs %}

{% docs col_experiment_status %}
Current experiment status (active, completed, paused).
{% enddocs %}

{% docs col_experiment_start_date %}
Date when the experiment started.
{% enddocs %}

{% docs col_experiment_end_date %}
Date when the experiment ended. Null if still active.
{% enddocs %}

{% docs col_experiment_description %}
Description of the experiment's purpose and hypothesis.
{% enddocs %}

---

## stg_funnel__events

{% docs stg_funnel__events %}
Staged product events. Shreds the properties JSON column into flat typed
columns. Passes experiment_flags as-is for downstream unnesting in
int_experiment_results.
{% enddocs %}

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

{% docs col_event_time %}
Timestamp when the event occurred.
{% enddocs %}

{% docs col_ingest_time %}
Timestamp when the event was ingested by the pipeline.
{% enddocs %}

{% docs col__loaded_at %}
Timestamp when the row was loaded into the warehouse.
{% enddocs %}

{% docs col_event_date %}
Date of the event. Populated by the source system from event_time.
{% enddocs %}

{% docs col_event_type %}
Type of event. Categorizes the user action or system event that was recorded.
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

{% docs col_billing_cycle %}
Billing cycle (monthly, annual).
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

---

## stg_billing__subscriptions

{% docs stg_billing__subscriptions %}
Staged subscription lifecycle events. Pass-through from source with canonical
naming. Covers trial starts/ends, subscription starts, upgrades, downgrades,
renewals, cancellations, and reactivations.
{% enddocs %}

{% docs col_subscription_event_id %}
Unique identifier for a subscription lifecycle event.
{% enddocs %}

{% docs col_subscription_id %}
Subscription identifier. Groups all lifecycle events for the same
subscription.
{% enddocs %}

{% docs col_subscription_event_type %}
Type of subscription event (trial_start, trial_end, subscription_start,
upgrade, downgrade, renewal, cancellation, reactivation).
{% enddocs %}

{% docs col_plan %}
Subscription plan at the time of the event (free, starter, pro, enterprise).
{% enddocs %}

{% docs col_previous_plan %}
Previous subscription plan before this event. Null for the first subscription
event on an account.
{% enddocs %}

{% docs col_mrr_amount %}
Monthly recurring revenue amount in the subscription currency.
{% enddocs %}

{% docs col_currency %}
ISO 4217 currency code (e.g., USD, EUR).
{% enddocs %}

{% docs col_cancel_reason %}
Reason for cancellation. Null for non-cancellation events.
{% enddocs %}

{% docs col_is_voluntary %}
Whether the cancellation was initiated by the customer (true) or by the
system (false). Null for non-cancellation events.
{% enddocs %}

---

## stg_billing__invoices

{% docs stg_billing__invoices %}
Staged invoices. Pass-through with line_items kept as raw JSON string — not
shredded at any layer.
{% enddocs %}

{% docs col_invoice_id %}
Unique invoice identifier.
{% enddocs %}

{% docs col_issued_at %}
Timestamp when the invoice was issued.
{% enddocs %}

{% docs col_paid_at %}
Timestamp when the invoice was paid. Null if unpaid.
{% enddocs %}

{% docs col_amount %}
Invoice total amount in the invoice currency.
{% enddocs %}

{% docs col_invoice_status %}
Invoice payment status (paid, pending, failed, refunded).
{% enddocs %}

{% docs col_refund_amount %}
Refund amount applied to the invoice. Zero if no refund.
{% enddocs %}

{% docs col_line_items %}
Raw JSON string of invoice line items. Kept as-is for downstream processing.
{% enddocs %}

---

## stg_marketing__spend

{% docs stg_marketing__spend %}
Staged marketing spend records. Renames source 'date' column to 'spend_date'
to avoid reserved word conflicts.
{% enddocs %}

{% docs col_spend_id %}
Unique marketing spend record identifier.
{% enddocs %}

{% docs col_spend_date %}
Date of the marketing spend. Renamed from source 'date' column.
{% enddocs %}

{% docs col_campaign_id %}
Marketing campaign identifier.
{% enddocs %}

{% docs col_campaign_name %}
Human-readable marketing campaign name.
{% enddocs %}

{% docs col_impressions %}
Number of ad impressions served.
{% enddocs %}

{% docs col_clicks %}
Number of ad clicks received.
{% enddocs %}

{% docs col_spend_amount %}
Amount spent on the campaign for the given date.
{% enddocs %}

---

## stg_support__tickets

{% docs stg_support__tickets %}
Staged support tickets. Clean pass-through with canonical naming. Includes
category, priority, resolution status, CSAT scores, and response times.
{% enddocs %}

{% docs col_ticket_id %}
Unique support ticket identifier.
{% enddocs %}

{% docs col_created_at %}
Timestamp when the ticket was created.
{% enddocs %}

{% docs col_resolved_at %}
Timestamp when the ticket was resolved. Null if still open.
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

{% docs col_csat_score %}
Customer satisfaction score (1-5). Null if the customer has not yet rated
the interaction.
{% enddocs %}

{% docs col_first_response_seconds %}
Time to first agent response in seconds. Null if no response has been sent.
{% enddocs %}
