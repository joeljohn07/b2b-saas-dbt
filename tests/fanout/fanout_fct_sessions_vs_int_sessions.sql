-- Fail if fct_sessions and int_sessions have different row counts.
-- fct_sessions is a 1:1 projection of int_sessions with no filters —
-- any mismatch indicates an upstream join multiplied or dropped rows.

{{ config(
    severity='error',
    tags=['data_quality'],
    description='fct_sessions row count must equal int_sessions — no rows added or dropped'
) }}

with counts as (

    select
        (select count(*) from {{ ref('fct_sessions') }}) as mart_count,
        (select count(*) from {{ ref('int_sessions') }}) as source_count

)

select
    mart_count,
    source_count,
    mart_count - source_count as row_delta
from counts
where mart_count != source_count
