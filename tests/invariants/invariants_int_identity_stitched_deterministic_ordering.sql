-- Validates that identity stitching produces deterministic results.
-- Each anon_id must have exactly one 'last_touch' row, which depends on
-- row_number() having a consistent tie-breaker in its ordering clause.

{{ config(
    severity='error',
    tags=['operations_alert'],
    description='Each anon_id must have exactly one last_touch — non-deterministic ordering causes duplicates'
) }}

select
    anon_id,
    count(*) as last_touch_count
from {{ ref('int_identity_stitched') }}
where stitch_source = 'last_touch'
group by all
having count(*) != 1
