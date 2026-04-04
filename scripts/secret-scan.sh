#!/usr/bin/env bash
set -euo pipefail

# Migrated from .githooks/pre-commit — blocks commits containing secrets

BLOCKED_PATTERNS=(
    '\.env$'
    '\.env\.'
    '\.secrets/'
    '\.token$'
    '\.key$'
    '\.pem$'
    '\.cookie'
    'downloads/'
    'state\.json'
    '-credentials\.json$'
    '-sa-key\.json$'
    'service.account\.json$'
)

STAGED=$(git diff --cached --name-only --diff-filter=ACM)

for file in $STAGED; do
    for pattern in "${BLOCKED_PATTERNS[@]}"; do
        if echo "$file" | grep -qE -- "$pattern"; then
            echo "BLOCKED: $file matches blocked pattern '$pattern'"
            exit 1
        fi
    done
done

_SECRET_CORE='(api_key|secret_key|password|token|sessionid|private_key|client_secret)[[:space:]]*[=:][[:space:]]*'
if git diff --cached -U0 | grep -iE "${_SECRET_CORE}[\"'][A-Za-z0-9+/=_.-]{8,}" >/dev/null 2>&1; then
    echo "BLOCKED: staged diff contains potential secret"
    exit 1
fi
