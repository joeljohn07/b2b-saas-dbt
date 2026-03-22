with source as (

    select
        spend_id,
        `date`,
        channel,
        campaign_id,
        campaign_name,
        impressions,
        clicks,
        spend_amount,
        currency,
        _loaded_at
    from {{ source('marketing', 'spend') }}

),

renamed as (

    select
        spend_id,
        `date` as spend_date,
        channel,
        campaign_id,
        campaign_name,
        impressions,
        clicks,
        spend_amount,
        currency,
        _loaded_at

    from source

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
from renamed
