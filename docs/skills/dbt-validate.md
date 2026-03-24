# dbt-validate

Run dbt project validation. Do ALL steps automatically without asking:

1. **Detect project** — Find `dbt_project.yml` in CWD or parents. Abort if not a dbt project.

2. **Parse arguments** — Check `$ARGUMENTS` for flags:
   - `--fix`: run sqlfluff in fix mode instead of lint
   - `--quick`: skip dbt build, lint checks only

3. **Run checks sequentially**, collecting pass/fail for each:

   a. **SQL lint** — `sqlfluff lint models/` (or `sqlfluff fix models/` if `--fix`). Report violations.

   b. **Model naming** — `scripts/lint-model-names.sh`. Enforces stg_/int_/fct_/dim_/bridge_/agg_/rpt_/mart_ conventions.

   c. **Doc block lint** — `scripts/lint-doc-blocks.sh`. Catches any inline descriptions in _models.yml (must use `{{ doc() }}` blocks).

   d. **dbt build** (skip if `--quick`) — `dbt build --exclude package:dbt_project_evaluator`. Parses, compiles, runs models, and executes tests.

4. **Present summary:**
```
Validation: <project>
  SQL lint:      PASS/FAIL (N violations)
  Model naming:  PASS/FAIL
  Doc blocks:    PASS/FAIL (N inline descriptions)
  dbt build:     PASS/FAIL (N models, N tests passed, N failed) | SKIPPED
```

5. **If all pass** — one-line confirmation.
   **If failures** — list failures with file:line references. Do not attempt to fix unless `--fix` was passed.
