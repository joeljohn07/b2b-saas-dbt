# b2b-saas-dbt

Full-company analytics platform for a B2B SaaS company — dbt on BigQuery, Kimball star schema.
38 models, 485+ tests, 5 source domains, full CI with per-PR dataset isolation.

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
| Marts | 17 | table |
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

Prerequisites: dbt-core 1.11+, dbt-bigquery, Python 3.12+

```bash
cp profiles.yml.example ~/.dbt/profiles.yml
# Set GCP_PROJECT_ID in your environment

dbt deps        # install packages
dbt parse       # validate project structure
dbt build --exclude package:dbt_project_evaluator  # run models + tests
```

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

1. Create a feature branch (`cc/<type>/<description>`) — never commit directly to main
2. Follow conventional commits: `feat:`, `fix:`, `docs:`, `test:`, `refactor:`, `chore:`
3. Run `dbt build --select state:modified+` and `scripts/lint-doc-blocks.sh` locally
4. Push and open a PR — CI runs the full gate suite automatically
5. See `docs/agent/INDEX.md` for agent operating instructions and skill files

## License

MIT
