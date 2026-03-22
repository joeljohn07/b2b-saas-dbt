# Doc Block Convention

## Naming Patterns

| Scope | Pattern | Example |
|-------|---------|---------|
| Shared columns | `col_{column}` | `col_user_id`, `col_currency`, `col__loaded_at` |
| Domain-qualified columns | `col_{domain}_{column}` | `col_invoice_status`, `col_ticket_status` |
| Model descriptions | `{model_name}` | `stg_funnel__events`, `int_events_normalized` |

## Reuse Rules

- Column flows unchanged through layers: reuse existing `col_` block
- Column transforms or gains new meaning: create new block
- Same column name, different semantics: domain-qualify (`col_{domain}_{column}`)

## File Organization

| File | Contents |
|------|----------|
| `docs/columns.md` | Shared column doc blocks |
| `models/staging/staging.md` | Staging model descriptions |
| `models/intermediate/intermediate.md` | Intermediate model descriptions (create when building int layer) |
| `models/marts/marts.md` | Marts model descriptions (create when building marts layer) |

## When to Create a New Doc Block

1. New column appears for the first time — create `col_{column}` in `docs/columns.md`
2. Existing column name has different meaning in new context — create `col_{domain}_{column}`
3. New model added — create `{model_name}` block in the layer's `.md` file
