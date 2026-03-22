with source as (

    select
        subscription_event_id,
        subscription_id,
        user_id,
        account_id,
        event_type,
        event_time,
        _loaded_at,
        plan,
        previous_plan,
        billing_cycle,
        mrr_amount,
        currency,
        cancel_reason,
        is_voluntary
    from {{ source('billing', 'subscriptions') }}

),

renamed as (

    select
        subscription_event_id,
        subscription_id,
        user_id,
        account_id,
        event_type,
        event_time,
        _loaded_at,
        plan,
        previous_plan,
        billing_cycle,
        mrr_amount,
        currency,
        cancel_reason,
        is_voluntary

    from source

)

select
    subscription_event_id,
    subscription_id,
    user_id,
    account_id,
    event_type,
    event_time,
    _loaded_at,
    plan,
    previous_plan,
    billing_cycle,
    mrr_amount,
    currency,
    cancel_reason,
    is_voluntary
from renamed
