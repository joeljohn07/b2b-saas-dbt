with source as (

    select
        ticket_id,
        user_id,
        account_id,
        created_at,
        resolved_at,
        _loaded_at,
        category,
        priority,
        status,
        csat_score,
        first_response_seconds
    from {{ source('support', 'tickets') }}

),

renamed as (

    select
        ticket_id,
        user_id,
        account_id,
        created_at,
        resolved_at,
        _loaded_at,
        category,
        priority,
        status,
        csat_score,
        first_response_seconds

    from source

)

select
    ticket_id,
    user_id,
    account_id,
    created_at,
    resolved_at,
    _loaded_at,
    category,
    priority,
    status,
    csat_score,
    first_response_seconds
from renamed
