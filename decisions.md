# Decision Log — b2b-saas-dbt

## 2026-03-12: Initial setup
- Project created and scaffolded
- Description: Full-company analytics platform with dbt on BigQuery
- Repo: https://github.com/joeljohn07/b2b-saas-dbt

## 2026-03-13: Architecture contract + tiered agent instructions
- Rewrote CLAUDE.md with dbt-specific three-layer architecture contract
- Created directory-level CLAUDE.md for staging, intermediate, marts, tests (Tier 1)
- Rewrote README.md with architecture diagram, source domains, environment targets
- Created Tier 2 doc stubs in docs/layers/
- Updated llms.txt with dbt references

## 2026-03-21: Expanded conventions
- Added mart prefixes: agg_ (coarser grain), rpt_ (dashboard-specific), mart_ (dim+fact blend)
- Added intermediate suffixes: _prep (source-specific prep), _unioned (multi-source union)
- Retired exp_ prefix / export layer concept — rpt_ within marts replaces it
- Added column naming consistency as hard rule
- Added SQL style: group by all, union all by name
- Adopted subdirectories within layers (source/domain/business-area)
- Adopted per-directory _models.yml YAML layout convention
- Populated docs/layers/ stubs with full layer contract and dimensional modeling guidelines
