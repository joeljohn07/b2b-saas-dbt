# Agent Operating Index — b2b-saas-dbt

Entry point for LLMs and agents working on this project.

## Architecture contract
- Root rules: `CLAUDE.md` (naming, hard rules, SQL style, file layout)

## Layer-specific rules
- Staging: `models/staging/CLAUDE.md`
- Intermediate: `models/intermediate/CLAUDE.md`
- Marts: `models/marts/CLAUDE.md`
- Tests: `tests/CLAUDE.md`

## Layer contract (full spec)
- `docs/layers/layer-contract.md`
- `docs/layers/dimensional-modeling-guidelines.md`

## PR review
- `docs/review/pr-checklist.md` — layer-specific checklist (70 items)
- `docs/review/common-mistakes.md` — 26 anti-patterns with locked business logic violations

## Doc block convention
- `docs/doc-block-convention.md` — all descriptions must use `{{ doc() }}` blocks

## Skills (workflow instructions)
- `docs/skills/dbt-validate.md` — lint + build + doc check
- `docs/skills/dbt-pr-review.md` — structured PR review
- `docs/skills/dbt-scaffold.md` — generate model + YAML stubs
- `docs/skills/dbt-audit.md` — deep compliance audit

## Decision log
- `decisions.md` — architectural choices and why
