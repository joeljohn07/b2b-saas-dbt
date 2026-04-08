-- Assert days_since_last_activity is non-negative when last_activity_at
-- falls within the snapshot week. A negative value indicates the
-- date_diff anchor is snapshot_week_start (Monday) rather than
-- snapshot_week_end (Sunday), producing negative deltas for mid-week
-- and late-week activity.

{{ config(
    severity='error',
    tags=['data_quality'],
    description='Assert days_since_last_activity is non-negative — detects week-start vs week-end anchoring mismatch'
) }}

select
    user_id,
    snapshot_week_start,
    days_since_last_activity,
    last_activity_at
from {{ ref('int_engagement_states') }}
where
    last_activity_at is not null
    and days_since_last_activity < 0
