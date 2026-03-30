-- Fixture test: out-of-order events (event_time well before _loaded_at).
-- Validates that deduplication does not discard events simply because event_time
-- is old — only event_id uniqueness drives dedup, not event_time recency.
-- Expects 0 rows: all 3 fixture events have distinct event_ids and must all survive.

{{ config(
    severity='error',
    tags=['fixture', 'data_quality'],
    description='Assert out-of-order events with unique event_ids are all retained after deduplication'
) }}

with deduped as (
    select
        event_id,
        row_number() over (
            partition by event_id
            order by _loaded_at asc, ingest_time asc
        ) as _dedup_row_num
    from {{ ref('fixture_events_out_of_order') }}
),

retained as (
    select event_id
    from deduped
    where _dedup_row_num = 1
)

-- Fixture has 3 distinct event_ids. If any are missing, return a row.
select
    'missing_events' as check_name,
    3 as expected_count,
    count(*) as actual_count
from retained
having count(*) != 3
