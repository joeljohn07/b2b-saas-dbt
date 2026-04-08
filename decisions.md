# Decision Log — b2b-saas-dbt

## 2026-03-12: Initial setup
- Project created and scaffolded
- Description: Full-company analytics platform with dbt on BigQuery
- Repo: https://github.com/joeljohn07/b2b-saas-dbt

## 2026-03-13: Architecture contract + tiered agent instructions
- Rewrote CLAUDE.md with dbt-specific three-layer architecture contract
- Created directory-level CLAUDE.md for staging, intermediate, marts, tests (Tier 1)
- Rewrote README.md with architecture diagram, source domains, environment targets
- Created Tier 2 doc stubs in docs/layers/
- Updated llms.txt with dbt references

## 2026-03-21: Expanded conventions
- Added mart prefixes: agg_ (coarser grain), rpt_ (dashboard-specific), mart_ (dim+fact blend)
- Added intermediate suffixes: _prep (source-specific prep), _unioned (multi-source union)
- Retired exp_ prefix / export layer concept — rpt_ within marts replaces it
- Added column naming consistency as hard rule
- Added SQL style: group by all, union all by name
- Adopted subdirectories within layers (source/domain/business-area)
- Adopted per-directory _models.yml YAML layout convention
- Populated docs/layers/ stubs with full layer contract and dimensional modeling guidelines

## 2026-03-22: Staging model for raw_funnel events
**PR:** #28
**Why:** First source domain needed a staging model to decouple raw source names from dbt model names
**What changed:** Added `stg_funnel__events` staging model + _sources.yml for funnel domain

## 2026-03-22: Complete staging layer — all five source domains
**PR:** #29
**Why:** Full source coverage needed before intermediate layer could begin; also resolved naming friction
**What changed:** Added staging models for billing, marketing, support. Dropped `raw_` prefix from dbt source names — `schema:` config in dbt decouples source names from BigQuery dataset names

## 2026-03-22: SQLFluff linting and pre-commit hooks
**PR:** #30
**Why:** Enforce consistent SQL style automatically before any code reaches review
**What changed:** Added .sqlfluff config, pre-commit hooks for SQLFluff + dbt parse

## 2026-03-22: CI pipeline, schema isolation, and WIF auth
**PR:** #31
**Why:** Needed isolated CI builds that don't pollute dev/prod datasets; keyless auth preferred over service account key files in CI secrets
**What changed:** GitHub Actions CI pipeline with Workload Identity Federation (WIF) over service account key file; per-PR BigQuery dataset namespace (`analytics_ci_{PR_NUMBER}`) for complete CI isolation

## 2026-03-22: PR template, doc block convention, repo settings
**PR:** #32
**Why:** Standardise contribution quality and surface doc block requirements at PR creation time
**What changed:** PR template with checklist, doc block convention documented in `docs/doc-block-convention.md`, branch protection rules

## 2026-03-23: Tier 1 intermediate models and doc block migration
**PR:** #33
**Why:** Business logic belongs in intermediate layer — staging models should be 1:1 source shaping only
**What changed:** First batch of intermediate models (event prep, deduplication). Migrated all inline descriptions to `{{ doc() }}` blocks; view materialization for all intermediate models (table only if query proves too heavy)

## 2026-03-23: Identity stitching, account memberships, MRR movements
**PR:** #34
**Why:** Identity resolution and MRR movement tracking are foundational — all downstream funnel and billing models depend on them
**What changed:** `int_identity_stitched` with `greatest(transition_time - 90d, prev_transition_time)` lookback guard to prevent unbounded interval explosion; `int_account_memberships`; `int_mrr_movements`

## 2026-03-23: Sessions, funnel staging, and attribution models
**PR:** #35
**Why:** Session boundaries and attribution are locked business logic — agreed once, never re-derived per model
**What changed:** `int_sessions` (1800s inactivity threshold for sessionization — not 30 min integer, which loses BQ timestamp precision); `int_funnel_staged`; `int_attribution`

