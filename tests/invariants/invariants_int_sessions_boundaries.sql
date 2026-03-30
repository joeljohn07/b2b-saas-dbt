-- Validates internal session boundary consistency in int_sessions.
-- Checks: session_end_at >= session_start_at, duration >= 0, and the duration formula
-- matches the timestamp difference within 1-second tolerance (for timestamp_diff precision).
--
-- Distinct from invariants_int_sessions_no_overlap.sql which checks inter-session time overlap.
-- This test is scoped entirely to the sessions model — no join to events required.

{{ config(
    severity='error',
    tags=['data_quality'],
    description='Assert session boundaries are internally consistent in int_sessions'
) }}

select
    session_id,
    session_start_at,
    session_end_at,
    session_duration_seconds
from {{ ref('int_sessions') }}
where
    session_end_at < session_start_at
    or session_duration_seconds < 0
    or abs(
        session_duration_seconds
        - timestamp_diff(session_end_at, session_start_at, second)
    ) > 1
