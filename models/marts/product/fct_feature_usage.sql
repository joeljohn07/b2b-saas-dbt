with feature_events as (

    select
        event_id,
        user_id,
        account_id,
        event_time,
        event_date,
        feature_name,
        feature_duration_seconds,
        platform,
        device_type
    from {{ ref('int_events_normalized') }}
    where
        event_type = 'feature_use'
        and user_id is not null

)

select
    farm_fingerprint(event_id) as feature_usage_key,
    event_id,
    user_id,
    farm_fingerprint(user_id) as user_key,
    account_id,
    case when account_id is not null then farm_fingerprint(account_id) end as account_key,
    cast(format_date('%Y%m%d', event_date) as int64) as usage_date_key,
    event_time as usage_at,
    feature_name,
    feature_duration_seconds,
    platform,
    device_type
from feature_events
