select
    farm_fingerprint(invoice_id) as invoice_key,
    invoice_id,
    subscription_id,
    user_id,
    farm_fingerprint(user_id) as user_key,
    account_id,
    farm_fingerprint(account_id) as account_key,
    cast(format_date('%Y%m%d', date(issued_at)) as int64) as issued_date_key,
    issued_at,
    paid_at,
    amount,
    currency,
    status,
    refund_amount,
    net_amount,
    is_paid
from {{ ref('int_invoices_prep') }}
