# dbt-scaffold

Generate a new model with all conventions applied. Do ALL steps automatically without asking:

1. **Parse arguments** — `$ARGUMENTS` format: `<layer> <model_name>` (e.g., `intermediate int_billing_payments_prep`)
   - If missing, ask for layer and model name

2. **Validate:**
   - Layer must be staging, intermediate, or marts
   - Model name must match naming convention for that layer (run through `scripts/lint-model-names.sh` pattern)
   - Infer subdirectory from model name (e.g., `int_billing_*` → `models/intermediate/billing/`)

3. **Read layer rules:**
   - Read the layer's CLAUDE.md (e.g., `models/intermediate/CLAUDE.md`)
   - Read `docs/doc-block-convention.md` for doc block patterns

4. **Generate SQL file** with layer-appropriate template:
   - **Staging**: `source()` ref, explicit column list, type casting, contract-ready
   - **Intermediate**: `ref()` to staging/intermediate, CTE structure, business logic placeholder
   - **Marts**: `ref()` to intermediate, light joins, FK assembly, contract-ready

5. **Update _models.yml** in the target subdirectory:
   - Add model entry with `{{ doc() }}` description placeholder
   - Add column entries with `{{ doc() }}` descriptions
   - Add PK tests: `not_null` + `unique`
   - For staging: add `contract.enforced: true`
   - For marts fct_/dim_/bridge_: add `contract.enforced: true` and `meta` block

6. **Create doc block stubs** in `docs/columns.md` for any new columns not already defined

7. **Report** what was created:
```
Created:
  models/<layer>/<subdir>/<model_name>.sql
  Updated: models/<layer>/<subdir>/_models.yml
  Updated: docs/columns.md (N new doc blocks)

Next steps:
  - Implement the SQL logic
  - Add FK relationship tests
  - Add accepted_values tests for categorical columns
```
