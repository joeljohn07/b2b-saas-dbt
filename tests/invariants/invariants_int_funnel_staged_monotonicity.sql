-- Validates funnel stage_reached_at increases monotonically with stage_ordinal per user.
-- A user cannot reach a higher stage ordinal before a lower one in time — stage regression
-- indicates bad event ordering or a logic error in int_funnel_staged.
--
-- Users with only one funnel stage produce a NULL prev_stage_reached_at (lag over a single row)
-- and are excluded by the IS NOT NULL guard — they cannot violate monotonicity.

{{ config(
    severity='error',
    tags=['data_quality'],
    description='Assert stage_reached_at is monotonically increasing with stage_ordinal in int_funnel_staged'
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
