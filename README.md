# b2b-saas-dbt

Full-company analytics platform for a B2B SaaS company — dbt on BigQuery, Kimball star schema.
38 models, 485+ tests, 5 source domains, full CI with per-PR dataset isolation.

**Live model docs:** [joeljohn07.github.io/b2b-saas-dbt](https://joeljohn07.github.io/b2b-saas-dbt/) — interactive lineage graph and column-level docs, auto-published from `main`.

## What this demonstrates

- **Frozen business logic** — 6 locked decisions (identity stitching, sessionization, engagement scoring, attribution, retention cohorts, canonical activation) are defined once in intermediate models and referenced everywhere; no per-model re-derivation
- **Incremental events pipeline** — `int_events_normalized` merges on `event_id` with a 36h `_loaded_at` lookback window, catching late arrivals without full-refresh cost
- **CI isolation** — every PR gets its own BigQuery dataset (`analytics_ci_{PR_NUMBER}`); WIF keyless auth, no service account key files in CI secrets
- **Enforced architecture** — `dbt-project-evaluator` blocks naming and DAG violations in CI; a custom doc-block linter blocks inline descriptions and orphaned `{{ doc() }}` references at pre-commit
- **Agent-ready codebase** — tiered CLAUDE.md instruction contract (root + one per layer) with `docs/agent/INDEX.md` as the canonical entry point; skill files for validate, PR review, scaffold, and audit; fixture seeds with companion invariant tests for edge-case coverage; built for iterative AI-assisted development from the start

## Architecture

```
raw sources           staging               intermediate            marts
───────────          ─────────             ──────────────          ──────
raw_funnel     ───►  stg_*__events    ───► int_events_normalized ──► fct_sessions
raw_billing    ───►  stg_*__subs      ───► int_mrr_movements     ──► fct_mrr_movements
               ───►  stg_*__invoices  ───► int_attribution       ──► dim_users
raw_marketing  ───►  stg_*__spend     ───► int_engagement_states ──► dim_accounts
raw_support    ───►  stg_*__tickets   ───► int_account_health    ──► dim_date
                     (view, 1:1)           (view, logic)              (table, star)
```

## Model inventory

| Layer | Models | Materialization |
|-------|--------|-----------------|
| Staging | 5 | view |
| Intermediate | 16 | view (1 incremental) |
| Marts | 17 + 2 seeds | table |
| **Total** | **38** | |

Mart types: `fct_` (measurable events), `dim_` (conformed dimensions), `bridge_` (M:M), `fct_retention_cohorts` (cross-domain). `dim_date` and `experiment_metadata` are seeds materialized in the marts schema.

## Key engineering decisions

- `farm_fingerprint()` for all surrogate keys — BQ-native INT64, no UUID overhead
- `dim_date` as a static seed (2024–2029) rather than a spine macro — simpler, no macro dependency
- `dim_users` SCD Type 1 — latest membership wins; historical membership tracked in `int_account_memberships`
- 1800s inactivity threshold for sessionization (not 30-min integer, which loses BigQuery timestamp precision)
- Incremental events lookback on `_loaded_at` not `event_time` — catches late-arriving duplicates at source
- Retention pre-computed in dbt (not Lightdash) with a 7-day `is_period_complete` guard on trailing cohorts

## CI / Quality gates

| Gate | Tool | Trigger |
|------|------|---------|
| SQL lint | SQLFluff | pre-commit + CI |
| Parse + build | dbt | every PR |
| Naming + DAG | dbt-project-evaluator | every PR |
| Doc blocks | `scripts/lint-doc-blocks.sh` | pre-commit + CI |
| Source freshness | `dbt source freshness` | every PR |
| Staging volume | singular test | every PR |
| Auth | Workload Identity Federation | CI (no key files) |
| Dataset isolation | `analytics_ci_{PR_NUMBER}` | every PR |

## Quick start

Prerequisites: Python 3.12+, `gcloud` CLI authenticated, a BigQuery project (free tier is sufficient — see [Cost notes](#cost-notes) below).

```bash
# 1. Install Python deps (dbt-core 1.11+, dbt-bigquery, sqlfluff, data-gen libs)
python3.12 -m venv .venv && source .venv/bin/activate
pip install -r requirements-ci.txt -r requirements-dev.txt

# 2. Auth + profile
gcloud auth application-default login
export GCP_PROJECT_ID=your-project-id
cp profiles.yml.example ~/.dbt/profiles.yml

# 3. Install dbt packages
dbt deps

# 4. Generate the synthetic dataset (one-time, ~5 min, uploads to BQ)
python scripts/generate_synthetic_data.py --users 50000 --months 24 --upload

# 5. Build everything
dbt build --exclude package:dbt_project_evaluator
```

Full setup, common failures, and daily commands: [`RUNBOOK.md`](RUNBOOK.md).

## Cost notes

The synthetic dataset is sized to fit comfortably within BigQuery's permanent free tier. Numbers below assume on-demand pricing at $6.25 / TB scanned and the default `--users 50000 --months 24` generator config.

| Component | Volume | Storage | Notes |
|---|---|---|---|
| `raw_funnel.events` | ~5.5M rows | ~2.7 GB | Dominant — 22 cols, mostly STRING. |
| `raw_billing.subscriptions` | ~150K rows | ~45 MB | |
| `raw_billing.invoices` | ~200K rows | ~50 MB | |
| `raw_marketing.spend` | ~30K rows | ~5 MB | |
| `raw_support.tickets` | ~40K rows | ~10 MB | |
| Marts (17 tables) | derived | ~150-200 MB | Smallest layer — most analysis happens here. |
| Intermediate (16 views + 1 table) | derived | ~3 GB | `int_events_normalized` is the only intermediate table; the rest are views (zero storage). |
| **Total** | | **~6 GB** | Well under the 10 GB free storage tier. |

**Query cost per `dbt build`:**

- Initial full refresh: ~3 GB scanned across staging + intermediate ≈ **$0.02**.
- Incremental run (default daily cadence): only the 36-hour `_loaded_at` lookback on events is scanned ≈ 50 MB ≈ **$0.0003** — effectively free.
- Monthly cost at one daily build: ~1.5 GB total scanned ≈ **$0.01** — covered by BQ's 1 TB / month on-demand free tier.

**At 10× volume (500K users):**

- Storage: ~30 GB raw, still within the free tier for individual projects with no other usage.
- Initial refresh: ~$0.20. Incremental daily build: ~$0.50 / month.

**What drives cost:**

1. `int_events_normalized` is the only incremental model. Its 36-hour `_loaded_at` lookback (`events_incremental_lookback_hours`) bounds the per-run scan.
2. Staging and intermediate layers are views — no storage cost, only on-query cost. A `dbt run --select staging` is essentially free.
3. Marts are tables but small (~200 MB total) and rebuilt by reading from the intermediate views.
4. Long-term storage (90+ days untouched) auto-discounts 50%. Doesn't apply here because everything is touched daily.

**What's not counted:** BigQuery slot time on flat-rate pricing (not used here), Storage API streaming inserts (also not used), or the cost of running the synthetic data generator's BQ upload — that's a one-time ~$0 cost on the free tier.

## Source domains

| Domain | Source | Key Entities |
|--------|--------|-------------|
| Product | `funnel.events` | Page views, signups, activations, feature usage, experiments |
| Billing | `billing.subscriptions` | Trials, upgrades, downgrades, cancellations, MRR |
| Billing | `billing.invoices` | Payments, refunds, line items |
| Marketing | `marketing.spend` | Channel spend, campaigns, impressions, clicks |
| Support | `support.tickets` | Tickets, resolution times, CSAT scores |

## Directory structure

```
.
├── models/
│   ├── staging/                # 1:1 source shaping (views)
│   ├── intermediate/           # Business logic (views + 1 incremental)
│   └── marts/                  # Kimball star schema (tables)
├── tests/
│   ├── invariants/             # PK, not-null, enum, logic checks
│   ├── reconciliation/         # Cross-layer row/value checks
│   ├── fanout/                 # Grain change detection
│   └── contracts/              # Schema contract enforcement
├── seeds/                      # Static reference data (dim_date) + edge-case fixtures
├── docs/                       # Extended documentation + skills
├── scripts/                    # lint-doc-blocks.sh, lint-model-names.sh
└── .github/workflows/          # CI pipeline
```

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for the full workflow. Short version:

1. Feature branch (`cc/<type>/<description>`) — never commit directly to `main`.
2. Conventional commits (`feat:`, `fix:`, `docs:`, `test:`, `refactor:`, `chore:`).
3. Tests for every model change (TDD gate enforced on push).
4. PR, CI runs the full gate suite, squash-merge.
5. Agent operating instructions in [`docs/agent/INDEX.md`](docs/agent/INDEX.md).

## License

MIT
