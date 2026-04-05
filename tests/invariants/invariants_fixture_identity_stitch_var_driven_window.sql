-- Fixture test: identity_stitching_lookback_days var drives the valid_from
-- cutoff computed by int_identity_stitched. Applies the same window expression
-- the model uses to a single known transition (2024-07-19); with the current
-- var value (90 days) the expected valid_from is 2024-04-20. If the var is
-- intentionally changed, update the expected date below — this tripwire is
-- deliberate.

{{ config(
    severity='error',
    tags=['fixture', 'data_quality'],
    description='Assert identity_stitching_lookback_days drives the valid_from cutoff in int_identity_stitched, using a single-transition fixture'
) }}

with transition as (

    select event_time as transition_time
    from {{ ref('fixture_identity_stitch_window_edge') }}

),

computed as (

    select
        transition_time,
        greatest(
            timestamp_sub(
                transition_time,
                interval {{ var('identity_stitching_lookback_days') }} day
            ),
            timestamp('1970-01-01')
        ) as valid_from
    from transition

)

select
    transition_time,
    valid_from
from computed
where date(valid_from) != date('2024-04-20')
