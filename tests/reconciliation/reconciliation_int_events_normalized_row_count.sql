-- Validates dedup removed ~0.5% duplicate events, not more than 1%.
-- If more than 1% of rows were removed, something is wrong with
-- the dedup logic or source data quality has degraded.

{{ config(severity='error') }}

with counts as (

    select
        (select count(*) from {{ ref('stg_funnel__events') }}) as staging_count,
        (select count(*) from {{ ref('int_events_normalized') }}) as normalized_count

)

select
    staging_count,
    normalized_count,
    1.0 - (cast(normalized_count as float64) / nullif(staging_count, 0))
        as dedup_rate
from counts
where
    1.0 - (cast(normalized_count as float64) / nullif(staging_count, 0)) > 0.01
    or normalized_count > staging_count
