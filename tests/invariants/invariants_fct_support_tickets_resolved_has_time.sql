-- Assert resolved tickets have a non-null resolution_time_hours.
-- A resolved ticket without resolution time indicates the resolved_at
-- timestamp was missing or the calculation was skipped.

{{ config(
    severity='error',
    tags=['data_quality'],
    description='Assert is_resolved=true implies resolution_time_hours is not null'
) }}

select
    ticket_key,
    is_resolved,
    resolution_time_hours
from {{ ref('fct_support_tickets') }}
where
    is_resolved
    and resolution_time_hours is null