## 2026-03-23: Engagement states and experiment results models
**PR:** #36
**Why:** Engagement scoring and experiment exposure tracking needed before marts could be built
**What changed:** `int_engagement_states`, `int_experiment_results`

## 2026-03-23: Checkout conversion and account health models
**PR:** #37
**Why:** Checkout funnel and account health are cross-domain — they belong in intermediate before mart assembly
**What changed:** `int_checkout_conversion`, `int_account_health`

## 2026-03-23: CI test fixes, restore lost YAML, doc block cleanup
**PR:** #38
**Why:** Incremental build-out exposed missing YAML definitions and residual inline descriptions
**What changed:** Fixed CI test failures, restored missing _models.yml entries, cleared remaining inline descriptions

## 2026-03-24: CI dataset isolation per-PR (not per-run)
**PR:** #39
**Why:** `github.run_id` causes separate datasets for re-runs of the same PR, breaking incremental state comparisons
**What changed:** CI dataset key changed to `PR_NUMBER`; added `github.run_id` fallback for non-PR runs (e.g., push to main) to prevent namespace collisions

## 2026-03-24: Tiered instruction system
**PR:** #40
**Why:** Agents working on different layers need layer-specific rules without loading the full project context; portability also requires docs committed in-repo
**What changed:** Five-file CLAUDE.md hierarchy (root + staging + intermediate + marts + tests); skills moved to `docs/skills/` (in-repo, not `~/.claude/commands/`)

## 2026-03-25: Marts dimension models, seeds, bridge table
**PR:** #41
**Why:** Conformed dimensions are the spine of the star schema — needed before any fact tables
**What changed:** `dim_users` (SCD Type 1 — latest membership wins), `dim_accounts`, `dim_date`, `dim_channels`, `dim_experiments`; `dim_date` as static seed (2024–2029) rather than a spine macro (simpler, no macro dependency); `bridge_user_experiments`; `farm_fingerprint()` used for all surrogate keys throughout (BQ-native INT64, no UUID overhead). Note: `bridge_account_users` was originally scoped but dropped in favour of the membership spine in `int_account_memberships`

## 2026-03-25: Simple fact tables
**PR:** #42
**Why:** Core product analytics facts to back the product dashboard
**What changed:** `fct_sessions`, `fct_signups`, `fct_activations`, `fct_feature_usage`, `fct_marketing_spend`, `fct_support_tickets`

## 2026-03-25: Billing facts and experiment exposures
**PR:** #43
**Why:** Revenue and experiment tracking complete the mart layer
**What changed:** `fct_mrr_movements`, `fct_subscriptions`, `fct_invoices`, `fct_experiment_exposures`

## 2026-03-25: Retention cohorts and cross-model FK tests
**PR:** #44
**Why:** Retention is a cross-domain concern; pre-computing in dbt avoids repeated Lightdash queries on large cohort tables
**What changed:** `fct_retention_cohorts` with 7-day `is_period_complete` buffer guard (prevents incomplete trailing cohorts); FK relationship tests across mart models

## 2026-03-30: Convention drift fix
**PR:** #51
**Why:** Several intermediate models had accumulated naming drift as the layer grew — `int_{domain}_{concept}` was inconsistent with the rule that subdirectory provides domain context
**What changed:** Renamed all intermediate models to `int_{concept}` (without domain prefix); updated all downstream refs

## 2026-03-30: persist_docs
**PR:** #52
**Why:** Column descriptions were not propagating to BigQuery metadata, making the data catalog unusable
**What changed:** Added `persist_docs: columns: true` globally in dbt_project.yml

## 2026-03-30: Logic bug fixes in intermediate models
**PR:** #53
**Why:** Several intermediate models had incorrect logic discovered during marts review
**What changed:** Fixed bugs in identity stitching, MRR movement calculation, and attribution window logic

