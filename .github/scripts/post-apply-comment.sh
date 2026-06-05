#!/usr/bin/env bash
# Post a region's apply summary to the merged PR (found via the pushed commit).
# Expects GH_TOKEN in the environment.
#
# Usage: post-apply-comment.sh <region_dir>
set -uo pipefail

REGION="${1:?region required}"
summary_file="${REGION}/apply_summary.md"

if [ ! -f "$summary_file" ]; then
  echo "No apply summary file found — skipping PR comment."
  exit 0
fi

pr_number=$(gh pr list --state merged --search "${GITHUB_SHA}" \
  --json number --jq '.[0].number' --repo "${GITHUB_REPOSITORY}" 2>/dev/null || true)

if [ -n "$pr_number" ] && [ "$pr_number" != "null" ]; then
  echo "Posting apply summary to merged PR #$pr_number..."
  gh pr comment "$pr_number" --body-file "$summary_file" --repo "${GITHUB_REPOSITORY}"
else
  echo "No merged PR found for commit ${GITHUB_SHA} — skipping PR comment."
fi
