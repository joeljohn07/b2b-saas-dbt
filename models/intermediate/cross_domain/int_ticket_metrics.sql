with source as (

    select
        ticket_id,
        user_id,
        account_id,
        created_at,
        resolved_at,
        category,
        priority,
        status,
        csat_score,
        first_response_seconds
    from {{ ref('stg_support__tickets') }}

),

enriched as (

    select
        ticket_id,
        user_id,
        account_id,
        created_at,
        resolved_at,
        category,
        priority,
        status,
        csat_score,
        timestamp_diff(resolved_at, created_at, second) / 3600.0
            as resolution_time_hours,
        first_response_seconds / 3600.0 as first_response_hours,
        status in ('resolved', 'closed') as is_resolved
    from source

)

select
    ticket_id,
    user_id,
    account_id,
    created_at,
    resolved_at,
    category,
    priority,
    status,
    csat_score,
    resolution_time_hours,
    first_response_hours,
    is_resolved
from enriched
