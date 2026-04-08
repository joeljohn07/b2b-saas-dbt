-- Assert refunded invoices have a positive refund_amount.
-- A refunded invoice with refund_amount = 0 indicates the status
-- was set without recording the refund, or the amount was lost.

{{ config(
    severity='error',
    tags=['data_quality'],
    description='Assert status=refunded implies refund_amount > 0'
) }}

select
    invoice_key,
    status,
    refund_amount
from {{ ref('fct_invoices') }}
where
    status = 'refunded'
    and (refund_amount is null or refund_amount <= 0)
