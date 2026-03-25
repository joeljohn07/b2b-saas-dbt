with signups as (

    select
        event_id,
        user_id,
        event_time,
        event_date,
        signup_method,
        channel,
        platform,
        device_type,
        browser,
        utm_source,
        utm_medium,
        utm_campaign
    from {{ ref('int_events_normalized') }}
    where event_type = 'signup'

)

select
    farm_fingerprint(event_id) as signup_key,
    event_id,
    user_id,
    farm_fingerprint(user_id) as user_key,
    cast(format_date('%Y%m%d', event_date) as int64) as signup_date_key,
    event_time as signup_at,
    signup_method,
    channel,
    farm_fingerprint(channel) as channel_key,
    platform,
    device_type,
    browser,
    utm_source,
    utm_medium,
    utm_campaign
from signups
