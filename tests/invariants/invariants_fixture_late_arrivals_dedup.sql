-- Fixture test: late-arriving duplicate (same event_id, _loaded_at 48h apart).
-- Applies the dedup logic from int_events_normalized inline.
-- Expects 0 rows: no event_id should have more than 1 row after deduplication.

{{ config(
    severity='error',
    tags=['fixture', 'data_quality'],
    description='Assert dedup logic eliminates late-arriving duplicate event_ids in fixture_events_late_arrivals'
) }}

with deduped as (
    select
        event_id,
        row_number() over (
            partition by event_id
            order by _loaded_at asc, ingest_time asc
        ) as _dedup_row_num
    from {{ ref('fixture_events_late_arrivals') }}
)

select
    event_id,
    count(*) as count_after_dedup
from deduped
where _dedup_row_num = 1
group by event_id
having count(*) > 1
