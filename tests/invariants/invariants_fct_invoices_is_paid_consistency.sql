-- Validates is_paid is true iff status = 'paid'.
-- Catches logic drift between the boolean flag and the status enum.

{{ config(
    severity='error',
    tags=['data_quality'],
    description='Assert is_paid boolean is consistent with status = paid in fct_invoices'
) }}

select
    invoice_id,
    status,
    is_paid
from {{ ref('fct_invoices') }}
where (status = 'paid') != is_paid
