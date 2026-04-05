#!/usr/bin/env bash
# Test: secret-scan.sh blocks when a benign file is renamed to a blocked pattern.
# A rename is represented in `git diff --cached --name-only` differently depending
# on --diff-filter. The script should surface the renamed destination path.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECRET_SCAN="$SCRIPT_DIR/../secret-scan.sh"

TMPDIR_TEST=$(mktemp -d)
trap 'rm -rf "$TMPDIR_TEST"' EXIT

cd "$TMPDIR_TEST"
git init --quiet --initial-branch=main
git config user.email "test@example.com"
git config user.name "Test"

echo "notes" > notes.txt
git add notes.txt
git commit --quiet -m "seed"

# Rename benign file to a blocked pattern (.env)
git mv notes.txt .env.local

# secret-scan.sh must block this rename
set +e
output=$(bash "$SECRET_SCAN" 2>&1)
exit_code=$?
set -e

if [[ $exit_code -eq 0 ]]; then
    echo "FAIL: secret-scan.sh did not block a rename to .env.local"
    echo "Output: $output"
    exit 1
fi

if ! echo "$output" | grep -q "BLOCKED"; then
    echo "FAIL: output did not contain BLOCKED marker"
    echo "Output: $output"
    exit 1
fi

echo "PASS: renamed secret file is blocked"
