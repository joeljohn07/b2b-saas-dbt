# Runbook

Setup, daily commands, and incident response for `b2b-saas-dbt`.

## Prerequisites

- Python 3.12
- A BigQuery project (the synthetic dataset costs effectively $0 in the free tier).
- `gcloud` CLI installed and authenticated:
  ```
  gcloud auth login
  gcloud auth application-default login
  ```

## First-Time Setup

```bash
# Clone and enter the repo
git clone https://github.com/joeljohn07/b2b-saas-dbt.git
cd b2b-saas-dbt

# Set the GCP project (used by every source declaration)
export GCP_PROJECT_ID=your-project-id

# Install Python dependencies (CI deps + dev deps)
python3.12 -m venv .venv
source .venv/bin/activate
pip install -r requirements-ci.txt -r requirements-dev.txt

# Install dbt packages
dbt deps

# Copy the profile template and edit for your GCP project
cp profiles.yml.example ~/.dbt/profiles.yml
# Edit ~/.dbt/profiles.yml to set project, dataset, location to taste

# Install pre-commit hooks (sqlfluff, dbt-parse, secret scan, doc-block lint)
pre-commit install
```

## Generate the Synthetic Dataset

The project has no real data — the synthetic generator produces a complete, deterministic dataset and uploads it to your BigQuery project.

```bash
# Local CSV only (fast smoke test)
python scripts/generate_synthetic_data.py --users 1000 --months 6

# Full 50K-user / 24-month dataset uploaded to BigQuery
python scripts/generate_synthetic_data.py --users 50000 --months 24 --upload
```

The upload creates and populates `raw_funnel.events`, `raw_billing.subscriptions`, `raw_billing.invoices`, `raw_marketing.spend`, `raw_support.tickets` in your GCP project. Re-running with the same `--seed` produces byte-identical output.

## Daily Commands

```bash
# Parse only (fast — catches Jinja and ref errors)
dbt parse

# Build everything against your dev target
dbt build --target dev

# Build a slice (intermediate billing onwards)
dbt build --select +int_mrr_movements+ --target dev

# Run tests only, without rebuilding
dbt test --target dev

# Serve the docs site locally
dbt docs generate && dbt docs serve --port 8080
```

## CI Behaviour

Every PR runs two GitHub Actions workflows:

- `ci.yml` — lint (sqlfluff, model-name lint, doc-block lint, shell tests), then `dbt build --target ci --full-refresh` into a per-PR dataset `analytics_ci_<pr_number>_*`. Authenticates to GCP via OIDC / Workload Identity Federation — no long-lived service-account keys.
- `pr-teardown.yml` — runs on PR close, drops the per-PR dataset.

CI gates that block merge:
- sqlfluff lint failure
- model naming violation (`scripts/lint-model-names.sh`)
- doc-block lint failure (`scripts/lint-doc-blocks.sh --strict`)
- shell test failure
- dbt parse, build, or test failure
- `dbt-project-evaluator` rule with `severity: error` (DAG boundary violations)

## Pre-Commit Hooks

Run on every commit. To run manually across the whole repo:

```bash
pre-commit run --all-files
```

Hooks in order:
- trailing whitespace, end-of-file, YAML syntax, merge-conflict markers
- sqlfluff lint (Jinja templater for speed; CI uses the dbt templater for full accuracy)
- dbt-parse, model-has-tests, model-has-properties, model-has-description
- doc-block lint
- secret scan (`scripts/secret-scan.sh`)
- conventional-commit message check (commit-msg hook)
- TDD gate on push (`scripts/tdd-gate.sh` — model changes must come with test changes)

## Common Failures

### `dbt parse` fails with `compilation error in model`

Most common cause: a `ref()` to a model that doesn't exist or a `source()` that's not declared in `_sources.yml`. Run `dbt list --select <model>` to confirm dbt sees the model.

### `dbt build` fails with `Permission denied while accessing dataset`

Check that `gcloud auth application-default login` is current and the dataset lives in the location declared in `profiles.yml` (`EU` by default).

### CI fails with `Dataset analytics_ci_<n>_* does not exist`

Race condition between the build job and an earlier teardown. Re-run the failed job — it will create the dataset fresh.

### `dbt-project-evaluator` raises `fct_marts_or_intermediate_dependent_on_source`

A marts or intermediate model is referencing a `source()` directly. Move the reference up one layer: intermediate should only `ref()` staging, marts should only `ref()` intermediate or other marts.

### `farm_fingerprint` returns NULL

Usually a NULL input — `farm_fingerprint(concat(a, '|', b))` returns NULL if either `a` or `b` is NULL. Wrap inputs with `coalesce(..., '')` or, better, guarantee non-null upstream and let the NULL surface as a test failure.

### Incremental `int_events_normalized` missing late events

The 36-hour lookback (`events_incremental_lookback_hours` var) is anchored on `_loaded_at`, not `event_time`. If an event arrives more than 36 hours after the previous run, it will not be picked up by `dbt build` — only by `dbt build --full-refresh`. Bump the var or schedule a periodic full refresh if your source has longer tails.

### Pre-commit hook `secret-scan.sh` flags a commit

The hook looks for high-entropy strings that match common secret formats. Review the flagged file — if it's a false positive (e.g., a UUID literal in a fixture), prefix the line with a `# noqa: secret` comment and re-commit. Never bypass with `--no-verify` unless you've manually verified no secret is leaking.

## Useful Selectors

```bash
# Everything in one domain
dbt build --select tag:product

# All marts and their upstream dependencies
dbt build --select +tag:marts

# Only the changed models in the current branch (state defer)
dbt build --select state:modified+ --defer --state ./target-base

# Skip a slow incremental during dev
dbt build --exclude int_events_normalized
```

## State and Manifests

After a successful build, `target/manifest.json` is the authoritative artifact for that run. On `push to main`, CI uploads it as a workflow artifact for downstream `--defer` builds.

## Where to Look When Something's Wrong

| Symptom | First place to look |
|---|---|
| A metric looks wrong | `docs/metric-contract.md` for the canonical definition, then the source model. |
| A column appeared / disappeared | `decisions.md` (search for the column name). |
| A test failed and you don't know why | `tests/<dir>/CLAUDE.md` for the test charter, then the test SQL. |
| CI passed but prod looks off | Compare the failed metric against `tests/reconciliation/` — they're designed to catch exactly this. |
| dbt won't parse and the error is opaque | `dbt parse --debug` and read the full traceback. |

## See Also

- [`docs/architecture.md`](docs/architecture.md) — system design.
- [`docs/event-contract.md`](docs/event-contract.md) — source schema.
- [`docs/metric-contract.md`](docs/metric-contract.md) — canonical metrics.
- [`docs/quality-gates.md`](docs/quality-gates.md) — test severity policy.
- [`decisions.md`](decisions.md) — every architectural decision with rationale.
