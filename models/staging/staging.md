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

## stg_funnel__events

{% docs stg_funnel__events %}
Staged product events. Shreds the properties JSON column into flat typed
columns. Passes experiment_flags as-is for downstream unnesting in
int_experiment_results.
{% enddocs %}

---

## stg_billing__subscriptions

{% docs stg_billing__subscriptions %}
Staged subscription lifecycle events. Pass-through from source with canonical
naming. Covers trial starts/ends, subscription starts, upgrades, downgrades,
renewals, cancellations, and reactivations.
{% enddocs %}

---

## stg_billing__invoices

{% docs stg_billing__invoices %}
Staged invoices. Pass-through with line_items kept as raw JSON string — not
shredded at any layer.
{% enddocs %}

---

## stg_marketing__spend

{% docs stg_marketing__spend %}
Staged marketing spend records. Renames source 'date' column to 'spend_date'
to avoid reserved word conflicts.
{% enddocs %}

---

## stg_support__tickets

{% docs stg_support__tickets %}
Staged support tickets. Clean pass-through with canonical naming. Includes
category, priority, resolution status, CSAT scores, and response times.
{% enddocs %}
