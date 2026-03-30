-- Validates fct_sessions row count does not exceed int_sessions by more than 1%.
-- Detects accidental fan-out from a bad join in mart assembly.
-- fct_sessions is assembled 1:1 from int_sessions — any ratio > 1.01 indicates a bad join.

{{ config(
    severity='error',
    tags=['data_quality'],
    description='Assert fct_sessions count does not exceed int_sessions by more than 1%'
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
where mart_count > intermediate_count * 1.01
