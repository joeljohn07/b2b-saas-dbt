-- TODO: convert to incremental materialization (issue #21)
{{ config(materialized='view') }}

with source as (

    select
        event_id,
        user_id,
        anon_id,
        account_id,
        event_time,
        ingest_time,
        _loaded_at,
        event_date,
        event_type,
        platform,
        channel,
        plan_context,
        utm_source,
        utm_medium,
        utm_campaign,
        utm_term,
        utm_content,
        device_type,
        browser,
        os,
        user_agent,
        page_url,
        referrer,
        signup_method,
        activation_action,
        time_to_activate_hours,
        feature_name,
        feature_duration_seconds,
        source_page,
        target_plan,
        billing_cycle,
        member_role,
        member_reason,
        experiment_flags,
        row_number() over (
            partition by event_id
            order by _loaded_at asc, ingest_time asc
        ) as _dedup_row_num
    from {{ ref('stg_funnel__events') }}

)

select
    event_id,
    user_id,
    anon_id,
    account_id,
    event_time,
    ingest_time,
    _loaded_at,
    event_date,
    event_type,
    platform,
    channel,
    plan_context,
    utm_source,
    utm_medium,
    utm_campaign,
    utm_term,
    utm_content,
    device_type,
    browser,
    os,
    user_agent,
    page_url,
    referrer,
    signup_method,
    activation_action,
    time_to_activate_hours,
    feature_name,
    feature_duration_seconds,
    source_page,
    target_plan,
    billing_cycle,
    member_role,
    member_reason,
    experiment_flags
from source
where _dedup_row_num = 1
