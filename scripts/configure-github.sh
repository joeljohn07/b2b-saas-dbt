#!/usr/bin/env bash
set -euo pipefail

# One-time repo settings for joeljohn07/b2b-saas-dbt
# Run: bash scripts/configure-github.sh

REPO="joeljohn07/b2b-saas-dbt"

echo "Configuring repo settings..."
gh api repos/"$REPO" \
  --method PATCH \
  --field allow_squash_merge=true \
  --field allow_merge_commit=false \
  --field allow_rebase_merge=false \
  --field delete_branch_on_merge=true \
  --field squash_merge_commit_title=PR_TITLE \
  --field squash_merge_commit_message=PR_BODY \
  --silent

echo "Configuring branch protection on main..."
gh api repos/"$REPO"/branches/main/protection \
  --method PUT \
  --input - <<'JSON'
{
  "required_status_checks": {
    "strict": false,
    "contexts": ["Lint", "Build & Validate"]
  },
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "required_approving_review_count": 0
  },
  "restrictions": null
}
JSON

echo "Done. Verify:"
echo "  gh api repos/$REPO --jq '.allow_squash_merge, .allow_merge_commit, .delete_branch_on_merge'"
echo "  gh api repos/$REPO/branches/main/protection --jq '.required_status_checks.contexts'"
