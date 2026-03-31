-- Fixture test: time-regression in event_type (page_view after checkout_start).
-- Validates that a later page_view event does not cause a monotonicity violation —
-- stage_reached_at is set to the FIRST occurrence of each event_type, so the later
-- page_view at 09:00 does not change stage_ordinal 1's stage_reached_at of 08:00.
-- Applies funnel stage derivation and the monotonicity lag check inline.
-- Expects 0 rows: no stage_ordinal should have stage_reached_at < prev_stage_reached_at.

{{ config(
    severity='error',
    tags=['fixture', 'data_quality'],
    description='Assert time-regression in event_type does not cause monotonicity violation in fixture_events_stage_regression'
) }}

with events as (
    select * from {{ ref('fixture_events_stage_regression') }}
),

stages as (
    select
        user_id,
        case event_type
            when 'page_view'      then 1
            when 'signup'         then 2
            when 'activation'     then 3
            when 'feature_use'    then 4
            when 'checkout_start' then 5
        end as stage_ordinal,
        min(event_time) over (
            partition by user_id, event_type
        ) as stage_reached_at
    from events
    where event_type in ('page_view', 'signup', 'activation', 'feature_use', 'checkout_start')
),

distinct_stages as (
    select distinct user_id, stage_ordinal, stage_reached_at
    from stages
),

lagged as (
    select
        user_id,
        stage_ordinal,
        stage_reached_at,
        lag(stage_reached_at) over (
            partition by user_id
            order by stage_ordinal
        ) as prev_stage_reached_at
    from distinct_stages
)

select user_id, stage_ordinal, stage_reached_at, prev_stage_reached_at
from lagged
where
    prev_stage_reached_at is not null
    and stage_reached_at < prev_stage_reached_at
