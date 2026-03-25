# Marts Model Descriptions

{% docs dim_date %}
Calendar date dimension seeded from a static CSV. Covers 2024-01-01 through
2029-12-31. Grain: one row per calendar date. Used as the conformed date
dimension for all date-keyed facts. Regenerate the seed CSV before the end
date to prevent FK test failures on newer data.
{% enddocs %}

{% docs dim_channels %}
Conformed channel dimension derived from attribution and marketing spend data.
Grain: one row per unique channel. Serves as FK target for first-touch,
last-touch, and acquisition channel role-playing keys.
{% enddocs %}

{% docs dim_sessions %}
Session dimension built from sessionized product events. Grain: one row per
session. Includes device, UTM, and session duration attributes.
{% enddocs %}

{% docs dim_experiments %}
Experiment dimension sourced from the experiment_metadata seed. Grain: one row
per experiment. Contains experiment definitions and status.
{% enddocs %}

{% docs bridge_user_experiments %}
Bridge table resolving the many-to-many relationship between users and
experiments. Grain: one row per user-experiment combination. Includes variant
assignment and first exposure timestamp.
{% enddocs %}

{% docs dim_users %}
User dimension joining attribution, engagement, account membership, and signup
data. Grain: one row per user (SCD Type 1 — current state). The most complex
dimension in the star schema.
{% enddocs %}

{% docs dim_accounts %}
Account dimension joining subscription lifecycle, health scores, member counts,
and acquisition attribution. Grain: one row per account (SCD Type 1 — current
state).
{% enddocs %}

{% docs fct_signups %}
Signup event fact sourced from normalized product events. Grain: one row per
signup event. Includes channel, UTM, and device attributes as degenerate
dimensions.
{% enddocs %}

{% docs fct_activations %}
Activation event fact sourced from attribution data. Grain: one row per user
activation. Only activated users appear (filtered upstream in int_attribution).
{% enddocs %}

{% docs fct_feature_usage %}
Feature usage event fact sourced from normalized product events. Grain: one row
per feature_use event. Tracks feature name, duration, and device context.
{% enddocs %}

{% docs fct_sessions %}
Session fact sourced from sessionized product events. Grain: one row per
session. Carries session duration, event counts, and page view counts as
measures. Device and UTM attributes included as degenerate dimensions.
{% enddocs %}

{% docs fct_marketing_spend %}
Marketing spend fact sourced from marketing spend prep. Grain: one row per
spend record (channel x campaign x date). Tracks spend amount, impressions,
and clicks.
{% enddocs %}

{% docs fct_support_tickets %}
Support ticket fact sourced from ticket metrics. Grain: one row per ticket.
Carries resolution time, first response time, CSAT score, and resolution
status.
{% enddocs %}

{% docs fct_subscriptions %}
Subscription lifecycle event fact sourced from subscription lifecycle. Grain:
one row per subscription event. Tracks plan changes, MRR, billing cycle, and
cancellation details.
{% enddocs %}

{% docs fct_mrr_movements %}
MRR movement fact sourced from MRR movements intermediate. Grain: one row per
MRR movement event per account. Tracks movement type, MRR before/after, and
delta for cohort-based MRR analysis.
{% enddocs %}

{% docs fct_invoices %}
Invoice fact sourced from invoices prep. Grain: one row per invoice. Tracks
amounts, payment status, refunds, and net revenue.
{% enddocs %}

{% docs fct_experiment_exposures %}
Experiment exposure factless fact sourced from experiment results. Grain: one
row per user x experiment. Extends bridge_user_experiments with conversion
metrics (converted, conversion_at) and exposure duration. Composite PK
(user_key + experiment_key).
{% enddocs %}
