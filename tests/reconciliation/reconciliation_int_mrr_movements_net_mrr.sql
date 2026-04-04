-- Validates that SUM(mrr_delta) per account equals the account's final MRR.
-- Compares the cumulative MRR movements against the latest subscription
-- lifecycle event's mrr_amount for each account.

{{ config(
    severity='error',
    tags=['billing_validation'],
    description='SUM(mrr_delta) must equal final MRR per account'
) }}

with movements_total as (

    select
        account_id,
        sum(mrr_delta) as total_mrr_delta
    from {{ ref('int_mrr_movements') }}
    group by all

),

latest_lifecycle as (

    select
        account_id,
        subscription_id,
        mrr_amount as final_mrr
    from {{ ref('int_subscription_lifecycle') }}
    where event_type not in ('trial_start', 'trial_end')
    qualify row_number() over (
        partition by account_id, subscription_id
        order by event_time desc
    ) = 1

),

latest_mrr_per_account as (

    select
        account_id,
        sum(final_mrr) as final_mrr
    from latest_lifecycle
    group by all

)

select
    coalesce(m.account_id, l.account_id) as account_id,
    m.total_mrr_delta,
    l.final_mrr,
    abs(coalesce(m.total_mrr_delta, 0) - coalesce(l.final_mrr, 0)) as difference
from movements_total as m
full outer join latest_mrr_per_account as l
    on m.account_id = l.account_id
where
    abs(coalesce(m.total_mrr_delta, 0) - coalesce(l.final_mrr, 0)) > 0.01
    -- accounts in lifecycle but no movements (e.g. trial-only with no MRR events)
    or (m.account_id is null and l.final_mrr > 0)
    -- accounts with movements but no lifecycle row (e.g. fully churned); zero delta is acceptable
    or (l.account_id is null and coalesce(m.total_mrr_delta, 0) <> 0)
