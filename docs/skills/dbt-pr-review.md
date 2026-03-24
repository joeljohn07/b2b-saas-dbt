# dbt-pr-review

Structured PR review with audit pass. Do ALL steps automatically without asking:

1. **Detect project** — Find `dbt_project.yml` in CWD or parents. Abort if not a dbt project.

2. **Gather context:**
   - Changed files: `git diff main...HEAD --name-only`
   - Full diff: `git diff main...HEAD`
   - Classify changes by layer (staging/intermediate/marts/tests/docs/scripts)
   - Read the changed files

3. **Load review rules:**
   - Read `docs/review/pr-checklist.md`
   - Read `docs/review/common-mistakes.md`
   - Read `docs/doc-block-convention.md`
   - Read the relevant layer CLAUDE.md for each changed layer

4. **Review pass** (checklist from pr-checklist.md):
   - Apply layer-specific checklist items to each changed model file
   - Check _models.yml changes for inline descriptions, missing tests, missing doc blocks
   - Match against common-mistakes.md anti-patterns

5. **Audit pass** (scoped to changed files only):
   - **Test coverage**: flag changed models missing PK tests (not_null+unique), FK relationships, accepted_values on categoricals
   - **Layer compliance**: verify ref() usage, materialization, contract.enforced
   - **Documentation**: no inline descriptions, doc blocks present for all columns
   - **Naming**: validate model names against conventions
   - **Meta**: check marts models for required meta fields (owner, pii, sla, tier)
   - **Business logic**: verify against locked decisions in common-mistakes.md

6. **Output** — structured findings with severity:
```
## PR Review: <branch>

### CRITICAL (must fix before merge)
- file:line — finding

### WARNING (should fix)
- file:line — finding

### INFO (optional improvement)
- file:line — finding

### What's Done Well
- ...
```
