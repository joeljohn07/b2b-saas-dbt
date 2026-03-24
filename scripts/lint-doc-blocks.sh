#!/usr/bin/env bash
set -euo pipefail

# Enforce: no inline descriptions in _models.yml files.
# Every description must use {{ doc() }} blocks.
# See docs/doc-block-convention.md for full convention.

EXIT_CODE=0

while IFS= read -r -d '' file; do
    # Find description lines that are NOT {{ doc() }} references.
    # Match: description: "some text" or description: 'some text' or description: some text
    # Skip: description: "{{ doc(...) }}" and empty/blank descriptions
    while IFS= read -r line_info; do
        line_num="${line_info%%:*}"
        line_content="${line_info#*:}"
        echo "FAIL: $file:$line_num — inline description found"
        echo "      $line_content"
        EXIT_CODE=1
    done < <(grep -nE '^\s+description:\s' "$file" \
        | grep -vE '\{\{.*doc\(' \
        | grep -vE '^\s+description:\s*$' \
        | grep -vE "^\s+description:\s*['\"]?\s*['\"]?\s*$" \
        || true)
done < <(find models -name '_models.yml' -print0 2>/dev/null)

if [[ $EXIT_CODE -eq 0 ]]; then
    echo "All descriptions use {{ doc() }} blocks."
fi

exit $EXIT_CODE
