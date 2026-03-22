with source as (

    select * from {{ source('raw_funnel', 'events') }}

),

renamed as (

    select
        -- identifiers
        event_id,
        user_id,
        anon_id,
        account_id,

        -- timestamps
        event_time,
        ingest_time,
        _loaded_at,
        event_date,

        -- event classification
        event_type,
        platform,
        channel,
        plan_context,

        -- utm
        utm_source,
        utm_medium,
        utm_campaign,
        utm_term,
        utm_content,

        -- device
        device_type,
        browser,
        os,
        user_agent,

        -- properties json shred (conditional on event_type, null otherwise)
        json_value(properties, '$.page_url') as page_url,
        json_value(properties, '$.referrer') as referrer,
        json_value(properties, '$.signup_method') as signup_method,
        json_value(properties, '$.activation_action') as activation_action,
        safe_cast(
            json_value(properties, '$.time_to_activate_hours') as float64
        ) as time_to_activate_hours,
        json_value(properties, '$.feature_name') as feature_name,
        safe_cast(
            json_value(properties, '$.duration_seconds') as int64
        ) as feature_duration_seconds,
        json_value(properties, '$.source_page') as source_page,
        json_value(properties, '$.target_plan') as target_plan,
        json_value(properties, '$.billing_cycle') as billing_cycle,
        json_value(properties, '$.role') as member_role,
        json_value(properties, '$.reason') as member_reason,

        -- experiment flags (json string, pass through for downstream unnesting)
        experiment_flags

    from source

)

select * from renamed
