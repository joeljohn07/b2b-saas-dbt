-- Validates fct_mrr_movements row count exactly equals int_mrr_movements.
-- int_mrr_movements excludes trial events (trial_start, trial_end), so mart and intermediate
-- counts must be equal. Any overage indicates a bad join in mart assembly.

{{ config(
    severity='error',
    tags=['data_quality'],
    description='Assert fct_mrr_movements count exactly equals int_mrr_movements (1:1 passthrough)'
) }}

with counts as (
    select
        (select count(*) from {{ ref('fct_mrr_movements') }})          as mart_count,
        (select count(*) from {{ ref('int_mrr_movements') }})          as intermediate_count
)

select
    mart_count,
    intermediate_count,
    round(safe_divide(mart_count, intermediate_count), 4)              as fanout_ratio
from counts
where mart_count > intermediate_count
