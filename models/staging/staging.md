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
Staged invoices. Pass-through with line_items kept as raw JSON string for
downstream processing in int_invoices_prep.
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
