with source as (

    select
        subscription_event_id,
        subscription_id,
        user_id,
        account_id,
        event_type,
        event_time,
        plan,
        previous_plan,
        billing_cycle,
        mrr_amount,
        currency,
        cancel_reason,
        is_voluntary
    from {{ ref('stg_billing__subscriptions') }}

),

enriched as (

    select
        subscription_event_id,
        subscription_id,
        user_id,
        account_id,
        event_type,
        event_time,
        plan,
        previous_plan,
        billing_cycle,
        mrr_amount,
        currency,
        cancel_reason,
        is_voluntary,
        event_type in (
            'subscription_start',
            'upgrade',
            'downgrade',
            'renewal',
            'reactivation'
        ) as is_active,
        date_diff(
            date(event_time),
            date(lag(event_time) over (
                partition by account_id, subscription_id
                order by event_time
            )),
            day
        ) as days_since_previous_event
    from source

)

select
    subscription_event_id,
    subscription_id,
    user_id,
    account_id,
    event_type,
    event_time,
    plan,
    previous_plan,
    billing_cycle,
    mrr_amount,
    currency,
    cancel_reason,
    is_voluntary,
    is_active,
    days_since_previous_event
from enriched
