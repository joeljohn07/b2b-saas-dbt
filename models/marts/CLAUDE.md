# Marts Layer

## Purpose
Kimball star schema. Consumer-facing facts and dimensions.

## Conventions
- Materialized: table
- `contract.enforced: true` on `fct_`, `dim_`, `bridge_` models. Optional on `agg_`, `rpt_`, `mart_`
- Naming:
  - `fct_{entity}` — measurable business events at declared grain
  - `dim_{entity}` — descriptive context, conformed, reusable across facts
  - `bridge_{m2m}` — many-to-many relationship resolution
  - `agg_{entity}_{grain}` — pre-aggregated fact at coarser grain than parent fact
  - `rpt_{topic}` — consumer-specific denormalized table, not reusable, replaces export concept
  - `mart_{entity}` — dimension blended with fact aggregations (e.g., customer + total revenue)
- `meta` required: owner, pii (boolean), sla, tier (1-5)
- `ref()` intermediate models for `fct_`, `dim_`, `bridge_` — never `source()`, never staging
- `agg_`, `rpt_`, `mart_` may also `ref()` other marts models (facts, dimensions)
- Conformed dimensions: shared dim keys across all facts
- Role-playing FKs use suffixed keys (e.g., `session_date_key`, `acquisition_date_key`)

## What Belongs Here
- Fact tables at declared grain (one row = one event/snapshot)
- Dimension tables with descriptive attributes
- Bridge tables for many-to-many relationships
- Light joins and column selection from intermediate models
- Pre-aggregated fact tables at coarser grain (agg_ prefix)
- Consumer-specific denormalized tables for dashboards (rpt_ prefix)
- Dimension + fact blend tables for common access patterns (mart_ prefix)

## What Does Not Belong Here
- Heavy transformations (push to intermediate)
- Raw source references
- Business logic beyond FK assembly in `fct_`, `dim_`, `bridge_` models (aggregation logic is allowed in `agg_`, `rpt_`, `mart_`)

## Directory Organization
Models organized by business area:
- core/ — conformed dimensions (users, accounts, date, channels) + cross-domain facts (retention cohorts spans product + billing data, not owned by either domain)
- product/ — product analytics facts + domain-specific dims + bridges
- billing/ — subscription + MRR + invoice facts
- marketing/ — channel spend facts
- support/ — support ticket facts
Each subdirectory contains one `_models.yml` with all model schemas.
