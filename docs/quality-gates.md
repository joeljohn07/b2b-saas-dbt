# Quality Gate Thresholds — b2b-saas-dbt

| Test type | Severity | Threshold | Notes |
|-----------|----------|-----------|-------|
| PK (unique + not_null) | error | any failure | Non-negotiable on all models |
| Accepted values / enum | error | any failure | |
| FK relationships | warn | >0 rows | Warn to avoid full-scan cost on large tables |
| Invariants | error | any failure | |
| Reconciliation | error | tolerance per test | Default: abs diff > 0.01 |
| Fanout | error | ratio > 1.01 | Mart rows / intermediate rows |
| Contracts | error | any missing | CI-only (requires built tables) |
| Source freshness | warn at 12h, error at 24h | per-source | Configured in _sources.yml |

## Notes

**FK severity:** `warn` prevents CI blocking on expensive full-table relationship scans while still
surfacing referential integrity issues. Escalate to `error` if the FK is the sole referential
integrity gate for a given column.

**Reconciliation tolerance:** Each test declares its own tolerance in the config description.
The default `abs diff > 0.01` matches the precision used in `reconciliation_int_mrr_movements_net_mrr.sql`.

**Contracts test:** CI-only — the smoke test in `tests/contracts/` requires all mart tables to be
built before it can run. It will fail on a fresh dev schema before `dbt build`.
