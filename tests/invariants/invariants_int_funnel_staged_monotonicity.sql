-- Surfaces users where stage_reached_at is not monotonically increasing with stage_ordinal.
-- This is a soft constraint — users can legitimately have page_views after signup (ordinal 1
-- reached after ordinal 2), so violations do not indicate a model bug. Useful for spotting
-- unusual funnel patterns or data pipeline anomalies.

{{ config(
    severity='warn',
    tags=['data_quality'],
    description='Warn when stage_reached_at is not monotonically increasing with stage_ordinal (soft constraint)'
) }}

with lagged as (
    select
        user_id,
        stage_ordinal,
        stage_reached_at,
        lag(stage_reached_at) over (
            partition by user_id
            order by stage_ordinal
        ) as prev_stage_reached_at
    from {{ ref('int_funnel_staged') }}
)

select
    user_id,
    stage_ordinal,
    stage_reached_at,
    prev_stage_reached_at
from lagged
where
    prev_stage_reached_at is not null
    and stage_reached_at < prev_stage_reached_at
