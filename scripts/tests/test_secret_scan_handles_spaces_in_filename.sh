#!/usr/bin/env bash
# Test: secret-scan.sh does not word-split on filenames containing spaces.
# Previous implementation used `for file in $STAGED` which splits on whitespace,
# corrupting filenames like "my notes.txt" into two separate "files".
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECRET_SCAN="$SCRIPT_DIR/../secret-scan.sh"

TMPDIR_TEST=$(mktemp -d)
trap 'rm -rf "$TMPDIR_TEST"' EXIT

cd "$TMPDIR_TEST"
git init --quiet --initial-branch=main
git config user.email "test@example.com"
git config user.name "Test"

echo "# placeholder" > "my notes.md"
git add "my notes.md"

# Non-secret file with spaces should pass cleanly
set +e
output=$(bash "$SECRET_SCAN" 2>&1)
exit_code=$?
set -e

if [[ $exit_code -ne 0 ]]; then
    echo "FAIL: secret-scan.sh incorrectly blocked 'my notes.md'"
    echo "Output: $output"
    exit 1
fi

# Now stage a file with spaces that SHOULD be blocked
git rm --cached "my notes.md" >/dev/null
rm "my notes.md"

echo "secret" > "bad name.env"
git add "bad name.env"

set +e
output=$(bash "$SECRET_SCAN" 2>&1)
exit_code=$?
set -e

if [[ $exit_code -eq 0 ]]; then
    echo "FAIL: secret-scan.sh did not block 'bad name.env'"
    echo "Output: $output"
    exit 1
fi

if ! echo "$output" | grep -q "bad name.env"; then
    echo "FAIL: output did not reference the full filename with space"
    echo "Output: $output"
    exit 1
fi

echo "PASS: filenames with spaces are handled correctly"
