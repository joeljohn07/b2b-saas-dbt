select
    user_id,
    farm_fingerprint(user_id) as user_key,
    experiment_id,
    farm_fingerprint(experiment_id) as experiment_key,
    variant,
    first_exposure_at,
    cast(format_date('%Y%m%d', date(first_exposure_at)) as int64) as exposure_date_key,
    converted,
    conversion_at,
    exposure_duration_hours
from {{ ref('int_experiment_results') }}
