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
- Column naming consistency: columns referring to the same business concept must use identical names across all staging models
- No inline descriptions — all descriptions must use `{{ doc() }}` blocks

## What Belongs Here
- Column renaming and type casting
- JSON shredding (properties → flat columns, experiment_flags passed through as JSON string for downstream unnesting)
- Exception: `line_items` on invoices is passed through as raw JSON — not shredded at any layer (variable-length structure consumed directly by downstream tools)
- Null handling for optional fields

## What Does Not Belong Here
- Joins, aggregations, window functions, derived columns
- Business logic or derived metrics
- References to other models

## Directory Organization
Models organized by source system: funnel/, billing/, marketing/, support/
Each subdirectory contains `_sources.yml` (source declarations) and `_models.yml` (schema definitions).
