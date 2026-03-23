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
    _loaded_at
from source
