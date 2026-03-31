-- Fixture test: replayed event (same event_id, later _loaded_at).
-- Verifies dedup retains the earliest _loaded_at row (first-seen wins, replay discarded).
-- Returns rows where the wrong row was kept (i.e. kept _loaded_at != min _loaded_at).

{{ config(
    severity='error',
    tags=['fixture', 'data_quality'],
    description='Assert dedup retains the earliest _loaded_at row when an event is replayed'
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

),

kept as (

    select event_id, _loaded_at
    from deduped
    where _dedup_row_num = 1

),

expected as (

    select event_id, min(_loaded_at) as earliest_loaded_at
    from {{ ref('fixture_events_backfill_replay') }}
    group by event_id

)

select
    kept.event_id,
    kept._loaded_at     as kept_loaded_at,
    expected.earliest_loaded_at
from kept
inner join expected using (event_id)
where kept._loaded_at != expected.earliest_loaded_at
