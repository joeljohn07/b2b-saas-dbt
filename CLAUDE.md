# analytics-dbt — Project Rules

## What This Is
Product funnel analytics with dbt on BigQuery

## Non-Negotiables
- No secrets in code, chat, or committed files
- Conventional commits: feat:, fix:, refactor:, docs:, test:, chore:, perf:, build:, ci:, style:, revert:
- Pre-commit hook: `git config core.hooksPath .githooks`
- Preinstall security audit required before adding any new dependency
- Project must be independently workable from its own repo root (no hub-only execution dependency)

## Testing
- python3 -m unittest discover -s tests -p 'test_*.py'
- TDD for all modules: failing test → smallest fix → green → refactor
- Mock I/O boundaries in unit tests

## Data Backend
- Default: BigQuery (hub pipeline). See `~/Agentic/docs/integrations/bigquery-event-contract.md` for schema patterns.
- Guardrails: partition by date, `require_partition_filter=true`, byte cap on queries, dead-letter table per dataset.
- Choose local Postgres instead only for: relational CRUD, low-latency transactions, or offline-first apps.
- Never store secrets, PII, or runtime state in BigQuery.

## Git
- **Never commit directly to main.** Create a feature branch first: `git checkout -b feat/description`
- Push branches with `git push -u origin HEAD`, then `gh pr create`
- Squash merge via `gh pr merge --squash --delete-branch`
- Pre-push hook blocks direct pushes to main (primary enforcement).
- Pre-commit blocks: .env, tokens, secrets
- Full workflow: `~/Agentic/frameworks/engineering/GIT_BRANCH_WORKFLOW.md`
