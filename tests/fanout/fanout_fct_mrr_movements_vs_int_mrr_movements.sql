-- Fail if fct_mrr_movements and int_mrr_movements have different row counts.
-- fct_mrr_movements is a 1:1 projection of int_mrr_movements with no filters —
-- any mismatch indicates an upstream join multiplied or dropped rows.

{{ config(
    severity='error',
    tags=['data_quality'],
    description='fct_mrr_movements row count must equal int_mrr_movements — no rows added or dropped'
) }}

with counts as (

    select
        (select count(*) from {{ ref('fct_mrr_movements') }}) as mart_count,
        (select count(*) from {{ ref('int_mrr_movements') }}) as source_count

)

select
    mart_count,
    source_count,
    mart_count - source_count as row_delta
from counts
where mart_count != source_count
