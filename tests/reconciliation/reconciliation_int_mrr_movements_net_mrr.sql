-- Validates that SUM(mrr_delta) per account equals the account's final MRR.
-- Compares the cumulative MRR movements against the latest subscription
-- lifecycle event's mrr_amount for each account.

{{ config(severity='error') }}

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
        mrr_amount as final_mrr
    from {{ ref('int_subscription_lifecycle') }}
    qualify row_number() over (
        partition by account_id
        order by event_time desc
    ) = 1

)

select
    m.account_id,
    m.total_mrr_delta,
    l.final_mrr,
    abs(m.total_mrr_delta - l.final_mrr) as difference
from movements_total as m
inner join latest_lifecycle as l
    on m.account_id = l.account_id
where abs(m.total_mrr_delta - l.final_mrr) > 0.01
