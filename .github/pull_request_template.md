## What changed
<!-- Brief description -->

## Why
<!-- Motivation, link to issue -->

## Checklist
- [ ] Correct layer directory (staging/intermediate/marts)
- [ ] Naming convention (stg_, int_, fct_, dim_, bridge_, agg_, rpt_, mart_)
- [ ] Materialization matches layer (staging=view, intermediate=view, marts=table)
- [ ] PK tests: `unique` + `not_null`
- [ ] FK tests: `relationships` on every FK column
- [ ] Enum tests: `accepted_values` on categorical columns
- [ ] Model + column descriptions use `{{ doc() }}` blocks
- [ ] Contracts enforced (staging + fct_/dim_/bridge_)

## Test plan
<!-- dbt build output, test count, what was verified -->
