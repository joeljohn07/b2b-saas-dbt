with membership_events as (

    select
        user_id,
        account_id,
        event_type,
        event_time,
        member_role as role
    from {{ ref('int_events_normalized') }}
    where
        event_type in ('member_joined', 'member_removed')
        and user_id is not null
        and account_id is not null

),

with_next_event as (

    select
        user_id,
        account_id,
        event_type,
        event_time,
        role,
        lead(event_time) over (
            partition by user_id, account_id
            order by event_time, event_type
        ) as next_event_time
    from membership_events

),

joined_only as (

    select
        user_id,
        account_id,
        role,
        event_time as valid_from,
        next_event_time as valid_to
    from with_next_event
    where event_type = 'member_joined'

)

select
    user_id,
    account_id,
    role,
    valid_from,
    valid_to,
    date_diff(
        date(coalesce(valid_to, current_timestamp())),
        date(valid_from),
        day
    ) as membership_duration_days
from joined_only
