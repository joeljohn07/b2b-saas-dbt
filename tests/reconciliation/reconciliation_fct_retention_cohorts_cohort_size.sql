-- Validates that cohort_size in fct_retention_cohorts matches the count of
-- activated users per week in int_attribution.

{{ config(
    severity='error',
    tags=['data_quality'],
    description='cohort_size must equal count of activated users per cohort week in int_attribution'
) }}

with attribution_counts as (

    select
        date_trunc(date(activation_at), isoweek) as cohort_week_start_date,
        count(*) as expected_cohort_size
    from {{ ref('int_attribution') }}
    group by all

),

retention_counts as (

    select distinct
        cohort_week_start_date,
        cohort_size
    from {{ ref('fct_retention_cohorts') }}

)

select
    coalesce(a.cohort_week_start_date, r.cohort_week_start_date)
        as cohort_week_start_date,
    a.expected_cohort_size,
    r.cohort_size as actual_cohort_size
from attribution_counts as a
full outer join retention_counts as r
    on a.cohort_week_start_date = r.cohort_week_start_date
where
    a.expected_cohort_size != r.cohort_size
    or a.expected_cohort_size is null
    or r.cohort_size is null
