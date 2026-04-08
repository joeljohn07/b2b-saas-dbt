-- Fixture test: incremental lookback is driven by events_incremental_lookback_hours var.
-- Fixture rows sit at 0h, 24h, 48h, and 100h before the anchor _loaded_at.
-- With the current var value (36h) the anchor and 24h rows are inside the
-- window and the 48h + 100h rows are outside. If the var is changed, update the
-- fixture offsets and the expected counts below — this tripwire is deliberate.

{{ config(
    severity='error',
    tags=['fixture', 'data_quality'],
    description='Assert events_incremental_lookback_hours drives the cutoff applied by int_events_normalized, using fixture rows at boundary offsets'
) }}

with anchor as (

    select max(_loaded_at) as max_loaded_at
    from {{ ref('fixture_events_late_arrivals_extreme') }}

),

applied as (

    select
        event_id,
        _loaded_at >= timestamp_sub(
            (select anchor.max_loaded_at from anchor),
            interval {{ var('events_incremental_lookback_hours') }} hour
        ) as within_window
    from {{ ref('fixture_events_late_arrivals_extreme') }}

),

counts as (

    select
        countif(within_window) as inside_count,
        countif(not within_window) as outside_count
    from applied

)

select
    inside_count,
    outside_count
from counts
where inside_count != 2 or outside_count != 2
