-- Validates that each user has exactly one is_current_stage = true row.

{{ config(
    severity='error',
    tags=['operations_alert'],
    description='Validates that each user has exactly one is_current_stage = true row.'
) }}

select
    user_id,
    countif(is_current_stage) as current_stage_count
from {{ ref('int_funnel_staged') }}
group by all
having countif(is_current_stage) != 1
