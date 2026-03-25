-- Validates that cohort_week_start_date is always a Monday (ISO week start).

{{ config(
    severity='error',
    tags=['data_quality'],
    description='cohort_week_start_date must always be a Monday'
) }}

select
    cohort_week_start_date,
    retention_period
from {{ ref('fct_retention_cohorts') }}
where extract(dayofweek from cohort_week_start_date) != 2
