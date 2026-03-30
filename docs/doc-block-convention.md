# Doc Block Convention

## No Inline Descriptions

**Every column and model description must use `{{ doc() }}` blocks. No exceptions.**

```yaml
# BAD — inline string
columns:
  - name: user_id
    description: "The unique identifier for a user"

# GOOD — doc block reference
columns:
  - name: user_id
    description: "{{ doc('col_user_id') }}"
```

Enforced by `scripts/lint-doc-blocks.sh` (pre-commit hook) and CI.

## Naming Patterns

| Scope | Pattern | Example |
|-------|---------|---------|
| Shared columns | `col_{column}` | `col_user_id`, `col_currency`, `col__loaded_at` |
| Domain-qualified columns | `col_{domain}_{column}` | `col_invoice_status`, `col_ticket_status` |
| Model descriptions | `{model_name}` | `stg_funnel__events`, `int_events_normalized` |
| Source descriptions | `src_{source}` | `src_billing` |
| Source table descriptions | `src_{source}_{table}` | `src_billing_subscriptions` |
| Seed descriptions | `seed_{seed_name}` | `seed_experiment_metadata` |

## Reuse Rules

- Column flows unchanged through layers: reuse existing `col_` block
- Column transforms or gains new meaning: create new block
- Same column name, different semantics: domain-qualify (`col_{domain}_{column}`)

## File Organization

| File | Contents |
|------|----------|
| `models/staging/staging.md` | Staging source, model, seed, and column descriptions |
| `models/intermediate/intermediate.md` | Intermediate model and column descriptions |
| `models/marts/marts.md` | Marts model and column descriptions |

Each column doc block lives in the layer `.md` file where it first appears.
dbt resolves doc blocks globally, so downstream layers can reference any
block regardless of which file defines it.

## When to Create a New Doc Block

1. New column appears for the first time — create `col_{column}` in the layer's `.md` file where it first appears
2. Existing column name has different meaning in new context — create `col_{domain}_{column}`
3. New model added — create `{model_name}` block in the layer's `.md` file
