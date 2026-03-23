with activity as (

    select
        m.account_id,
        count(distinct s.session_id) as session_count,
        sum(s.event_count) as total_events
    from {{ ref('int_sessions') }} as s
    inner join {{ ref('int_account_memberships') }} as m
        on
            s.stitched_user_id = m.user_id
            and s.session_start_at >= m.valid_from
            and s.session_start_at < coalesce(
                m.valid_to, timestamp('9999-12-31')
            )
    where
        s.session_start_at >= timestamp_sub(
            current_timestamp(), interval 28 day
        )
    group by all

),

billing as (

    select
        account_id,
        max(case when is_active then 1 else 0 end) as has_active_sub,
        max(event_time) as last_billing_event
    from {{ ref('int_subscription_lifecycle') }}
    where
        event_time >= timestamp_sub(
            current_timestamp(), interval 28 day
        )
    group by all

),

support as (

    select
        account_id,
        countif(not is_resolved) as open_tickets,
        avg(
            case when is_resolved then csat_score end
        ) as avg_csat,
        avg(
            case when is_resolved then resolution_time_hours end
        ) as avg_resolution_hours
    from {{ ref('int_ticket_metrics') }}
    where
        created_at >= timestamp_sub(
            current_timestamp(), interval 28 day
        )
    group by all

),

accounts as (

    select distinct account_id
    from {{ ref('int_subscription_lifecycle') }}

),

scored as (

    select
        acc.account_id,
        least(
            coalesce(a.session_count, 0) / 10.0 * 100, 100
        ) as activity_score,
        case
            when
                b.has_active_sub = 1
                and date_diff(
                    current_date(),
                    date(b.last_billing_event),
                    day
                ) <= 90
                then 100
            when b.has_active_sub = 1 then 70
            when b.has_active_sub = 0 then 20
            else 0
        end as billing_score,
        case
            when
                coalesce(s.open_tickets, 0) = 0
                and coalesce(s.avg_csat, 5) >= 4
                then 100
            when
                coalesce(s.open_tickets, 0) <= 2
                and coalesce(s.avg_csat, 3) >= 3
                then 70
            when coalesce(s.open_tickets, 0) <= 5
                then 40
            else 10
        end as support_score
    from accounts as acc
    left join activity as a on acc.account_id = a.account_id
    left join billing as b on acc.account_id = b.account_id
    left join support as s on acc.account_id = s.account_id

)

select
    account_id,
    greatest(0, least(
        100,
        0.4 * activity_score + 0.3 * billing_score + 0.3 * support_score
    )) as health_score,
    activity_score,
    billing_score,
    support_score,
    current_timestamp() as calculated_at,
    28 as trailing_window_days
from scored
