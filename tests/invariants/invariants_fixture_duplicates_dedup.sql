-- Fixture test: within-window duplicates (same event_id, two _loaded_at within 36h).
-- Applies the dedup logic from int_events_normalized inline.
-- Expects 0 rows: no event_id should have more than 1 row after deduplication.

{{ config(
    severity='error',
    tags=['fixture', 'data_quality'],
    description='Assert dedup logic resolves within-window duplicate event_ids in fixture_events_duplicates'
) }}

with deduped as (
    select
        event_id,
        row_number() over (
            partition by event_id
            order by _loaded_at asc, ingest_time asc
        ) as _dedup_row_num
    from {{ ref('fixture_events_duplicates') }}
)

select
    event_id,
    count(*) as count_after_dedup
from deduped
where _dedup_row_num = 1
group by event_id
having count(*) > 1
