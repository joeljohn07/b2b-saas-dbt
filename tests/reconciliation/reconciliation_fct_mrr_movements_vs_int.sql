-- Validates sum(mrr_delta) per account is consistent between int_mrr_movements and fct_mrr_movements.
-- Tests that mart assembly did not alter, drop, or duplicate any MRR delta values.
-- Tolerance: 0.01, matching the precision used in reconciliation_int_mrr_movements_net_mrr.sql.
--
-- A full outer join surfaces three failure modes:
--   1. account_id in intermediate but missing from mart (dropped in assembly)
--   2. account_id in mart but missing from intermediate (introduced in assembly)
--   3. sum(mrr_delta) differs by more than tolerance (value altered in assembly)

{{ config(
    severity='error',
    tags=['data_quality'],
    description='Assert mrr_delta totals per account are consistent between int_mrr_movements and fct_mrr_movements'
) }}

with intermediate_totals as (
    select
        account_id,
        sum(mrr_delta)  as total_mrr_delta_int
    from {{ ref('int_mrr_movements') }}
    group by account_id
),

mart_totals as (
    select
        account_id,
        sum(mrr_delta)  as total_mrr_delta_mart
    from {{ ref('fct_mrr_movements') }}
    group by account_id
)

select
    coalesce(i.account_id, m.account_id)    as account_id,
    i.total_mrr_delta_int,
    m.total_mrr_delta_mart
from intermediate_totals i
full outer join mart_totals m
    on i.account_id = m.account_id
where
    i.account_id is null
    or m.account_id is null
    or abs(i.total_mrr_delta_int - m.total_mrr_delta_mart) > 0.01