## 2026-03-30: Expand doc-block linter
**PR:** #54
**Why:** Linter was only catching inline descriptions in _models.yml; orphaned doc blocks in docs.md files and broken doc() references were going undetected
**What changed:** `scripts/lint-doc-blocks.sh` extended with orphan detection and broken reference checking; integrated into CI

## 2026-03-30: Generic test deprecation warnings (63 warnings resolved)
**PR:** #55
**Why:** dbt 1.11 deprecated the `tests:` key in favour of `data_tests:` — 63 warnings were cluttering CI output
**What changed:** Partial migration of `tests:` to `data_tests:` in _models.yml files — 63 deprecation warnings resolved but ~311 `tests:` blocks remain across 13 files. Full migration tracked separately

## 2026-03-30: int_events_normalized incremental
**PR:** #56
**Why:** Full-refresh on the events table is expensive at scale; deduplication logic was also running on already-clean data
**What changed:** `int_events_normalized` converted to incremental materialization with merge strategy on `event_id`; 36h `_loaded_at` lookback window (not `event_time`) to catch late-arriving duplicates without reprocessing the full table

## 2026-03-30: Source freshness CI + staging volume test
**PR:** #57
**Why:** CI was not alerting on stale source data or complete data drops in staging
**What changed:** `dbt source freshness` added as a CI step; `assert_staging_events_min_volume` singular test guards against empty staging loads

