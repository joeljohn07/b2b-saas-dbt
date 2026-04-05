-- Validates dedup removed ~0.5% duplicate events, not more than 1%.
-- If more than 1% of rows were removed, something is wrong with
-- the dedup logic or source data quality has degraded.

{{ config(
    severity='error',
    tags=['data_quality'],
    description='Validates dedup removed ~0.5% of events (not >1%) within the reconciliation window. The window is anchored to max(_loaded_at) in staging so the test scans the actual data range rather than wall-clock time — CI datasets built from fixtures with frozen timestamps still exercise the check. Historical dedup beyond the window is not tested — accepted trade-off for CI scan cost. Fails loudly when the window is empty so an idle dataset cannot false-green.'
) }}

with window_anchor as (

    select timestamp_sub(
        max(_loaded_at),
        interval {{ var('reconciliation_dedup_test_window_days') }} day
    ) as cutoff
    from {{ ref('stg_funnel__events') }}

),

counts as (

    select
        (
            select count(*)
            from {{ ref('stg_funnel__events') }}
            where _loaded_at >= (select cutoff from window_anchor)
        ) as staging_count,
        (
            select count(*)
            from {{ ref('int_events_normalized') }}
            where _loaded_at >= (select cutoff from window_anchor)
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
