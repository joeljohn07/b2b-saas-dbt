with resolved_events as (

    select
        coalesce(e.user_id, i.user_id) as resolved_user_id,
        e.event_time,
        e.event_type,
        e.experiment_flags
    from {{ ref('int_events_normalized') }} as e
    left join {{ ref('int_identity_stitched') }} as i
        on
            e.anon_id = i.anon_id
            and e.event_time >= i.valid_from
            and e.event_time < coalesce(
                i.valid_to, timestamp('9999-12-31')
            )
    where coalesce(e.user_id, i.user_id) is not null

),

unnested as (

    select
        e.resolved_user_id,
        e.event_time,
        e.event_type,
        json_extract_scalar(flag, '$.experiment_id') as experiment_id,
        json_extract_scalar(flag, '$.variant') as variant
    from resolved_events as e
    cross join
        unnest(
            json_extract_array(e.experiment_flags, '$')
        ) as flag
    where e.experiment_flags is not null

),

first_exposure as (

    select
        resolved_user_id,
        experiment_id,
        variant,
        min(event_time) as first_exposure_at,
        max(event_time) as last_exposure_at
    from unnested
    group by all

),

conversions as (

    select
        f.resolved_user_id,
        f.experiment_id,
        min(e.event_time) as conversion_at
    from first_exposure as f
    inner join resolved_events as e
        on
            f.resolved_user_id = e.resolved_user_id
            and e.event_type = 'activation'
            and f.first_exposure_at < e.event_time
    group by all

),

results as (

    select
        f.resolved_user_id as user_id,
        f.experiment_id,
        f.variant,
        f.first_exposure_at,
        c.conversion_at is not null as converted,
        c.conversion_at,
        timestamp_diff(
            f.last_exposure_at, f.first_exposure_at, hour
        ) as exposure_duration_hours
    from first_exposure as f
    left join conversions as c
        on
            f.resolved_user_id = c.resolved_user_id
            and f.experiment_id = c.experiment_id

)

select
    user_id,
    experiment_id,
    variant,
    first_exposure_at,
    converted,
    conversion_at,
    exposure_duration_hours
from results
where exposure_duration_hours >= 24
