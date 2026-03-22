with events as (

    select
        e.event_type,
        e.event_time,
        coalesce(e.user_id, i.user_id) as resolved_user_id
    from {{ ref('int_events_normalized') }} as e
    left join {{ ref('int_identity_stitched') }} as i
        on
            e.anon_id = i.anon_id
            and e.event_time >= i.valid_from
            and e.event_time < coalesce(
                i.valid_to, timestamp('9999-12-31')
            )
    where e.event_type in (
        'page_view',
        'signup',
        'activation',
        'feature_use',
        'checkout_start'
    )

),

stage_mapping as (

    select
        resolved_user_id,
        event_type,
        event_time,
        case event_type
            when 'page_view' then 1
            when 'signup' then 2
            when 'activation' then 3
            when 'feature_use' then 4
            when 'checkout_start' then 5
        end as stage_ordinal
    from events
    where resolved_user_id is not null

),

user_max_stage as (

    select
        resolved_user_id,
        max(stage_ordinal) as max_stage_ordinal
    from stage_mapping
    group by all

),

stages_reached as (

    select
        s.resolved_user_id as user_id,
        s.event_type as stage,
        s.stage_ordinal,
        min(s.event_time) as stage_reached_at,
        u.max_stage_ordinal
    from stage_mapping as s
    inner join user_max_stage as u
        on s.resolved_user_id = u.resolved_user_id
    where s.stage_ordinal <= u.max_stage_ordinal
    group by all

)

select
    user_id,
    stage,
    stage_reached_at,
    stage_ordinal = max_stage_ordinal as is_current_stage
from stages_reached
