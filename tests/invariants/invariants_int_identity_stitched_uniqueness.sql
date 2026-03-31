-- Validates no two rows in int_identity_stitched share the same (anon_id, valid_from).
-- This is the composite primary key of the identity stitching model.
-- Complements invariants_int_identity_stitched_no_overlapping_intervals (which checks time range
-- overlap) and invariants_int_identity_stitched_deterministic_ordering (which checks last_touch
-- cardinality). Together the three tests fully constrain the identity model output.

{{ config(
    severity='error',
    tags=['data_quality'],
    description='Assert (anon_id, valid_from) is unique in int_identity_stitched'
) }}

select
    anon_id,
    valid_from,
    count(*) as duplicate_count
from {{ ref('int_identity_stitched') }}
group by anon_id, valid_from
having count(*) > 1
