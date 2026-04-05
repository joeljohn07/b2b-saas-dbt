-- Validates dedup removed ~0.5% duplicate events, not more than 1%.
-- If more than 1% of rows were removed, something is wrong with
-- the dedup logic or source data quality has degraded.

{{ config(
    severity='error',
    tags=['data_quality'],
    description='Validates dedup removed ~0.5% of events (not >1%) within the reconciliation window. Historical dedup beyond this window is not tested — accepted trade-off for CI scan cost. Fails loudly when the window is empty so an idle dataset cannot false-green.'
) }}

with counts as (

    select
        (
            select count(*)
            from {{ ref('stg_funnel__events') }}
            where _loaded_at >= timestamp_sub(
                current_timestamp(),
                interval {{ var('reconciliation_dedup_test_window_days') }} day
            )
        ) as staging_count,
        (
            select count(*)
            from {{ ref('int_events_normalized') }}
            where _loaded_at >= timestamp_sub(
                current_timestamp(),
                interval {{ var('reconciliation_dedup_test_window_days') }} day
            )
        ) as normalized_count

)

select
    staging_count,
    normalized_count,
    1.0 - (cast(normalized_count as float64) / nullif(staging_count, 0))
        as dedup_rate
from counts
where
    staging_count = 0
    or 1.0 - (cast(normalized_count as float64) / nullif(staging_count, 0)) > 0.01
    or normalized_count > staging_count
