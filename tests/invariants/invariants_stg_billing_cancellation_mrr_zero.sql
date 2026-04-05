-- Assert cancellation events carry mrr_amount = 0.
-- int_mrr_movements uses the mrr_amount column directly when computing the
-- churn component; if a cancellation event ever emits a non-zero mrr_amount
-- the churn figure will be understated (or negated). The staging contract
-- enforces not_null and >= 0, but not the cancellation-specific zero, so
-- this invariant backfills the hidden assumption.

{{ config(
    severity='error',
    tags=['data_quality'],
    description='Assert cancellation subscription events have mrr_amount = 0'
) }}

select
    subscription_event_id,
    event_type,
    mrr_amount
from {{ ref('stg_billing__subscriptions') }}
where event_type = 'cancellation'
    and mrr_amount != 0
