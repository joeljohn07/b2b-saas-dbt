with authenticated_events as (

    select
        anon_id,
        user_id,
        event_time
    from {{ ref('int_events_normalized') }}
    where user_id is not null

),

first_auth_per_anon as (

    select
        anon_id,
        user_id,
        min(event_time) as first_auth_time
    from authenticated_events
    group by all

),

ranked as (

    select
        anon_id,
        user_id,
        first_auth_time,
        row_number() over (
            partition by anon_id
            order by first_auth_time desc
        ) as recency_rank,
        lead(first_auth_time) over (
            partition by anon_id
            order by first_auth_time asc
        ) as next_user_start
    from first_auth_per_anon

),

intervals as (

    select
        anon_id,
        user_id,
        first_auth_time as valid_from,
        next_user_start as valid_to,
        case
            when recency_rank = 1 then 'last_touch'
            else 'historical'
        end as stitch_source
    from ranked

),

with_stitch_window as (

    select
        i.anon_id,
        i.user_id,
        i.valid_from,
        i.valid_to,
        i.stitch_source,
        min(e.event_time) as earliest_anon_event
    from intervals as i
    inner join {{ ref('int_events_normalized') }} as e
        on i.anon_id = e.anon_id
    group by all

)

select
    anon_id,
    user_id,
    valid_from,
    valid_to,
    stitch_source
from with_stitch_window
where
    timestamp_diff(valid_from, earliest_anon_event, day) <= 90
