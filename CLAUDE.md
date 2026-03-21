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
- Intermediate: `int_{domain}_{concept}`
- Facts: `fct_{entity}`, Dimensions: `dim_{entity}`, Bridges: `bridge_{m2m}`

## Hard Rules
- No `select *` — explicit column lists everywhere
- `{{ doc() }}` for any field description reused across 2+ models
- Contracts required on all staging and marts models
- No custom governance macros — use dbt-project-evaluator

## SQL Style
- SQLFluff for linting
- Lowercase keywords, trailing commas, 4-space indent
- CTEs over subqueries

## Testing
- Primary keys: `not_null` + `unique` on every model
- Foreign keys: `relationships` test on every FK
- Enums: `accepted_values` on all categorical columns
- Business rules: singular tests at layer boundaries
- See `tests/CLAUDE.md` for categories and naming

## Git
- Never commit directly to main — feature branch + PR
- Conventional commits: feat:, fix:, docs:, test:, refactor:, chore:
- Squash merge via PR

## Layer Details
Each model directory has its own CLAUDE.md with layer-specific rules.
Full documentation in `docs/layers/`.
