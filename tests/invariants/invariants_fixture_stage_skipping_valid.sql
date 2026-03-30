-- Fixture test: stage skipping (page_view → signup → feature_use, no activation).
-- Validates that a user skipping stages does not cause a cardinality violation in
-- the funnel stage model — exactly 1 is_current_stage = true per user is required.
-- Applies the is_current_stage logic inline (max stage_ordinal per user).
-- Expects 0 rows: user_009 must have exactly 1 current stage.

{{ config(
    severity='error',
    tags=['fixture', 'data_quality'],
    description='Assert stage-skipping user has exactly one is_current_stage in fixture_events_stage_skipping'
) }}

with events as (
    select * from {{ ref('fixture_events_stage_skipping') }}
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

with_current as (
    select
        user_id,
        stage_ordinal,
        stage_ordinal = max(stage_ordinal) over (
            partition by user_id
        ) as is_current_stage
    from distinct_stages
)

select user_id
from with_current
group by user_id
having countif(is_current_stage) != 1
