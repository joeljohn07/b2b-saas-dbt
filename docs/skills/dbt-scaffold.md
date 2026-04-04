# dbt-scaffold

Generate a new model with all conventions applied. Do ALL steps automatically without asking:

1. **Parse arguments** — `$ARGUMENTS` format: `<layer> <model_name>` (e.g., `intermediate int_billing_payments_prep`)
   - If missing, ask for layer and model name

2. **Validate:**
   - Layer must be staging, intermediate, or marts
   - Model name must match naming convention for that layer (run through `scripts/lint-model-names.sh` pattern)
   - Determine subdirectory using the lookup below (do not infer from name):

   **Intermediate subdirectory lookup** (subdirectory provides domain context — names are not prefixed):
   | Subdirectory | Models belong here when they deal with... |
   |---|---|
   | `product/` | event normalization, sessions, identity stitching, funnel staging, account memberships |
   | `billing/` | subscription lifecycle, MRR movements |
   | `engagement/` | engagement states, experiment results, experiment metadata |
   | `cross_domain/` | attribution, checkout conversion, ticket metrics, account health, invoice prep, marketing spend prep |

   If the new model's domain is ambiguous, ask the user which subdirectory before generating.

   **Staging subdirectory lookup:**
   | Subdirectory | Source system |
   |---|---|
   | `funnel/` | product events |
   | `billing/` | subscriptions + invoices |
   | `marketing/` | marketing spend |
   | `support/` | support tickets |

   **Marts subdirectory lookup:**
   | Subdirectory | Models belong here when... |
   |---|---|
   | `core/` | conformed dimensions + cross-domain facts (retention) |
   | `product/` | product analytics facts + session/experiment dims |
   | `billing/` | billing facts |
   | `marketing/` | channel spend facts |
   | `support/` | support ticket facts |

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
