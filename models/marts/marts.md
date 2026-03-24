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
