# Test Rules

## Categories
Tests are organized into subdirectories:

- `invariants/` — PK uniqueness, not-null, accepted_values (every model)
- `reconciliation/` — row count and value checks across layers
- `fanout/` — detect unintended grain changes from joins
- `contracts/` — schema contract enforcement (marts + staging)

## Naming
- Schema tests: declared in model YAML (not_null, unique, relationships, accepted_values)
- Singular tests: `{category}_{model}_{invariant}.sql`

## Primary Keys
- Every model must have a primary key tested with `not_null` + `unique`
- If a model has no natural primary key, generate one with `dbt_utils.generate_surrogate_key` and test it
- Exception: staging models where the source PK has known duplicates (document explicitly, enforce uniqueness in the intermediate dedup model instead)

## Layer Testing Strategy

### Staging (test thoroughly — these are the building blocks)
- PK: `not_null` + `unique` on every model
- Enums: `accepted_values` on all categorical columns
- Not-null: on all columns that should never be null
- Booleans: on BigQuery, `contract.enforced` with `data_type: boolean` handles type safety (see Boolean section below)
- Relationships: test FK columns here (cheaper than testing downstream on larger tables)
- Range checks: `dbt_expectations.expect_column_values_to_be_between` on bounded numeric columns

### Intermediate (test what transforms)
- PK: `not_null` + `unique` on every model (always)
- Skip tests on columns that pass through unchanged from staging — already tested upstream
- Test new derived columns: CASE WHEN outputs, aggregations, window function results
- Singular tests for business rule validation at layer boundaries

### Marts (production-ready gate)
- PK: `not_null` + `unique` on every model — non-negotiable for production
- Re-test critical business fields even if tested upstream (safety net)
- FK: `relationships` tests on conformed dimension keys
- Contracts enforced on all `fct_`, `dim_`, `bridge_` models

## Column Type Rules

### Boolean columns
- BigQuery enforces BOOL type natively — `contract.enforced: true` with `data_type: boolean` prevents 0/1 or string variants from leaking through
- `accepted_values` does not work on BigQuery BOOL columns (dbt casts values to strings, causing type mismatch)
- Add `not_null` if the boolean should never be null
- For non-BigQuery warehouses: use `accepted_values: [true, false]` to guard against type drift

### Categorical columns (status, state, category, type)
- Always test with `accepted_values` and an explicit allowed list
- Columns created via CASE WHEN must have `accepted_values` to guard against logic changes
- CASE WHEN columns should also have `not_null` unless null is an expected output
- Complex CASE statements (3+ branches with business logic) should have dbt unit tests

### Numeric columns
- Use `dbt_expectations.expect_column_values_to_be_between` for bounded ranges (scores, percentages, amounts)
- Financial columns: test `not_null` + `>= 0` where negative values are invalid

## Relationship Tests
- Prefer testing relationships in staging (smaller tables, cheaper scans)
- Use `config: severity: warn` on relationship tests that cross large tables
- In marts, test FK relationships on conformed dimension keys

## Performance
- Use `config: where:` to limit test scope on large tables
- Relationship tests trigger full scans — use cautiously on tables > 1M rows
- Use `config: where:` with a date or partition filter to reduce test scope on large tables

## dbt_utils Test Toolkit
Use these before writing custom singular tests:

| Test | When to use |
|------|-------------|
| `dbt_utils.expression_is_true` | Validate SQL expressions (e.g., `net_amount + tax = gross_amount`) |
| `dbt_utils.not_empty_string` | Check string columns aren't empty (`''`) |
| `dbt_utils.accepted_range` | Check numeric ranges (alternative to dbt_expectations) |
| `dbt_utils.recency` | Verify data freshness on timestamp columns |
| `dbt_utils.not_null_proportion` | Allow some NULL proportion (e.g., 95% not-null is acceptable) |
| `dbt_utils.unique_combination_of_columns` | Composite primary keys |

## Singular Tests
- Use for specific business rule validation that can't be expressed as schema tests
- Don't reinvent the wheel — check dbt_utils and dbt_expectations before writing custom SQL
- Tag singular tests by domain: `operations_alert`, `billing_validation`, `data_quality`
- Include `config: severity: warn/error` and `description` in the config block

## Test Severity
- `error` (default): blocks downstream models, fails CI
- `warn`: surfaces issues without blocking
- Use `error` for: PK violations, critical business rules, contract enforcement
- Use `warn` for: data quality alerts, relationship tests on large tables, coverage checks
- Use `warn_if` / `error_if` thresholds for singular tests that tolerate some failures
