-- Prep model: enforces the three-layer contract (marts never ref staging).
-- Adds derived metrics; extend here when currency normalisation or dedup is needed.

with source as (

    select
        spend_id,
        spend_date,
        channel,
        campaign_id,
        campaign_name,
        impressions,
        clicks,
        spend_amount,
        currency,
        _loaded_at
    from {{ ref('stg_marketing__spend') }}

)

select
    spend_id,
    spend_date,
    channel,
    campaign_id,
    campaign_name,
    impressions,
    clicks,
    spend_amount,
    currency,
    safe_divide(spend_amount, nullif(clicks, 0)) as cost_per_click,
    safe_divide(clicks, nullif(impressions, 0)) as click_through_rate,
    _loaded_at
from source
