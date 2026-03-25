select
    farm_fingerprint(session_id) as session_key,
    session_id,
    stitched_user_id as user_id,
    farm_fingerprint(stitched_user_id) as user_key,
    cast(format_date('%Y%m%d', session_date) as int64) as session_date_key,
    session_start_at,
    session_end_at,
    session_duration_seconds,
    event_count,
    page_view_count,
    platform,
    device_type,
    browser,
    utm_source,
    utm_medium,
    utm_campaign
from {{ ref('int_sessions') }}
