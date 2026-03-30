-- Validates that stg_funnel__events has a minimum number of rows.
-- Catches silent truncation or data loss that schema tests cannot detect.
-- Threshold: 100 rows (synthetic dataset has ~5.9M rows in prod/ci).

{{ config(
    severity='error',
    tags=['data_quality'],
    description='Assert stg_funnel__events has at least 100 rows'
) }}

select count(*) as row_count
from {{ ref('stg_funnel__events') }}
having count(*) < 100
