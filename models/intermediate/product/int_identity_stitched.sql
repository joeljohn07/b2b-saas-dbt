with authenticated_events as (

    select
        anon_id,
        user_id,
        event_time
    from {{ ref('int_events_normalized') }}
    where user_id is not null

),

user_transitions as (

    select
        anon_id,
        user_id,
        event_time,
        lag(user_id) over (
            partition by anon_id
            order by event_time, user_id
        ) as prev_user_id
    from authenticated_events

),

transition_starts as (

    select
        anon_id,
        user_id,
        event_time as transition_time
    from user_transitions
    where
        prev_user_id is null
        or prev_user_id != user_id

),

intervals as (

    select
        anon_id,
        user_id,
        transition_time,
        lead(transition_time) over (
            partition by anon_id
            order by transition_time
        ) as next_transition_time,
        lag(transition_time) over (
            partition by anon_id
            order by transition_time
        ) as prev_transition_time,
        row_number() over (
            partition by anon_id
            order by transition_time desc
        ) as recency_rank
    from transition_starts

),

with_lookback as (

    select
        anon_id,
        user_id,
        greatest(
            timestamp_sub(transition_time, interval 90 day),
            coalesce(prev_transition_time, timestamp('1970-01-01'))
        ) as valid_from,
        next_transition_time as valid_to,
        case
            when recency_rank = 1 then 'last_touch'
            else 'historical'
        end as stitch_source
    from intervals

)

select
    anon_id,
    user_id,
    valid_from,
    valid_to,
    stitch_source
from with_lookback
where valid_from < coalesce(valid_to, timestamp('9999-12-31'))
