#!/usr/bin/env bash
set -euo pipefail

# Enforce dbt model naming conventions per CLAUDE.md:
#   staging:      stg_{source}__{entity}
#   intermediate: int_{concept}
#   marts:        fct_|dim_|bridge_|agg_|rpt_|mart_ prefix

EXIT_CODE=0

check_pattern() {
    local dir="$1"
    local pattern="$2"
    local label="$3"

    if [[ ! -d "$dir" ]]; then
        return
    fi

    while IFS= read -r -d '' file; do
        basename="${file##*/}"
        name="${basename%.sql}"
        if ! echo "$name" | grep -qE "$pattern"; then
            echo "FAIL: $file does not match $label pattern ($pattern)"
            EXIT_CODE=1
        fi
    done < <(find "$dir" -name '*.sql' -not -name '_*' -print0)
}

check_pattern "models/staging" '^stg_[a-z]+__[a-z_]+$' "staging"
check_pattern "models/intermediate" '^int_[a-z_]+$' "intermediate"
check_pattern "models/marts" '^(fct|dim|bridge|agg|rpt|mart)_[a-z_]+$' "marts"

if [[ $EXIT_CODE -eq 0 ]]; then
    echo "All model names pass naming conventions."
fi

exit $EXIT_CODE
