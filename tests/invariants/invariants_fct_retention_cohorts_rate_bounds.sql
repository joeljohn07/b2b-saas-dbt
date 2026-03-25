-- Validates that retention_rate is [0, 1], retained_count <= cohort_size,
-- and cohort_size > 0.

{{ config(
    severity='error',
    tags=['data_quality'],
    description='retention_rate must be [0,1] and retained_count must be <= cohort_size'
) }}

select
    cohort_week_start_date,
    retention_period,
    cohort_size,
    retained_count,
    retention_rate
from {{ ref('fct_retention_cohorts') }}
where
    retention_rate < 0
    or retention_rate > 1
    or retained_count > cohort_size
    or retained_count < 0
    or cohort_size <= 0
