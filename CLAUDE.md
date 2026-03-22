# b2b-saas-dbt — Architecture Contract

## Project
Full-company analytics platform for a B2B SaaS company. dbt on BigQuery, Kimball star schema.
Five source domains: product events, billing subscriptions, billing invoices, marketing spend, support tickets.

## Three-Layer Architecture
- **staging**: 1:1 source shaping, views, `source()` refs only, `contract.enforced`
- **intermediate**: all business logic (dedup, sessions, identity, attribution, lifecycle), views, `ref()` only
- **marts**: Kimball star schema, tables, `contract.enforced`, conformed dimensions

## Naming
- Staging: `stg_{source}__{entity}` (double underscore)
- Intermediate: `int_{domain}_{concept}` (suffixes: `_prep` for source-specific prep, `_unioned` for multi-source union)
- Facts: `fct_{entity}`, Dimensions: `dim_{entity}`, Bridges: `bridge_{m2m}`
- Aggregations: `agg_{entity}_{grain}`, Reports: `rpt_{topic}`, Marts: `mart_{entity}`

## Hard Rules
- No `select *` — explicit column lists everywhere
- `{{ doc() }}` for any field description reused across 2+ models
- Contracts required on all staging models and marts `fct_`, `dim_`, `bridge_` models. Optional on `agg_`, `rpt_`, `mart_`
- No custom governance macros — use dbt-project-evaluator
- Column naming consistency: same concept = same column name across all models

## SQL Style
- SQLFluff for linting
- Lowercase keywords, trailing commas, 4-space indent
- CTEs over subqueries
- Prefer `group by all` over explicit column ordinals
- Use `union all by name` for multi-source unions

## File Organization
- Models organized into subdirectories within layers (by source, domain, or business area)
- One `_models.yml` per subdirectory for schema definitions
- One `_sources.yml` per staging subdirectory for source declarations

## Testing
- See `tests/CLAUDE.md` for all testing rules, categories, exceptions, and naming
- Dev builds: `dbt build --exclude package:dbt_project_evaluator`
- Evaluator runs in CI only (or on demand: `dbt build --select package:dbt_project_evaluator`)

## Git
- Never commit directly to main — feature branch + PR
- Conventional commits: feat:, fix:, docs:, test:, refactor:, chore:
- Squash merge via PR

## Layer Details
Each model directory has its own CLAUDE.md with layer-specific rules.
Full documentation in `docs/layers/`.
