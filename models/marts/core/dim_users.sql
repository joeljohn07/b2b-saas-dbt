with latest_engagement as (
    select
        user_id,
        engagement_state,
        is_re_engaged,
    from {{ ref('int_engagement_states') }}
    qualify row_number() over (partition by user_id order by snapshot_week_start desc) = 1
),

current_membership as (
    select
        user_id,
        account_id,
        role,
    from {{ ref('int_account_memberships') }}
    where valid_to is null
    qualify row_number() over (
        partition by user_id order by valid_from desc, account_id
    ) = 1
),

attribution as (
    select
        user_id,
        first_touch_channel,
        last_touch_channel,
        activation_at,
    from {{ ref('int_attribution') }}
),

signups as (
    select
        user_id,
        min(event_time) as signup_at,
    from {{ ref('int_events_normalized') }}
    where event_type = 'signup'
        and user_id is not null
    group by all
),

users as (
    select distinct user_id
    from {{ ref('int_events_normalized') }}
    where user_id is not null
)

select
    farm_fingerprint(u.user_id) as user_key,
    u.user_id,
    cm.account_id,
    s.signup_at,
    a.activation_at,
    farm_fingerprint(a.first_touch_channel) as first_touch_channel_key,
    farm_fingerprint(a.last_touch_channel) as last_touch_channel_key,
    coalesce(e.engagement_state, 'pre_active') as engagement_state,
    coalesce(e.is_re_engaged, false) as is_re_engaged,
from users as u
left join signups as s on u.user_id = s.user_id
left join current_membership as cm on u.user_id = cm.user_id
left join attribution as a on u.user_id = a.user_id
left join latest_engagement as e on u.user_id = e.user_id