## 2026-04-05: Test-harness repair + CI guardrails
**PR:** #79-linked
**Why:** Several safety nets did not test what they claimed. The reconciliation dedup-rate test false-greened on an empty sample window (divide-by-zero → null → dropped by WHERE). Fixture dedup tests re-implemented `int_events_normalized`'s partition/order expression inline, so a change to the real model's dedup logic would not be caught. CI was not tearing down the `_fixtures` dataset, cache key referenced the wrong packages file, and pip installs were not using the pinned requirements file. Shell gates used `--diff-filter=ACM`, missing rename-based bypasses, and word-split on filenames with spaces.
**What changed:**
- Reconciliation test now fails when `staging_count = 0` and uses a dedicated `reconciliation_dedup_test_window_days` var (separate from the model's 36h incremental lookback).
- Added `dedup_events_row_number()` macro — `int_events_normalized` and all fixture dedup tests now share a single canonical expression.
- Added `invariants_stg_billing_cancellation_mrr_zero` to encode the hidden assumption that `int_mrr_movements` churn math depends on.
- CI now installs from `requirements-ci.txt`, caches off `package-lock.yml`, tears down the `_fixtures` dataset, and drops the duplicate staging build.
- `secret-scan.sh` and `tdd-gate.sh` switched to `--diff-filter=ACMR` and NUL-safe line iteration.
- Added shell test harness under `scripts/tests/` wired into CI.

## 2026-04-05: Product-layer lookback windows moved to vars
**PR:** #82 (issue #81)
**Why:** The incremental lookback in `int_events_normalized` (36h) and the stitch window in `int_identity_stitched` (90d) were hardcoded intervals scattered across the SQL. Both are business-policy levers — the 36h window reflects the late-arrival SLA for the event pipeline, and the 90d window is the documented bound on anon→user stitching. Having the constants inline meant changing them required a model edit rather than a config edit, and the rationale only lived in commit history.
**What changed:**
- Added `events_incremental_lookback_hours: 36` and `identity_stitching_lookback_days: 90` to `dbt_project.yml` under the locked business-rule vars.
- `int_events_normalized.sql` and `int_identity_stitched.sql` now reference the vars instead of literal intervals.
- Added boundary fixtures `fixture_events_late_arrivals_extreme` and `fixture_identity_stitch_window_edge` with matching invariant tests that exercise the var-driven cutoff expressions — tripwires fire if the vars change without the tests being updated.
- `int_sessions.sql` received a doc comment flagging that anonymous sessions emit null `stitched_user_id` by design and will require a contract relaxation in the downstream mart.

## 2026-04-08: Cross-domain correctness fixes
**PR:** #84 (issue #83)
**Why:** Five intermediate models had correctness bugs affecting join grain, filter predicates, and window anchoring — surfaced during a structured review pass.
**What changed:**
- `int_subscription_lifecycle`: added `subscription_id` to the `lag()` PARTITION BY to prevent cross-subscription day-gap pollution on multi-sub accounts.
- `int_checkout_conversion`: joined on `(account_id, user_id)` instead of `account_id` alone to eliminate multi-user fanout; filtered null `user_id` checkout events; replaced hardcoded `interval 30 day` with `checkout_conversion_window_days` var.
- `int_experiment_results`: moved `experiment_flags is not null` filter from the base CTE to the unnest-only CTE, so activation events without flag payloads are found by the conversion join.
- `int_engagement_states`: anchored `days_since_last_activity` and threshold comparisons to `snapshot_week_end` (week_start + 6) instead of `snapshot_week_start`, fixing a negative-delta bug for mid/late-week activity.
- `int_account_health`: split the billing CTE into `billing_latest` (all-time, for `has_active_sub`) and `billing_recent` (28-day window, for `last_billing_event`), so annual subscriptions are no longer dropped from the active-sub flag.
- Documented `is_paid` semantics: option B (false for refunded invoices = recognized revenue, not payment history); updated `col_is_paid` doc block.
- Added 5 model-level invariant tests and 1 `is_paid` consistency test.

## 2026-04-08: Mart grain, contract alignment, and cross-field invariants
**PR:** #86 (issue #85)
**Why:** Mart-layer models had grain bugs, FK/contract mismatches against upstream SQL nullability, and missing cross-field invariants — surfaced during a structured review pass.
**What changed:**
- `fct_activations`: PK changed from `farm_fingerprint(user_id)` to `farm_fingerprint(concat(user_id, '|', date))` so the surrogate key is distinct from the FK `user_key`.
- `fct_sessions`: relaxed `not_null` on `user_id`/`user_key` to allow anonymous sessions through. FK test scoped to non-null keys only.
- `fct_feature_usage`: added `where user_id is not null` filter — anonymous feature events are low-signal and the contract requires not_null.
- `dim_accounts`: added support tickets to the account union; filtered acquisition attribution by `valid_from` to exclude pre-membership activations.
- `dim_users`: extended to include billing + support user_ids. Added `is_product_user`, `is_billing_user`, `is_support_user` boolean columns for downstream source-aware filtering.
- `fct_retention_cohorts`: replaced hardcoded 7-day maturity guard with `retention_maturity_guard_days` var.
- Added 5 cross-field mart invariant tests: MRR delta arithmetic, refund-implies-amount, resolved-has-time, dim_users source coverage, dim_accounts source coverage.

## 2026-04-09: Documentation drift and config corrections
**PR:** #88
**Why:** README, decisions.md, fixture descriptions, and package declarations had drifted from the actual codebase state
**What changed:**
- README: marts count 19→17 (seeds are not mart models), Python version 3.10→3.12 (matches CI), clarified dim_date/experiment_metadata as seeds
- `fixture_events_backfill_replay` description corrected: "latest wins" → "earliest wins" (matches code and test)
- `packages.yml`: added missing `dbt_date` dependency (present in `package-lock.yml` but absent from manifest)
- `decisions.md` PR #41: corrected `bridge_account_users` → `bridge_user_experiments` (bridge_account_users was scoped but never built)
- `decisions.md` PR #55: corrected `tests:` → `data_tests:` migration claim (partial, not complete)
- `retention_rate` doc block: added null case for zero-denominator cohorts
- Created `assets/` directory (referenced by `asset-paths` in dbt_project.yml)
- Removed empty `macros/governance/` directory
