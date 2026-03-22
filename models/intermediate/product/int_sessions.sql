with events as (

    select
        event_id,
        anon_id,
        event_time,
        event_type,
        platform,
        device_type,
        browser,
        utm_source,
        utm_medium,
        utm_campaign,
        lag(event_time) over (
            partition by anon_id
            order by event_time
        ) as prev_event_time
    from {{ ref('int_events_normalized') }}

),

session_boundaries as (

    select
        event_id,
        anon_id,
        event_time,
        event_type,
        platform,
        device_type,
        browser,
        utm_source,
        utm_medium,
        utm_campaign,
        sum(
            case
                when prev_event_time is null
                    then 1
                when
                    timestamp_diff(
                        event_time, prev_event_time, minute
                    ) > 30
                    then 1
                else 0
            end
        ) over (
            partition by anon_id
            order by event_time
            rows unbounded preceding
        ) as session_seq
    from events

),

first_event_per_session as (

    select
        anon_id,
        session_seq,
        event_id as first_event_id,
        utm_source,
        utm_medium,
        utm_campaign,
        platform,
        device_type,
        browser
    from session_boundaries
    qualify row_number() over (
        partition by anon_id, session_seq
        order by event_time asc
    ) = 1

),

session_agg as (

    select
        anon_id,
        session_seq,
        min(event_time) as session_start_at,
        max(event_time) as session_end_at,
        timestamp_diff(
            max(event_time), min(event_time), second
        ) as session_duration_seconds,
        count(*) as event_count,
        countif(event_type = 'page_view') as page_view_count,
        date(min(event_time)) as session_date
    from session_boundaries
    group by all

),

sessions_enriched as (

    select
        to_hex(md5(concat(
            a.anon_id,
            f.first_event_id
        ))) as session_id,
        a.anon_id,
        a.session_start_at,
        a.session_end_at,
        a.session_duration_seconds,
        a.event_count,
        a.page_view_count,
        f.utm_source,
        f.utm_medium,
        f.utm_campaign,
        f.platform,
        f.device_type,
        f.browser,
        a.session_date
    from session_agg as a
    inner join first_event_per_session as f
        on
            a.anon_id = f.anon_id
            and a.session_seq = f.session_seq

),

with_identity as (

    select
        s.session_id,
        s.anon_id,
        i.user_id as stitched_user_id,
        s.session_start_at,
        s.session_end_at,
        s.session_duration_seconds,
        s.event_count,
        s.page_view_count,
        s.utm_source,
        s.utm_medium,
        s.utm_campaign,
        s.platform,
        s.device_type,
        s.browser,
        s.session_date
    from sessions_enriched as s
    left join {{ ref('int_identity_stitched') }} as i
        on
            s.anon_id = i.anon_id
            and s.session_start_at >= i.valid_from
            and s.session_start_at < coalesce(
                i.valid_to, timestamp('9999-12-31')
            )

)

select
    session_id,
    anon_id,
    stitched_user_id,
    session_start_at,
    session_end_at,
    session_duration_seconds,
    event_count,
    page_view_count,
    utm_source,
    utm_medium,
    utm_campaign,
    platform,
    device_type,
    browser,
    session_date
from with_identity
