select
    farm_fingerprint(experiment_id) as experiment_key,
    experiment_id,
    experiment_name,
    status,
    start_date,
    end_date,
    description
from {{ ref('int_experiment_metadata') }}
