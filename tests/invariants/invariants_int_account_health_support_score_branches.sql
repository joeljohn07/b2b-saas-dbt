-- Validates that the support_score branch logic handles null CSAT correctly:
-- accounts with no support interactions (null avg_csat, 0 open tickets)
-- must score 70 (neutral), not 100 (perfect).

{{ config(
    severity='error',
    tags=['operations_alert'],
    description='Support score must be 70 for accounts with no support interactions (null CSAT + 0 open tickets)'
) }}

with support_data as (

    select
        h.account_id,
        h.support_score,
        t.has_tickets
    from {{ ref('int_account_health') }} as h
    left join (
        select
            account_id,
            true as has_tickets
        from {{ ref('int_ticket_metrics') }}
        where created_at >= timestamp_sub(
            current_timestamp(),
            interval {{ var('account_health_trailing_days') }} day
        )
        group by all
    ) as t on h.account_id = t.account_id

)

select
    account_id,
    support_score,
    has_tickets
from support_data
where
    -- accounts with no tickets should score exactly 70
    (has_tickets is null and support_score != 70)
    -- support score must never exceed 100
    or support_score > 100
