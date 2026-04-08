-- Assert that accounts with at least one active subscription have
-- billing_score > 0. A zero billing_score for an active subscriber
-- indicates the billing CTE uses a time-windowed query that misses
-- subscriptions with infrequent billing events (e.g. annual plans).

{{ config(
    severity='error',
    tags=['data_quality'],
    description='Assert billing_score > 0 for accounts with an active subscription — detects annual sub dropout from time-windowed billing CTE'
) }}

with active_accounts as (

    select distinct account_id
    from {{ ref('int_subscription_lifecycle') }}
    where is_active

)

select
    h.account_id,
    h.billing_score
from {{ ref('int_account_health') }} as h
inner join active_accounts as aa
    on h.account_id = aa.account_id
where h.billing_score = 0
