-- Fixture test: cross-device events (same user_id, different anon_ids).
-- Validates that 3 events for the same user across 2 devices all have unique event_ids
-- and all survive deduplication. Multi-device is valid data, not a dedup target.
-- Expects 0 rows: all 3 distinct event_ids are retained.

{{ config(
    severity='error',
    tags=['fixture', 'data_quality'],
    description='Assert cross-device events with distinct event_ids all survive deduplication in fixture_events_multi_device'
) }}

with deduped as (
    select
        event_id,
        {{ dedup_events_row_number() }} as _dedup_row_num
    from {{ ref('fixture_events_multi_device') }}
),

retained as (
    select event_id
    from deduped
    where _dedup_row_num = 1
)

select
    'missing_events' as check_name,
    3 as expected_count,
    count(*) as actual_count
from retained
having count(*) != 3
