-- Validates no duplicate event_id exists after deduplication in int_events_normalized.
-- The model deduplicates using row_number() over (partition by event_id order by _loaded_at asc,
-- ingest_time asc) = 1. This test verifies that dedup logic produced no residual duplicates.

{{ config(
    severity='error',
    tags=['data_quality'],
    description='Assert int_events_normalized has no duplicate event_id after deduplication'
) }}

select
    event_id,
    count(*) as duplicate_count
from {{ ref('int_events_normalized') }}
group by event_id
having count(*) > 1
