-- Assert is_paid = (status = 'paid') for all known statuses.
-- Refunded invoices must have is_paid = false even though they were
-- originally paid (option B: recognized revenue, not payment history).

{{ config(
    severity='error',
    tags=['data_quality'],
    description='Assert is_paid equals (status = paid) across all invoice statuses including refunded'
) }}

select
    invoice_id,
    status,
    is_paid
from {{ ref('int_invoices_prep') }}
where is_paid != (status = 'paid')
