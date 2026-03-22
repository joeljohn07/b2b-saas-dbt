with events as (

    select
        coalesce(e.user_id, i.user_id) as resolved_user_id,
        e.event_time,
        e.event_type
    from {{ ref('int_events_normalized') }} as e
    left join {{ ref('int_identity_stitched') }} as i
        on
            e.anon_id = i.anon_id
            and e.event_time >= i.valid_from
            and e.event_time < coalesce(
                i.valid_to, timestamp('9999-12-31')
            )
    where coalesce(e.user_id, i.user_id) is not null

),

activations as (

    select
        resolved_user_id,
        min(event_time) as activation_at
    from events
    where event_type = 'activation'
    group by all

),

week_spine as (

    select week_start
    from
        unnest(
            generate_date_array(
                (select date_trunc(min(date(event_time)), week (monday)) from events),
                current_date(),
                interval 1 week
            )
        ) as week_start

),

users as (

    select distinct resolved_user_id
    from events

),

user_weeks as (

    select
        u.resolved_user_id as user_id,
        w.week_start as snapshot_week_start
    from users as u
    cross join week_spine as w

),

last_activity as (

    select
        uw.user_id,
        uw.snapshot_week_start,
        max(e.event_time) as last_activity_at
    from user_weeks as uw
    left join events as e
        on
            uw.user_id = e.resolved_user_id
            and date(e.event_time) <= date_add(
                uw.snapshot_week_start, interval 6 day
            )
    group by all

),

classified as (

    select
        la.user_id,
        la.snapshot_week_start,
        la.last_activity_at,
        a.activation_at,
        case
            when la.last_activity_at is null
                then date_diff(
                    la.snapshot_week_start, date('2024-01-01'), day
                )
            else date_diff(
                la.snapshot_week_start, date(la.last_activity_at), day
            )
        end as days_since_last_activity,
        case
            when
                a.activation_at is null
                or a.activation_at > timestamp(
                    date_add(la.snapshot_week_start, interval 6 day)
                )
                then 'pre_active'
            when
                la.last_activity_at is not null
                and date_diff(
                    la.snapshot_week_start, date(la.last_activity_at), day
                ) <= 14
                then 'active'
            when
                la.last_activity_at is not null
                and date_diff(
                    la.snapshot_week_start, date(la.last_activity_at), day
                ) <= 42
                then 'dormant'
            else 'disengaged'
        end as engagement_state,
        lag(
            case
                when
                    a.activation_at is null
                    or a.activation_at > timestamp(
                        date_add(la.snapshot_week_start, interval 6 day)
                    )
                    then 'pre_active'
                when
                    la.last_activity_at is not null
                    and date_diff(
                        la.snapshot_week_start,
                        date(la.last_activity_at),
                        day
                    ) <= 14
                    then 'active'
                when
                    la.last_activity_at is not null
                    and date_diff(
                        la.snapshot_week_start,
                        date(la.last_activity_at),
                        day
                    ) <= 42
                    then 'dormant'
                else 'disengaged'
            end
        ) over (
            partition by la.user_id
            order by la.snapshot_week_start
        ) as previous_state
    from last_activity as la
    left join activations as a
        on la.user_id = a.resolved_user_id

)

select
    user_id,
    snapshot_week_start,
    engagement_state,
    previous_state in ('dormant', 'disengaged')
    and engagement_state = 'active' as is_re_engaged,
    days_since_last_activity,
    last_activity_at
from classified
