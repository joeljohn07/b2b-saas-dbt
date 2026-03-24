# PR Review Checklist

Apply the layer-specific section based on which files changed.

## All Layers

- [ ] No inline descriptions — every description uses `{{ doc() }}` blocks
- [ ] No `select *` — explicit column lists
- [ ] SQLFluff clean (lowercase keywords, trailing commas, 4-space indent)
- [ ] CTEs over subqueries
- [ ] Column names match existing conventions (same concept = same name across models)
- [ ] PK tested: `not_null` + `unique` on every model
- [ ] Conventional commit message
- [ ] Doc blocks created/updated in `docs/columns.md` for new columns

## Staging

- [ ] Model name: `stg_{source}__{entity}` (double underscore)
- [ ] `contract.enforced: true` in _models.yml
- [ ] Only `source()` references — no `ref()`
- [ ] No joins, aggregations, window functions, or derived columns
- [ ] Column types cast to canonical (TIMESTAMP, DATE, STRING, INT64, NUMERIC)
- [ ] Columns renamed to snake_case, no abbreviations
- [ ] JSON shredding to flat columns where appropriate
- [ ] `_sources.yml` present in subdirectory
- [ ] FK columns tested with `relationships`
- [ ] Enum columns tested with `accepted_values`
- [ ] Boolean columns: `contract.enforced` with `data_type: boolean` (NOT `accepted_values`)

## Intermediate

- [ ] Model name: `int_{domain}_{concept}` (optional `_prep` or `_unioned` suffix)
- [ ] Only `ref()` — no `source()` references
- [ ] No `contract.enforced` (intermediate is internal)
- [ ] Materialized as view (exception: `int_events_normalized` is incremental)
- [ ] Correct subdirectory: product/, billing/, engagement/, or cross_domain/
- [ ] New derived columns tested (CASE WHEN outputs, aggregations, window functions)
- [ ] Business logic consistent with locked decisions (see common-mistakes.md)
- [ ] Skip tests on passthrough columns already tested in staging

## Marts

- [ ] Model name: `fct_`, `dim_`, `bridge_`, `agg_`, `rpt_`, or `mart_` prefix
- [ ] `contract.enforced: true` on `fct_`, `dim_`, `bridge_` models
- [ ] `meta` present: owner, pii (boolean), sla, tier (1-5)
- [ ] Materialized as table
- [ ] `ref()` intermediate models only for `fct_`/`dim_`/`bridge_` — never staging, never source
- [ ] `agg_`/`rpt_`/`mart_` may also `ref()` other marts models
- [ ] Conformed dimension keys: FK columns reference shared dim keys
- [ ] Role-playing FKs use suffixed keys (e.g., `session_date_key`, `acquisition_date_key`)
- [ ] FK columns tested with `relationships` to conformed dimensions
- [ ] Re-test critical business fields even if tested upstream (safety net)
- [ ] Correct subdirectory: core/, product/, billing/, marketing/, or support/

## Tests

- [ ] Singular test name: `{category}_{model}_{invariant}.sql`
- [ ] Test in correct subdirectory: invariants/, reconciliation/, fanout/, or contracts/
- [ ] `config: severity:` set (error for critical, warn for data quality)
- [ ] Description present in config block
- [ ] No reinventing the wheel — check dbt_utils/dbt_expectations before custom SQL
- [ ] `config: where:` used on large table tests for performance

## Cross-Model

- [ ] No column name drift (same business concept uses same name everywhere)
- [ ] FK naming consistent across layers
- [ ] No orphaned doc blocks (blocks added but no model references them)
- [ ] Models in _models.yml match actual SQL files (no phantom entries)
