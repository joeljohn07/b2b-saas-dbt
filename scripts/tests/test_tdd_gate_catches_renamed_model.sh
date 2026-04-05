#!/usr/bin/env bash
# Test: tdd-gate.sh is invoked on the correct rename filter.
# The gate exempts SQL files (.sql$), macros, seeds, etc. — the common scenario
# we must cover is a rename that drops a .py file from tests/ into an unexempt
# location. With --diff-filter=ACM the rename target is missed entirely.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TDD_GATE="$SCRIPT_DIR/../tdd-gate.sh"

TMPDIR_TEST=$(mktemp -d)
trap 'rm -rf "$TMPDIR_TEST"' EXIT

cd "$TMPDIR_TEST"
git init --quiet --initial-branch=main
git config user.email "test@example.com"
git config user.name "Test"

# Seed: a python module with a corresponding test
mkdir -p src tests
cat > src/thing.py <<'EOF'
def thing():
    return 1
EOF
cat > tests/test_thing.py <<'EOF'
def test_thing():
    assert 1 == 1
EOF
git add src/thing.py tests/test_thing.py
git commit --quiet -m "seed"

# Simulate: rename src/thing.py to src/renamed_thing.py with no test change.
# This is a code change without corresponding test change — gate must block.
git mv src/thing.py src/renamed_thing.py

set +e
unset TDD_BYPASS
output=$(bash "$TDD_GATE" 2>&1)
exit_code=$?
set -e

if [[ $exit_code -eq 0 ]]; then
    echo "FAIL: tdd-gate.sh did not block a renamed code file without test changes"
    echo "Output: $output"
    exit 1
fi

if ! echo "$output" | grep -q "BLOCKED"; then
    echo "FAIL: output did not contain BLOCKED marker"
    echo "Output: $output"
    exit 1
fi

echo "PASS: rename-only code change is blocked by TDD gate"
