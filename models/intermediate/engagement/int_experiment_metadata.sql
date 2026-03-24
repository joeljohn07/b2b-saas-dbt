select
    experiment_id,
    experiment_name,
    status,
    start_date,
    end_date,
    description
from {{ ref('experiment_metadata') }}
