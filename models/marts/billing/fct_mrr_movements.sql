select
    farm_fingerprint(concat(account_id, '|', cast(subscription_event_id as string))) as mrr_movement_key,
    account_id,
    farm_fingerprint(account_id) as account_key,
    subscription_event_id,
    subscription_id,
    cast(format_date('%Y%m%d', movement_date) as int64) as movement_date_key,
    movement_date,
    movement_type,
    mrr_before,
    mrr_after,
    mrr_delta
from {{ ref('int_mrr_movements') }}
