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
        timestamp_sub(transition_time, interval 90 day)
            as valid_from,
        next_transition_time as valid_to,
        case
            when recency_rank = 1 then 'last_touch'
            else 'historical'
        end as stitch_source
    from intervals

),

capped as (

    select
        w.anon_id,
        w.user_id,
        greatest(
            w.valid_from,
            coalesce(
                lag(w.valid_to) over (
                    partition by w.anon_id
                    order by w.valid_from
                ),
                w.valid_from
            )
        ) as valid_from,
        w.valid_to,
        w.stitch_source
    from with_lookback as w

)

select
    anon_id,
    user_id,
    valid_from,
    valid_to,
    stitch_source
from capped
where valid_from < coalesce(valid_to, timestamp('9999-12-31'))
