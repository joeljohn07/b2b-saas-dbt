-- Assert every support account_id appears in dim_accounts.
-- Missing accounts indicate the dim_accounts union does not include
-- the support domain, causing FK test failures on fct_support_tickets.

{{ config(
    severity='error',
    tags=['data_quality'],
    description='Assert dim_accounts covers all account_ids from support tickets'
) }}

with support_accounts as (
    select distinct account_id
    from {{ ref('int_ticket_metrics') }}
)

select s.account_id
from support_accounts as s
left join {{ ref('dim_accounts') }} as d on s.account_id = d.account_id
where d.account_id is null
