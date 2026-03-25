select
    farm_fingerprint(spend_id) as spend_key,
    spend_id,
    cast(format_date('%Y%m%d', spend_date) as int64) as spend_date_key,
    channel,
    farm_fingerprint(channel) as channel_key,
    campaign_id,
    campaign_name,
    spend_amount,
    currency,
    impressions,
    clicks
from {{ ref('int_marketing_spend_prep') }}
