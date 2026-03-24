with channels as (
    select distinct first_touch_channel as channel
    from {{ ref('int_attribution') }}

    union distinct

    select distinct last_touch_channel
    from {{ ref('int_attribution') }}

    union distinct

    select distinct channel
    from {{ ref('int_marketing_spend_prep') }}
)

select
    farm_fingerprint(channel) as channel_key,
    channel
from channels
where channel is not null
