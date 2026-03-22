with lifecycle as (

    select
        account_id,
        subscription_event_id,
        subscription_id,
        event_type,
        event_time,
        mrr_amount,
        lag(mrr_amount) over (
            partition by account_id
            order by event_time
        ) as previous_mrr,
        lag(event_type) over (
            partition by account_id
            order by event_time
        ) as previous_event_type
    from {{ ref('int_subscription_lifecycle') }}

),

movements as (

    select
        account_id,
        subscription_event_id,
        subscription_id,
        event_type,
        date(event_time) as movement_date,
        case
            when
                previous_mrr is null
                and event_type = 'subscription_start'
                then 'new'
            when event_type = 'reactivation'
                then 'reactivation'
            when event_type = 'cancellation'
                then 'churn'
            when
                mrr_amount
                > coalesce(previous_mrr, 0)
                then 'expansion'
            when
                mrr_amount
                < coalesce(previous_mrr, 0)
                and mrr_amount > 0
                then 'contraction'
        end as movement_type,
        coalesce(previous_mrr, 0) as mrr_before,
        mrr_amount as mrr_after,
        mrr_amount - coalesce(previous_mrr, 0) as mrr_delta
    from lifecycle
    where event_type not in ('trial_start', 'trial_end')

)

select
    account_id,
    subscription_event_id,
    subscription_id,
    movement_date,
    movement_type,
    mrr_before,
    mrr_after,
    mrr_delta
from movements
where movement_type is not null
