-- Fixture test: late-arriving duplicate (same event_id, _loaded_at 48h apart).
-- Applies the canonical dedup expression from the dedup_events_row_number
-- macro (also used by int_events_normalized) so this test stays in sync
-- with the real model's partition/order when the dedup logic evolves.
-- Expects 0 rows: no event_id should have more than 1 row after deduplication.

{{ config(
    severity='error',
    tags=['fixture', 'data_quality'],
    description='Assert dedup logic eliminates late-arriving duplicate event_ids in fixture_events_late_arrivals'
) }}

with deduped as (
    select
        event_id,
        {{ dedup_events_row_number() }} as _dedup_row_num
    from {{ ref('fixture_events_late_arrivals') }}
)

select
    event_id,
    count(*) as count_after_dedup
from deduped
where _dedup_row_num = 1
group by event_id
having count(*) > 1
