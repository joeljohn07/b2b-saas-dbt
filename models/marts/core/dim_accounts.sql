with accounts as (
    select distinct account_id
    from {{ ref('int_account_memberships') }}

    union distinct

    select distinct account_id
    from {{ ref('int_subscription_lifecycle') }}

    union distinct

    select distinct account_id
    from {{ ref('int_account_health') }}
),

current_sub as (
    select
        account_id,
        plan,
        billing_cycle,
        mrr_amount,
        currency,
        event_type,
        is_active
    from {{ ref('int_subscription_lifecycle') }}
    qualify row_number() over (partition by account_id order by event_time desc) = 1
),

health as (
    select
        account_id,
        health_score,
        activity_score,
        billing_score,
        support_score
    from {{ ref('int_account_health') }}
),

member_count as (
    select
        account_id,
        count(distinct user_id) as user_count
    from {{ ref('int_account_memberships') }}
    where valid_to is null
    group by all
),

account_acquisition as (
    select
        m.account_id,
        a.first_touch_channel,
        a.activation_at,
        row_number() over (
            partition by m.account_id
            order by a.activation_at asc, a.user_id asc
        ) as rn
    from {{ ref('int_account_memberships') }} as m
    inner join {{ ref('int_attribution') }} as a on m.user_id = a.user_id
)

select
    farm_fingerprint(acc.account_id) as account_key,
    acc.account_id,
    cs.plan,
    cs.billing_cycle,
    cs.mrr_amount,
    cs.currency,
    mc.user_count,
    h.health_score,
    h.activity_score,
    cast(h.billing_score as float64) as billing_score,
    cast(h.support_score as float64) as support_score,
    farm_fingerprint(aq.first_touch_channel) as acquisition_channel_key,
    date(aq.activation_at) as acquisition_date,
    case
        when cs.is_active and cs.event_type in ('subscription_start', 'renewal', 'upgrade', 'downgrade') then 'active'
        when cs.event_type = 'reactivation' then 'reactivated'
        when cs.event_type = 'cancellation' then 'churned'
        when cs.event_type = 'trial_start' then 'trial'
        else 'unknown'
    end as lifecycle_stage
from accounts as acc
left join current_sub as cs on acc.account_id = cs.account_id
left join health as h on acc.account_id = h.account_id
left join member_count as mc on acc.account_id = mc.account_id
left join account_acquisition as aq on acc.account_id = aq.account_id and aq.rn = 1
