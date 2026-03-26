-- Validates that no two memberships overlap for the same account_id + user_id.
-- Half-open intervals [valid_from, valid_to) must not have any temporal overlap.

{{ config(
    severity='error',
    tags=['operations_alert'],
    description='No two membership intervals may overlap for the same account_id + user_id'
) }}

with intervals as (

    select
        account_id,
        user_id,
        valid_from,
        coalesce(valid_to, timestamp('9999-12-31')) as valid_to
    from {{ ref('int_account_memberships') }}

)

select
    a.account_id,
    a.user_id,
    a.valid_from as a_valid_from,
    a.valid_to as a_valid_to,
    b.valid_from as b_valid_from,
    b.valid_to as b_valid_to
from intervals as a
inner join intervals as b
    on a.account_id = b.account_id
    and a.user_id = b.user_id
    and a.valid_from < b.valid_from
    and a.valid_to > b.valid_from
