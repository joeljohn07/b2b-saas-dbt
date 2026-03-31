-- Fixture test: session boundary at the 1800-second inactivity threshold.
-- anon_008: two events exactly 1800s apart — same session (gap does not exceed threshold).
-- anon_009: two events 1801s apart — two sessions (gap exceeds threshold).
-- Applies session start detection inline using the 1800s boundary rule.
-- Expects 0 rows: any anon_id where session count differs from expected returns a row.

{{ config(
    severity='error',
    tags=['fixture', 'data_quality'],
    description='Assert 1800s session boundary produces 1 session for anon_008 and 2 sessions for anon_009'
) }}

with events as (
    select * from {{ ref('fixture_events_session_boundary') }}
),

session_flags as (
    select
        anon_id,
        event_id,
        event_time,
        case
            when lag(event_time) over (
                partition by anon_id order by event_time
            ) is null then 1
            when timestamp_diff(
                event_time,
                lag(event_time) over (partition by anon_id order by event_time),
                second
            ) > 1800 then 1
            else 0
        end as is_session_start
    from events
),

session_counts as (
    select
        anon_id,
        sum(is_session_start) as session_count
    from session_flags
    group by anon_id
)

select anon_id, session_count
from session_counts
where
    (anon_id = 'anon_008' and session_count != 1)
    or (anon_id = 'anon_009' and session_count != 2)
