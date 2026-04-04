#!/usr/bin/env bash
set -euo pipefail

# Doc-block integrity linter for dbt projects.
# Enforces the no-inline-descriptions convention and validates doc block references.
# See docs/doc-block-convention.md for full convention.
#
# Checks:
#   1. Inline descriptions in _models.yml (ERROR)
#   2. Inline descriptions in _sources.yml (WARNING; ERROR with --strict)
#   3. Inline descriptions in _seeds.yml (WARNING; ERROR with --strict)
#   4. Orphaned doc blocks — defined but never referenced (ERROR)
#   5. Undefined doc references — referenced but never defined (ERROR)
#   6. Missing column descriptions on contracted models (ERROR)
#
# Usage:
#   bash scripts/lint-doc-blocks.sh           # warnings for sources/seeds inline
#   bash scripts/lint-doc-blocks.sh --strict  # all checks are errors
#
# --strict is now enabled in CI and pre-commit (PR #51 landed, inline descriptions fixed).

STRICT=false
for arg in "$@"; do
    case "$arg" in
        --strict) STRICT=true ;;
    esac
done

EXIT_CODE=0
WARN_COUNT=0

# ─── Helper: scan YAML files for inline descriptions ─────────────────────────

check_inline_descriptions() {
    local pattern="$1"    # find -name pattern
    local search_dir="$2" # directory to search
    local severity="$3"   # ERROR or WARN

    while IFS= read -r -d '' file; do
        while IFS= read -r line_info; do
            line_num="${line_info%%:*}"
            line_content="${line_info#*:}"
            if [[ "$severity" == "ERROR" ]]; then
                echo "FAIL: $file:$line_num — inline description found"
                echo "      $line_content"
                EXIT_CODE=1
            else
                echo "WARN: $file:$line_num — inline description found"
                echo "      $line_content"
                WARN_COUNT=$((WARN_COUNT + 1))
            fi
        done < <(grep -nE '^\s+description:\s' "$file" \
            | grep -vE '\{\{.*doc\(' \
            | grep -vE '^\s+description:\s*$' \
            | grep -vE "^\s+description:\s*['\"]?\s*['\"]?\s*$" \
            || true)
    done < <(find "$search_dir" -name "$pattern" -print0 2>/dev/null)
}

# ─── Check 1: Inline descriptions in _models.yml (always ERROR) ──────────────

check_inline_descriptions '_models.yml' 'models' 'ERROR'

# ─── Check 2: Inline descriptions in _sources.yml ────────────────────────────

if [[ "$STRICT" == true ]]; then
    check_inline_descriptions '_sources.yml' 'models' 'ERROR'
else
    check_inline_descriptions '_sources.yml' 'models' 'WARN'
fi

# ─── Check 3: Inline descriptions in _seeds.yml ──────────────────────────────

if [[ "$STRICT" == true ]]; then
    check_inline_descriptions '_seeds.yml' 'seeds' 'ERROR'
else
    check_inline_descriptions '_seeds.yml' 'seeds' 'WARN'
fi

# ─── Check 4 & 5: Orphaned / undefined doc blocks ────────────────────────────

# Collect all {% docs BLOCK_NAME %} definitions from .md files
DEFINED_BLOCKS_FILE=$(mktemp)
REFERENCED_BLOCKS_FILE=$(mktemp)
trap 'rm -f "$DEFINED_BLOCKS_FILE" "$REFERENCED_BLOCKS_FILE"' EXIT

grep -rohE '\{%[[:space:]]*docs[[:space:]]+[A-Za-z0-9_]+' docs/ models/ seeds/ 2>/dev/null \
    | sed 's/.*docs[[:space:]]*//' \
    | sort -u > "$DEFINED_BLOCKS_FILE" || true

# Collect all {{ doc("BLOCK_NAME") }} references from YAML files
grep -roh 'doc("[^"]*")' models/ seeds/ 2>/dev/null \
    | sed 's/^doc("//;s/")$//' \
    | sort -u > "$REFERENCED_BLOCKS_FILE" || true

# Check 4: Find blocks defined but never referenced
while IFS= read -r block; do
    [[ -z "$block" ]] && continue
    def_file=$(grep -rlE "\{%[[:space:]]*docs[[:space:]]+${block}[[:space:]]" docs/ models/ seeds/ 2>/dev/null | head -1)
    echo "FAIL: orphaned doc block '${block}' defined in ${def_file:-unknown} but never referenced"
    EXIT_CODE=1
done < <(comm -23 "$DEFINED_BLOCKS_FILE" "$REFERENCED_BLOCKS_FILE")

# Check 5: Find references to blocks that are never defined
while IFS= read -r block; do
    [[ -z "$block" ]] && continue
    ref_files=$(grep -rl "doc(\"${block}\")" models/ seeds/ 2>/dev/null | head -3 | tr '\n' ', ' | sed 's/,$//')
    echo "FAIL: undefined doc reference '${block}' used in: ${ref_files}"
    EXIT_CODE=1
done < <(comm -13 "$DEFINED_BLOCKS_FILE" "$REFERENCED_BLOCKS_FILE")

# ─── Check 6: Missing column descriptions on contracted models ───────────────
# For models with contract.enforced: true, every column must have a description.

while IFS= read -r -d '' file; do
    while IFS= read -r fail_line; do
        [[ -z "$fail_line" ]] && continue
        echo "$fail_line"
        EXIT_CODE=1
    done < <(awk -v file="$file" '
    /^  - name:/ {
        if (in_columns && col_name != "" && col_has_desc == 0) {
            printf "FAIL: %s: model=%s column=%s — missing description\n", file, model, col_name
        }
        model = $NF
        in_contract = 0
        in_columns = 0
        col_name = ""
        col_has_desc = 0
    }
    /enforced: true/ { in_contract = 1 }
    /^    columns:/ && in_contract {
        in_columns = 1
        next
    }
    /^      - name:/ && in_columns {
        if (col_name != "" && col_has_desc == 0) {
            printf "FAIL: %s: model=%s column=%s — missing description\n", file, model, col_name
        }
        col_name = $NF
        col_has_desc = 0
    }
    /^        description:/ && in_columns && col_name != "" {
        val = $0
        sub(/^        description:[ \t]*/, "", val)
        gsub(/^[ \t]+|[ \t]+$/, "", val)
        if (val != "" && val != "\"\"" && val != "'\'''\''") {
            col_has_desc = 1
        }
    }
    END {
        if (in_columns && col_name != "" && col_has_desc == 0) {
            printf "FAIL: %s: model=%s column=%s — missing description\n", file, model, col_name
        }
    }
    ' "$file" 2>/dev/null || true)
done < <(find models -name '_models.yml' -print0 2>/dev/null)

# ─── Summary ─────────────────────────────────────────────────────────────────

echo ""
if [[ $EXIT_CODE -eq 0 && $WARN_COUNT -eq 0 ]]; then
    echo "All doc-block checks passed."
elif [[ $EXIT_CODE -eq 0 ]]; then
    echo "Doc-block checks passed with ${WARN_COUNT} warning(s)."
    echo "Run with --strict to treat warnings as errors."
else
    echo "Doc-block checks failed."
fi

exit $EXIT_CODE
