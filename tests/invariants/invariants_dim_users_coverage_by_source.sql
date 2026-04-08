-- Assert every billing and support user_id appears in dim_users.
-- Missing users indicate the dim_users union does not include all
-- source domains, causing FK test failures on downstream facts.

{{ config(
    severity='error',
    tags=['data_quality'],
    description='Assert dim_users covers all user_ids from billing and support sources'
) }}

with billing_users as (
    select distinct user_id
    from {{ ref('int_subscription_lifecycle') }}
),

support_users as (
    select distinct user_id
    from {{ ref('int_ticket_metrics') }}
),

all_source_users as (
    select user_id from billing_users
    union distinct
    select user_id from support_users
)

select s.user_id
from all_source_users as s
left join {{ ref('dim_users') }} as d on s.user_id = d.user_id
where d.user_id is null
