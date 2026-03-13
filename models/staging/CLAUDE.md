# Staging Layer

## Purpose
1:1 shaping of raw sources. No business logic. No joins.

## Conventions
- Materialized: view
- Naming: `stg_{source}__{entity}` (double underscore separates source from entity)
- Only `source()` references — never `ref()`
- `contract.enforced: true` on all staging models
- Shred JSON fields to flat columns (e.g., properties → typed columns)
- Cast to canonical types (TIMESTAMP, DATE, STRING, INT64, NUMERIC)
- Rename source columns to snake_case, no abbreviations

## What Belongs Here
- Column renaming and type casting
- JSON shredding (properties, line_items, experiment_flags)
- Null handling for optional fields

## What Does Not Belong Here
- Joins, aggregations, window functions, derived columns
- Business logic or derived metrics
- References to other models
