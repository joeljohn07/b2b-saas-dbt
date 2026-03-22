-- Validates that no two identity stitch intervals overlap for the same anon_id.
-- Half-open intervals [valid_from, valid_to) must not have any temporal overlap.

{{ config(
    severity='error',
    tags=['operations_alert'],
    description='No two identity stitch intervals may overlap for the same anon_id'
) }}

with intervals as (

    select
        anon_id,
        valid_from,
        coalesce(valid_to, timestamp('9999-12-31')) as valid_to
    from {{ ref('int_identity_stitched') }}

)

select
    a.anon_id,
    a.valid_from as a_valid_from,
    a.valid_to as a_valid_to,
    b.valid_from as b_valid_from,
    b.valid_to as b_valid_to
from intervals as a
inner join intervals as b
    on a.anon_id = b.anon_id
    and a.valid_from < b.valid_from
    and a.valid_to > b.valid_from
