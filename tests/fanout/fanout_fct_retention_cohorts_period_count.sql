-- Fail if any cohort_week_start_date has a row count other than 8.
-- The cross join in fct_retention_cohorts is intentional and must produce
-- exactly 8 period rows per cohort week. Uses count(*) not count(distinct)
-- to catch duplicate rows as well as missing periods.

{{ config(
    severity='error',
    tags=['data_quality'],
    description='Each cohort_week_start_date must have exactly 8 retention period rows'
) }}

select
    cohort_week_start_date,
    count(*) as row_count
from {{ ref('fct_retention_cohorts') }}
group by all
having count(*) != 8
