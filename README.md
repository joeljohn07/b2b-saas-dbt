# b2b-saas-dbt

Full-company analytics platform for a B2B SaaS company, built with dbt on BigQuery.

Covers the full analytics lifecycle across five source domains — product events, billing, marketing, and support — through a three-layer dbt architecture into a Kimball star schema for BI consumption.

## Quick Start

Prerequisites: dbt-core 1.11+, dbt-bigquery, Python 3.10+

```bash
# Copy and configure profiles
cp profiles.yml.example ~/.dbt/profiles.yml
# Set GCP_PROJECT_ID in your environment

dbt deps        # install packages
dbt parse       # validate project structure
dbt build       # run models + tests
```

## Architecture

Three-layer dbt project following Kimball dimensional modeling:

```
raw sources           staging               intermediate            marts
───────────          ─────────             ──────────────          ──────
raw_funnel     ───►  stg_*__events    ───► int_sessions       ──► fct_sessions
raw_billing    ───►  stg_*__subs      ───► int_mrr_movements  ──► fct_account_mrr_snapshot
               ───►  stg_*__invoices  ───► int_attribution    ──► dim_users
raw_marketing  ───►  stg_*__spend     ───► int_engagement     ──► dim_accounts
raw_support    ───►  stg_*__tickets   ───► int_account_health ──► dim_date
                     (view, 1:1)           (view, logic)           (table, star)
```

## Source Domains

| Domain | Source | Key Entities |
|--------|--------|-------------|
| Product | `raw_funnel.events` | Page views, signups, activations, feature usage, experiments |
| Billing | `raw_billing.subscriptions` | Trials, upgrades, downgrades, cancellations, MRR |
| Billing | `raw_billing.invoices` | Payments, refunds, line items |
| Marketing | `raw_marketing.spend` | Channel spend, campaigns, impressions, clicks |
| Support | `raw_support.tickets` | Tickets, resolution times, CSAT scores |

## Directory Structure

```
.
├── models/
│   ├── staging/                # 1:1 source shaping (views)
│   │   ├── raw_funnel/         # Product events
│   │   ├── raw_billing/        # Subscriptions + invoices
│   │   ├── raw_marketing/      # Channel spend
│   │   └── raw_support/        # Support tickets
│   ├── intermediate/           # Business logic (views + 1 incremental)
│   │   ├── product/            # Event pipeline, sessions, identity, funnel
│   │   ├── billing/            # Subscription lifecycle, MRR movements
│   │   ├── engagement/         # Engagement states, experiments
│   │   └── cross_domain/       # Attribution, checkout, ticket metrics, health
│   └── marts/                  # Kimball star schema (tables)
│       ├── core/               # Conformed dims + company-level facts
│       ├── product/            # Product analytics
│       ├── billing/            # Billing facts
│       ├── marketing/          # Channel spend facts
│       └── support/            # Support ticket facts
├── tests/
│   ├── invariants/             # PK, not-null, enum checks
│   ├── reconciliation/         # Cross-layer row/value checks
│   ├── fanout/                 # Grain change detection
│   └── contracts/              # Schema contract enforcement
├── macros/                     # Reusable SQL macros
├── seeds/                      # Static reference data
├── docs/                       # Extended documentation
├── analyses/                   # Ad-hoc analytical queries
└── scripts/                    # Utility scripts
```

Additional mart model types: `agg_` (pre-aggregated), `rpt_` (reporting), `mart_` (blended). See `docs/layers/` for full reference.

## Environment Targets

| Target | Dataset | Auth | Use |
|--------|---------|------|-----|
| dev | analytics_dev | OAuth (personal) | Local development |
| ci | analytics_ci | Service account | CI pipeline |
| prod | analytics | Impersonated SA | Production |

## Contributing

1. Create a feature branch (never commit directly to main)
2. Follow conventional commits: `feat:`, `fix:`, `docs:`, `test:`, `refactor:`
3. Test your changes: `dbt build --select state:modified+`
4. Push and open a PR
5. CI runs lint + parse + build + test

## License

MIT
