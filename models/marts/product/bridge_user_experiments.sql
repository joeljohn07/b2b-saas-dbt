select
    user_id,
    farm_fingerprint(experiment_id) as experiment_key,
    variant,
    first_exposure_at,
from {{ ref('int_experiment_results') }}
