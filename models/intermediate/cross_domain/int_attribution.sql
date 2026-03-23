with events as (

    select
        coalesce(e.user_id, i.user_id) as resolved_user_id,
        e.event_time,
        e.event_type,
        e.channel,
        e.utm_source,
        e.utm_medium,
        e.utm_campaign
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

attribution_window as (

    select
        e.resolved_user_id,
        e.event_time,
        e.channel,
        e.utm_source,
        e.utm_medium,
        e.utm_campaign,
        a.activation_at
    from events as e
    inner join activations as a
        on e.resolved_user_id = a.resolved_user_id
    where
        e.event_time < a.activation_at
        and e.event_time >= timestamp_sub(
            a.activation_at, interval 30 day
        )

),

first_touch as (

    select
        resolved_user_id,
        channel as first_touch_channel,
        utm_source as first_touch_source,
        utm_medium as first_touch_medium,
        utm_campaign as first_touch_campaign,
        event_time as first_touch_at
    from attribution_window
    qualify row_number() over (
        partition by resolved_user_id
        order by event_time asc
    ) = 1

),

last_touch as (

    select
        resolved_user_id,
        channel as last_touch_channel,
        utm_source as last_touch_source,
        utm_medium as last_touch_medium,
        utm_campaign as last_touch_campaign,
        event_time as last_touch_at
    from attribution_window
    qualify row_number() over (
        partition by resolved_user_id
        order by event_time desc
    ) = 1

)

select
    f.resolved_user_id as user_id,
    f.first_touch_channel,
    f.first_touch_source,
    f.first_touch_medium,
    f.first_touch_campaign,
    f.first_touch_at,
    l.last_touch_channel,
    l.last_touch_source,
    l.last_touch_medium,
    l.last_touch_campaign,
    l.last_touch_at,
    a.activation_at
from first_touch as f
inner join last_touch as l
    on f.resolved_user_id = l.resolved_user_id
inner join activations as a
    on f.resolved_user_id = a.resolved_user_id
