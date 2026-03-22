-- Validates that all health scores and sub-scores are within [0, 100]
-- and that the weighted formula holds: health = 0.4*activity + 0.3*billing + 0.3*support.

{{ config(severity='error') }}

select
    account_id,
    health_score,
    activity_score,
    billing_score,
    support_score,
    abs(
        health_score
        - (0.4 * activity_score + 0.3 * billing_score + 0.3 * support_score)
    ) as formula_error
from {{ ref('int_account_health') }}
where
    health_score < 0
    or health_score > 100
    or activity_score < 0
    or activity_score > 100
    or billing_score < 0
    or billing_score > 100
    or support_score < 0
    or support_score > 100
    or abs(
        health_score
        - (0.4 * activity_score + 0.3 * billing_score + 0.3 * support_score)
    ) > 0.01
