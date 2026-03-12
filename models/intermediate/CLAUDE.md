# Intermediate Layer

## Purpose
All business logic lives here. Dedup, sessionization, identity stitching, attribution, lifecycle state machines, cross-domain joins.

## Conventions
- Materialized: view (default). Use table only if query is too heavy for downstream.
- Exception: `int_events_normalized` is incremental (merge on event_id, 36h lookback)
- Naming: `int_{domain}_{concept}`
- `ref()` staging or other intermediate models only — never `source()`
- No `contract.enforced` (intermediate is internal)

## What Belongs Here
- Deduplication and normalization
- Sessionization, identity stitching, funnel staging
- Attribution, engagement states, experiment results
- Subscription lifecycle, MRR movements
- Cross-domain joins (checkout conversion, account health)

## What Does Not Belong Here
- Direct `source()` references
- Final dimensional modeling (that belongs in marts)
- Metric definitions
