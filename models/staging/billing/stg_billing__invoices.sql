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
    from {{ source('billing', 'invoices') }}

),

renamed as (

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
    line_items
from renamed
