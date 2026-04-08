select
    farm_fingerprint(
        concat(user_id, '|', cast(date(activation_at) as string))
    ) as activation_key,
    user_id,
    farm_fingerprint(user_id) as user_key,
    cast(format_date('%Y%m%d', date(activation_at)) as int64) as activation_date_key,
    activation_at,
    farm_fingerprint(first_touch_channel) as first_touch_channel_key,
    farm_fingerprint(last_touch_channel) as last_touch_channel_key,
    first_touch_channel,
    last_touch_channel
from {{ ref('int_attribution') }}
