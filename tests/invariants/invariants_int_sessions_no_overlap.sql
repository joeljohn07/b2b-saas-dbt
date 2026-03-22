-- Validates that no two sessions overlap for the same anon_id.
-- Session time ranges [session_start_at, session_end_at] must not overlap.

{{ config(
    severity='error',
    tags=['operations_alert'],
    description='Validates that no two sessions overlap for the same anon_id.'
) }}

select
    a.anon_id,
    a.session_id as session_a,
    b.session_id as session_b,
    a.session_start_at as a_start,
    a.session_end_at as a_end,
    b.session_start_at as b_start,
    b.session_end_at as b_end
from {{ ref('int_sessions') }} as a
inner join {{ ref('int_sessions') }} as b
    on a.anon_id = b.anon_id
    and a.session_start_at < b.session_start_at
    and a.session_end_at > b.session_start_at
