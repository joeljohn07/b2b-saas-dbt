#!/usr/bin/env bash
set -euo pipefail

# Migrated from .githooks/pre-commit — blocks commits without corresponding test changes
# Bypass: TDD_BYPASS=1 git commit (for emergency non-functional commits)

if [[ "${TDD_BYPASS:-0}" == "1" ]]; then
    exit 0
fi

STAGED=$(git diff --cached --name-only --diff-filter=ACM)

# Exempt: docs, dbt files (sql/yml/yaml), config, macros, seeds, CI, hooks, scripts
# dbt model changes are validated by dbt schema tests, not Python unit tests
NON_TEST_CHANGES=$(echo "$STAGED" | grep -E -v '(^tests/|(^|/)test_.*\.py$|_test\.py$|\.md$|\.sql$|\.yml$|\.yaml$|^docs/|^\.github/|^\.githooks/|^macros/|^seeds/|^analyses/|^scripts/|^AGENTS\.md$|^CLAUDE\.md$|^decisions\.md$|^llms\.txt$|^\.gitignore$|^\.sqlfluff|^\.pre-commit|^LICENSE$)' || true)
TEST_CHANGES=$(echo "$STAGED" | grep -E '(^tests/|(^|/)test_.*\.py$|_test\.py$)' || true)

if [[ -n "$NON_TEST_CHANGES" && -z "$TEST_CHANGES" ]]; then
    echo "BLOCKED: TDD gate failed — code changes require test changes in the same commit."
    echo "Set TDD_BYPASS=1 only for emergency non-functional commits."
    exit 1
fi
