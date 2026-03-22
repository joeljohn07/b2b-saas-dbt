with checkouts as (

    select
        event_id as checkout_event_id,
        user_id,
        account_id,
        event_time as checkout_at,
        target_plan
    from {{ ref('int_events_normalized') }}
    where event_type = 'checkout_start'

),

subscriptions as (

    select
        subscription_event_id,
        account_id,
        event_time as subscription_at
    from {{ ref('int_subscription_lifecycle') }}
    where event_type = 'subscription_start'

),

candidates as (

    select
        c.checkout_event_id,
        s.subscription_event_id,
        s.subscription_at,
        row_number() over (
            partition by c.checkout_event_id
            order by s.subscription_at asc
        ) as checkout_rank,
        row_number() over (
            partition by s.subscription_event_id
            order by c.checkout_at desc
        ) as sub_rank
    from checkouts as c
    inner join subscriptions as s
        on
            c.account_id = s.account_id
            and c.checkout_at <= s.subscription_at
            and s.subscription_at <= timestamp_add(
                c.checkout_at, interval 30 day
            )

),

winners as (

    select
        checkout_event_id,
        subscription_event_id,
        subscription_at
    from candidates
    where checkout_rank = 1 and sub_rank = 1

)

select
    c.checkout_event_id,
    c.user_id,
    c.account_id,
    c.checkout_at,
    c.target_plan,
    w.subscription_event_id,
    w.subscription_at,
    w.subscription_event_id is not null as converted,
    date_diff(
        date(w.subscription_at), date(c.checkout_at), day
    ) as time_to_conversion_days
from checkouts as c
left join winners as w
    on c.checkout_event_id = w.checkout_event_id
