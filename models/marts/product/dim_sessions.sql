select
    farm_fingerprint(session_id) as session_key,
    session_id,
    cast(format_date('%Y%m%d', session_date) as int64) as session_date_key,
    platform,
    device_type,
    browser,
    utm_source,
    utm_medium,
    utm_campaign,
    session_duration_seconds,
    event_count,
    page_view_count,
from {{ ref('int_sessions') }}
