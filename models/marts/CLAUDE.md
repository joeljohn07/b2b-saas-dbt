# Marts Layer

## Purpose
Kimball star schema. Consumer-facing facts and dimensions.

## Conventions
- Materialized: table
- `contract.enforced: true` on all marts models
- Naming: `fct_{entity}`, `dim_{entity}`, `bridge_{m2m}`
- `meta` required: owner, pii (boolean), sla, tier (1-5)
- `ref()` intermediate models only — never `source()`, never staging
- Conformed dimensions: shared dim keys across all facts
- Role-playing FKs use suffixed keys (e.g., `session_date_key`, `acquisition_date_key`)

## What Belongs Here
- Fact tables at declared grain (one row = one event/snapshot)
- Dimension tables with descriptive attributes
- Bridge tables for many-to-many relationships
- Light joins and column selection from intermediate models

## What Does Not Belong Here
- Heavy transformations (push to intermediate)
- Raw source references
- Business logic beyond FK assembly
