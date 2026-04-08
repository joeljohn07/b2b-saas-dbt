-- Assert mrr_delta = mrr_after - mrr_before for every MRR movement row.
-- A mismatch indicates broken delta arithmetic in int_mrr_movements.

{{ config(
    severity='error',
    tags=['data_quality'],
    description='Assert mrr_delta equals mrr_after minus mrr_before for every movement row'
) }}

select
    mrr_movement_key,
    mrr_before,
    mrr_after,
    mrr_delta,
    mrr_after - mrr_before as expected_delta
from {{ ref('fct_mrr_movements') }}
where abs(mrr_delta - (mrr_after - mrr_before)) > 0.01
