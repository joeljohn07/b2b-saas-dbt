# Quality Gate Thresholds

The severity policy for every test category in this project. Severity governs whether a failure blocks merge (`error`) or surfaces as a non-blocking signal (`warn`). For tolerance-based tests, `warn_if` and `error_if` express the boundary in row counts.

## Policy

| Test category | Severity | Threshold | Configuration site | Rationale |
|---|---|---|---|---|
| PK — `unique` + `not_null` | `error` | 0 failures | per-column in `_models.yml` (default severity) | Data integrity is non-negotiable. A duplicate or null primary key is always a bug. |
| `accepted_values` (enum) | `error` | 0 failures | per-column in `_models.yml` (default severity) | Enum drift is silent corruption — fail fast. |
| FK — `relationships` | `warn` | `warn_if: ">0"`, `error_if: ">10"` | explicit `config:` per-test in `_models.yml` | Small referential gaps are tolerable (e.g., late-arriving anonymous events with no resolved `user_id`). Large gaps signal a real upstream break and should block. |
| Invariant tests | `error` | 0 failures | `{{ config(severity='error') }}` in `tests/invariants/*.sql` | Each invariant encodes a business or technical guarantee — any failure means an assumption broke. |
| Reconciliation tests | `error` | declared tolerance per test (default abs diff > 0.01) | `{{ config(severity='error') }}` in `tests/reconciliation/*.sql` | Mart totals must reconcile to intermediate totals. Drift > tolerance means assembly logic dropped, added, or mutated rows. |
| Fanout tests | `error` | mart_rows ≠ source_rows (exact, with declared exceptions) | `{{ config(severity='error') }}` in `tests/fanout/*.sql` | Row multiplication is always wrong — either grain expansion in a join or accidental row deletion. |
| Contract tests | `error` | 0 missing tables | `tests/contracts/contracts_mart_tables_populated.sql` | All 17 mart models must be built before CI passes. CI-only — fails on a fresh dev schema. |
| Source freshness | `warn at 24h`, `error at 48h` | `_loaded_at` age per source | `_sources.yml` per source | Synthetic data is always "stale" in CI (`continue-on-error: true` on the freshness step). The thresholds document the pattern; in a real production setup they would be tightened to align with upstream SLAs. |

## How Severity Is Set

### Per-column tests in `_models.yml`

`unique`, `not_null`, and `accepted_values` inherit dbt's default severity (`error`) and require no explicit config. A failure on any of these blocks merge.

`relationships` tests carry explicit `config:` per-instance:

```yaml
- relationships:
    arguments:
      to: ref('dim_users')
      field: user_key
    config:
      severity: warn
      warn_if: ">0"
      error_if: ">10"
```

The `warn_if` / `error_if` thresholds are expressions evaluated against the count of failing rows. So a `relationships` test with more than 10 orphan rows escalates from `warn` to `error` and blocks the merge.

### Singular tests in `tests/`

Every singular test file declares severity at the top of the SQL:

```sql
{{ config(
    severity='error',
    tags=['data_quality'],
    description='...'
) }}
```

The `tags` field is conventional, not enforced — `data_quality`, `operations_alert`, and `fixture` are in current use.

### Source freshness in `_sources.yml`

```yaml
freshness:
  warn_after:
    count: 24
    period: hour
  error_after:
    count: 48
    period: hour
```

Configured per source table. Currently uniform across all five sources.

## How CI Interprets Severity

- `dbt build` exits 0 if all tests pass or only warn, and non-zero if any test errors.
- The `Build & Validate` CI job fails on non-zero `dbt build` exit, blocking merge.
- Warnings appear in the `dbt build` output but do not fail the job.
- The `dbt source freshness` step uses `continue-on-error: true` because synthetic data is always stale by definition — the step documents the freshness pattern without blocking CI.

## Escalation Paths

If a `warn`-severity test starts failing repeatedly:

1. Investigate the underlying cause — does the model have a real bug, or is the threshold too tight?
2. If the model is right and the threshold is wrong, tighten the threshold (raise `error_if`) and document in `decisions.md`.
3. If the model is wrong, fix it. The warning becomes silent.
4. Never simply suppress a warning by removing the test.

If an `error`-severity test starts failing in CI:

1. The PR is blocked. This is intentional.
2. Determine whether the test is wrong (rare — would have caught it during review) or the model is wrong (almost always the case).
3. Fix the underlying issue. Do not lower severity to ship.

## See Also

- [`docs/dbt-guidelines.md`](dbt-guidelines.md) — full dbt conventions including the test-category map.
- [`tests/CLAUDE.md`](../tests/CLAUDE.md) — test directory charter.
- [`decisions.md`](../decisions.md) — entries documenting severity changes over time.
