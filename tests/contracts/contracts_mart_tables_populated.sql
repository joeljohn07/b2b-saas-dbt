-- Validates all mart tables are built and have at least one row.
-- This is a CI-only smoke test confirming that contract.enforced: true was applied and
-- all 17 mart models were successfully built in the target environment.
--
-- Will fail on a fresh dev schema before dbt build — run with:
--   dbt test --select contracts_mart_tables_populated --target ci

{{ config(
    severity='error',
    tags=['data_quality'],
    description='Assert all mart tables are built and populated — CI-only smoke test for contract enforcement'
) }}

with mart_counts as (
    select 'fct_sessions'             as model_name, count(*) as row_count from {{ ref('fct_sessions') }}
    union all
    select 'fct_signups',             count(*) from {{ ref('fct_signups') }}
    union all
    select 'fct_activations',         count(*) from {{ ref('fct_activations') }}
    union all
    select 'fct_feature_usage',       count(*) from {{ ref('fct_feature_usage') }}
    union all
    select 'fct_experiment_exposures',count(*) from {{ ref('fct_experiment_exposures') }}
    union all
    select 'fct_mrr_movements',       count(*) from {{ ref('fct_mrr_movements') }}
    union all
    select 'fct_subscriptions',       count(*) from {{ ref('fct_subscriptions') }}
    union all
    select 'fct_invoices',            count(*) from {{ ref('fct_invoices') }}
    union all
    select 'fct_retention_cohorts',   count(*) from {{ ref('fct_retention_cohorts') }}
    union all
    select 'fct_marketing_spend',     count(*) from {{ ref('fct_marketing_spend') }}
    union all
    select 'fct_support_tickets',     count(*) from {{ ref('fct_support_tickets') }}
    union all
    select 'dim_users',               count(*) from {{ ref('dim_users') }}
    union all
    select 'dim_accounts',            count(*) from {{ ref('dim_accounts') }}
    union all
    select 'dim_sessions',            count(*) from {{ ref('dim_sessions') }}
    union all
    select 'dim_channels',            count(*) from {{ ref('dim_channels') }}
    union all
    select 'dim_experiments',         count(*) from {{ ref('dim_experiments') }}
    union all
    select 'bridge_user_experiments', count(*) from {{ ref('bridge_user_experiments') }}
)

select model_name, row_count
from mart_counts
where row_count = 0
