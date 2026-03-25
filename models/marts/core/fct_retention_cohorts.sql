with activated_users as (

    select
        user_id,
        activation_at,
        date_trunc(date(activation_at), isoweek) as cohort_week_start_date
    from {{ ref('int_attribution') }}

),

retention_periods as (

    select
        retention_period,
        period_offset_days
    from
        unnest([
            struct('W1' as retention_period, 7 as period_offset_days),
            struct('W2', 14),
            struct('W3', 21),
            struct('W4', 28),
            struct('M2', 60),
            struct('M3', 91),
            struct('M6', 182),
            struct('M12', 365)
        ])

),

user_periods as (

    select
        au.user_id,
        au.cohort_week_start_date,
        rp.retention_period,
        rp.period_offset_days,
        date_add(
            au.cohort_week_start_date,
            interval rp.period_offset_days day
        ) as period_start_date,
        date_add(
            au.cohort_week_start_date,
            interval rp.period_offset_days + 6 day
        ) as period_end_date
    from activated_users as au
    cross join retention_periods as rp

),

user_activity as (

    select distinct
        coalesce(e.user_id, i.user_id) as resolved_user_id,
        date(e.event_time) as activity_date
    from {{ ref('int_events_normalized') }} as e
    left join {{ ref('int_identity_stitched') }} as i
        on
            e.anon_id = i.anon_id
            and e.event_time >= i.valid_from
            and e.event_time < coalesce(
                i.valid_to, timestamp('9999-12-31')
            )
    where
        coalesce(e.user_id, i.user_id) is not null
        and coalesce(e.user_id, i.user_id) in (
            select activated_users.user_id from activated_users
        )

),

retention_measured as (

    select
        up.cohort_week_start_date,
        up.retention_period,
        up.period_offset_days,
        up.period_end_date,
        count(distinct up.user_id) as cohort_size,
        count(distinct case
            when ua.activity_date is not null then up.user_id
        end) as retained_count
    from user_periods as up
    left join user_activity as ua
        on
            up.user_id = ua.resolved_user_id
            and ua.activity_date
            between up.period_start_date and up.period_end_date
    group by all

)

select
    farm_fingerprint(
        concat(
            cast(cohort_week_start_date as string),
            '|',
            retention_period
        )
    ) as retention_cohort_key,
    cohort_week_start_date,
    cast(
        format_date('%Y%m%d', cohort_week_start_date) as int64
    ) as cohort_week_date_key,
    retention_period,
    period_offset_days,
    period_end_date,
    cast(
        format_date('%Y%m%d', period_end_date) as int64
    ) as period_end_date_key,
    cohort_size,
    retained_count,
    safe_divide(retained_count, cohort_size) as retention_rate,
    date_add(period_end_date, interval 7 day) <= current_date()
        as is_period_complete
from retention_measured
