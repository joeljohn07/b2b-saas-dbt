-- Assert days_since_previous_event is always non-negative.
-- A negative value indicates the lag() window compared events
-- across different subscriptions within the same account (the
-- partition must include subscription_id alongside account_id).

{{ config(
    severity='error',
    tags=['data_quality'],
    description='Assert days_since_previous_event is non-negative — detects cross-subscription pollution in the lag partition'
) }}

select
    subscription_event_id,
    account_id,
    subscription_id,
    days_since_previous_event
from {{ ref('int_subscription_lifecycle') }}
where days_since_previous_event < 0
