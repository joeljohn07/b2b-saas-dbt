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

joined_events as (

    select
        user_id,
        account_id,
        role,
        event_time as valid_from,
        lead(event_time) over (
            partition by user_id, account_id
            order by event_time
        ) as next_event_time,
        lead(event_type) over (
            partition by user_id, account_id
            order by event_time
        ) as next_event_type
    from membership_events
    where event_type = 'member_joined'

)

select
    user_id,
    account_id,
    role,
    valid_from,
    case
        when next_event_type = 'member_removed' then next_event_time
    end as valid_to,
    date_diff(
        date(coalesce(
            case when next_event_type = 'member_removed' then next_event_time end,
            current_timestamp()
        )),
        date(valid_from),
        day
    ) as membership_duration_days
from joined_events
