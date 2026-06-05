#!/usr/bin/env bash
# Combine the per-unit plan summaries and the security summary into a single
# final-summary.md, then post it as a PR comment (or print it if no PR found).
# Expects GH_TOKEN in the environment; PR_NUMBER optional (falls back to lookup).
set -uo pipefail

repo="${GITHUB_REPOSITORY}"
pr_number="${PR_NUMBER:-}"

{
  echo "## 🚀 Terragrunt Plan Results"
  echo ""
  echo "Plan results for infrastructure units affected by this Pull Request:"
  echo ""

  if ls plan-summary-*.md >/dev/null 2>&1; then
    for file in plan-summary-*.md; do
      cat "$file"
      echo ""
      echo "---"
      echo ""
    done
  else
    echo "> ℹ️ No Terragrunt units were affected by this PR (or plan job was skipped)."
    echo ""
    echo "---"
    echo ""
  fi

  if [ -f "security-results/security-summary.md" ]; then
    cat "security-results/security-summary.md"
  else
    echo "## 🔒 Security Scan Results"
    echo ""
    echo "> ⚠️ Security scan results not available — check the Actions log for details."
  fi
} > final-summary.md

if [ -z "$pr_number" ]; then
  pr_number=$(gh pr list --head "${GITHUB_REF_NAME}" --json number --jq '.[0].number' \
    --repo "$repo" 2>/dev/null || true)
fi

if [ -n "$pr_number" ] && [ "$pr_number" != "null" ]; then
  echo "Posting comment to PR #$pr_number..."
  gh pr comment "$pr_number" --body-file final-summary.md --repo "$repo"
else
  echo "No open PR found for branch ${GITHUB_REF_NAME} — printing summary:"
  cat final-summary.md
fi
