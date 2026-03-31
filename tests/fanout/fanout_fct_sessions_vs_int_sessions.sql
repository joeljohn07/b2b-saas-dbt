-- Validates fct_sessions row count exactly equals int_sessions.
-- fct_sessions is a 1:1 passthrough from int_sessions — any overage indicates a bad join.

{{ config(
    severity='error',
    tags=['data_quality'],
    description='Assert fct_sessions count exactly equals int_sessions (1:1 passthrough)'
) }}

with counts as (
    select
        (select count(*) from {{ ref('fct_sessions') }})           as mart_count,
        (select count(*) from {{ ref('int_sessions') }})           as intermediate_count
)

select
    mart_count,
    intermediate_count,
    round(safe_divide(mart_count, intermediate_count), 4)          as fanout_ratio
from counts
where mart_count > intermediate_count
