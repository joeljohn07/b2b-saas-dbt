# dbt-audit

Deep compliance audit across the entire project. Do ALL steps automatically without asking:

1. **Detect project** — Find `dbt_project.yml` in CWD or parents. Abort if not a dbt project.

2. **Load rules:**
   - Read `docs/review/common-mistakes.md`
   - Read `docs/review/pr-checklist.md`
   - Read each layer CLAUDE.md
   - Read `tests/CLAUDE.md`

3. **Run audit categories:**

   a. **Test coverage** — Parse all `_models.yml` files:
      - Flag models without PK tests (`not_null` + `unique`)
      - Flag FK columns without `relationships` tests
      - Flag categorical columns without `accepted_values`
      - Flag boolean columns using `accepted_values` instead of contract enforcement
      - Flag numeric columns missing range checks where applicable

   b. **Layer compliance** — Check every model:
      - Staging models use only `source()`, never `ref()`
      - Intermediate models use only `ref()`, never `source()`
      - Marts models ref intermediate only (fct_/dim_/bridge_), not staging
      - Materialization matches layer rules (staging=view, intermediate=view, marts=table)
      - `contract.enforced` set where required (staging + fct_/dim_/bridge_ marts)

   c. **Documentation completeness**:
      - Run `scripts/lint-doc-blocks.sh` for inline description violations
      - Scan for columns in _models.yml without any description
      - Scan `docs/columns.md` for doc blocks not referenced by any model
      - Check model descriptions exist and use `{{ doc() }}` blocks

   d. **Naming compliance**:
      - Run `scripts/lint-model-names.sh`
      - Check column naming consistency across layers (same concept = same name)

   e. **Meta compliance** (marts only):
      - Check all marts models for required meta fields: owner, pii, sla, tier

4. **Present scored report:**
```
## dbt Audit Report

| Category           | Status | Issues |
|--------------------|--------|--------|
| Test coverage      | PASS/WARN/FAIL | N |
| Layer compliance   | PASS/WARN/FAIL | N |
| Documentation      | PASS/WARN/FAIL | N |
| Naming             | PASS/WARN/FAIL | N |
| Meta compliance    | PASS/WARN/FAIL | N |

### Issues by Severity
#### CRITICAL
- ...
#### WARNING
- ...

### Overall: N/5 categories pass
```
