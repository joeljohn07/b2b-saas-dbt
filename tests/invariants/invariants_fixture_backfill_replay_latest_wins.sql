-- Fixture test: replayed event (same event_id, later _loaded_at).
-- Validates that after deduplication, the row with the earliest _loaded_at is retained
-- (dedup orders by _loaded_at asc — first-seen wins, replay is discarded).
-- Expects 0 rows: exactly 1 row for evt_replay_001 after dedup.

{{ config(
    severity='error',
    tags=['fixture', 'data_quality'],
    description='Assert replayed event_id is deduplicated to exactly one row in fixture_events_backfill_replay'
) }}

with deduped as (
    select
        event_id,
        _loaded_at,
        row_number() over (
            partition by event_id
            order by _loaded_at asc, ingest_time asc
        ) as _dedup_row_num
    from {{ ref('fixture_events_backfill_replay') }}
)

select
    event_id,
    count(*) as count_after_dedup
from deduped
where _dedup_row_num = 1
group by event_id
having count(*) > 1
