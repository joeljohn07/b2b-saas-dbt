select
    farm_fingerprint(ticket_id) as ticket_key,
    ticket_id,
    user_id,
    farm_fingerprint(user_id) as user_key,
    account_id,
    farm_fingerprint(account_id) as account_key,
    cast(format_date('%Y%m%d', date(created_at)) as int64) as created_date_key,
    created_at,
    resolved_at,
    category,
    priority,
    status,
    csat_score,
    resolution_time_hours,
    first_response_hours,
    is_resolved
from {{ ref('int_ticket_metrics') }}
