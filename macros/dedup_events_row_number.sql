{% macro dedup_events_row_number() -%}
    row_number() over (
        partition by event_id
        order by _loaded_at asc, ingest_time asc
    )
{%- endmacro %}
