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

## Coverage
- Every model: `not_null` + `unique` on primary key columns
- Every FK column: `relationships` test to parent dimension
- Every enum column: `accepted_values` with explicit allowed list
- Layer boundaries: singular tests for business rules crossing layers

## Conventions
- Use dbt_expectations for complex assertions
- Test descriptions required on all singular tests
- Singular tests at staging input and marts output — not intermediate internals
- Schema tests (PK, FK, enums) apply to every model including intermediate
