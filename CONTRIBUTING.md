# Contributing

This is a portfolio project, but the contribution workflow is the same one a real team would use.

## Setup

Full setup steps in [`RUNBOOK.md`](RUNBOOK.md). Short version: Python 3.12, `gcloud` authenticated, `dbt deps`, copy `profiles.yml.example` to `~/.dbt/profiles.yml`, `export GCP_PROJECT_ID=...`.

## Branching

- Never commit directly to `main`. Always a feature branch and a PR.
- Branch naming: `<prefix>/<type>/<short-description>`.
  - Prefix: `cc/` (Claude Code), `cx/` (Codex), or your initials.
  - Type: `feat`, `fix`, `docs`, `test`, `refactor`, `chore`.
  - Example: `cc/feat/add-retention-snapshot`.

## Commits

Conventional commits. Lowercase imperative subject, no trailing period.

```
feat: add retention snapshot fact table
fix: correct lookback anchor in int_events_normalized
docs: clarify identity stitching window rationale
test: add fanout guard for fct_sessions
```

The `commit-msg` hook enforces this on every commit.

## Before You Open a PR

1. **Tests pass locally** — `dbt build --select state:modified+` against your dev target. The TDD gate (pre-push hook) blocks pushes that change a model without a corresponding test change.
2. **Lint clean** — sqlfluff + doc-block lint run as pre-commit hooks; CI runs them again. If a hook fails, fix the issue rather than `--no-verify`.
3. **Doc tags updated** — every new column or model gets a `doc(...)` block authored in the appropriate layer `.md` file. Pattern: [`docs/doc-block-convention.md`](docs/doc-block-convention.md).
4. **Decision documented** — if you changed a project variable, materialisation strategy, or business rule, add a dated entry to [`decisions.md`](decisions.md) with the **why** and what was considered.

## What a PR Review Looks For

Full checklist: [`docs/review/pr-checklist.md`](docs/review/pr-checklist.md). Highlights:

- **Layer compliance** — staging only `source()`, intermediate only `ref()`, marts only `ref()` of intermediate or other marts. `dbt-project-evaluator` catches violations at `severity: error`.
- **Grain declared and respected** — every fact and dimension states its grain in the model description; tests prove the row count.
- **Contracts** — `contract.enforced: true` on all staging models and on `fct_`/`dim_`/`bridge_` marts.
- **Test evidence** — a new metric needs an invariant test; a new join needs a fanout test; a new mart needs a contracts smoke check.
- **No `select *`** — explicit column lists everywhere.
- **Naming follows the contract** — see [`docs/dbt-guidelines.md`](docs/dbt-guidelines.md).

## Tests

Categories live under `tests/`:

- `tests/invariants/` — things that must always be true.
- `tests/reconciliation/` — mart totals reconcile to upstream intermediate.
- `tests/fanout/` — guards against unintended grain expansion.
- `tests/contracts/` — populated-table assertions for the production marts.

Plus per-column tests in `_models.yml` (`unique`, `not_null`, `accepted_values`, `relationships`, `dbt-utils` helpers).

Severity policy in [`docs/quality-gates.md`](docs/quality-gates.md).

## Merging

- Squash-merge via the GitHub UI.
- The PR title becomes the squash commit title — keep it under ~70 chars and conventional-commits formatted.
- Use the PR description for context, not the commit subject.

## See Also

- [`RUNBOOK.md`](RUNBOOK.md) — environment setup and daily commands.
- [`docs/architecture.md`](docs/architecture.md) — system design.
- [`docs/dbt-guidelines.md`](docs/dbt-guidelines.md) — exhaustive dbt conventions.
- [`docs/review/common-mistakes.md`](docs/review/common-mistakes.md) — patterns that get caught in review.
- [`CLAUDE.md`](CLAUDE.md) / [`AGENTS.md`](AGENTS.md) — operating instructions for AI-assisted work.
