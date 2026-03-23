with source as (

    select
        invoice_id,
        subscription_id,
        user_id,
        account_id,
        issued_at,
        paid_at,
        _loaded_at,
        amount,
        currency,
        status,
        refund_amount,
        line_items
    from {{ ref('stg_billing__invoices') }}

),

enriched as (

    select
        invoice_id,
        subscription_id,
        user_id,
        account_id,
        issued_at,
        paid_at,
        _loaded_at,
        amount,
        currency,
        status,
        refund_amount,
        line_items,
        status = 'paid' as is_paid,
        amount - refund_amount as net_amount
    from source

)

select
    invoice_id,
    subscription_id,
    user_id,
    account_id,
    issued_at,
    paid_at,
    _loaded_at,
    amount,
    currency,
    status,
    refund_amount,
    line_items,
    is_paid,
    net_amount
from enriched
