-- Assert that experiment results include at least one conversion.
-- If zero users convert, the exposure/activation join likely filters
-- out activation events (e.g. via an experiment_flags is not null
-- predicate that excludes activations without flag payloads).

-- severity=warn because small or fixture-only datasets may legitimately
-- have zero conversions; the test is a canary, not a hard gate.
{{ config(
    severity='warn',
    tags=['data_quality'],
    description='Assert at least one experiment conversion exists — detects activation filter regression'
) }}

with stats as (

    select countif(converted) as converted_count
    from {{ ref('int_experiment_results') }}

)

select converted_count
from stats
where converted_count = 0
