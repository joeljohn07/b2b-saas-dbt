-- Validates that every user with an activation stage also has a signup stage.
-- Funnel ordering invariant: activation requires signup first.

{{ config(
    severity='error',
    tags=['operations_alert'],
    description='Validates that every user with an activation stage also has a signup stage.'
) }}

with user_stages as (

    select
        user_id,
        max(case when stage = 'activation' then 1 else 0 end)
            as has_activation,
        max(case when stage = 'signup' then 1 else 0 end)
            as has_signup
    from {{ ref('int_funnel_staged') }}
    group by all

)

select
    user_id,
    has_activation,
    has_signup
from user_stages
where has_activation = 1 and has_signup = 0
