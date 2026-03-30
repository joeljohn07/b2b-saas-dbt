-- Validates net_amount = amount - refund_amount.
-- Computed in int_invoices_prep and passed through to fct_invoices.

{{ config(
    severity='error',
    tags=['data_quality'],
    description='Assert net_amount equals amount minus refund_amount in fct_invoices'
) }}

select
    invoice_id,
    amount,
    refund_amount,
    net_amount,
    amount - refund_amount as expected_net_amount
from {{ ref('fct_invoices') }}
where amount - refund_amount != net_amount
