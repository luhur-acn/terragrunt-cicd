#!/usr/bin/env bash
# Init + plan a single Terragrunt unit, then render a markdown plan summary
# (plan-summary-<safe-dir>.md) inside the unit directory.
# Requires terraform, terragrunt, and tf-summarize on PATH.
#
# Usage: plan-unit.sh <unit_dir>
set -uo pipefail

UNIT_DIR="${1:?unit dir required}"

echo "Cleaning caches in workspace..."
find . -type d -name ".terraform"          -exec rm -rf {} + 2>/dev/null || true
find . -type d -name ".terragrunt-cache"   -exec rm -rf {} + 2>/dev/null || true
find . -type f -name ".terraform.lock.hcl" -delete         2>/dev/null || true

cd "$UNIT_DIR" || exit 1

terragrunt init -reconfigure || exit 1

# Run plan, stream output, capture exit code.
# -lock-timeout lets concurrent runs wait for the state lock instead of failing
# immediately on contention.
set -o pipefail
terragrunt plan -out=tfplan -no-color -lock-timeout=5m 2>&1 | tee plan_output.txt
exit_code=${PIPESTATUS[0]}
if [ "$exit_code" -ne 0 ]; then
  echo "Terragrunt Plan FAILED"
  exit "$exit_code"
fi

# Convert binary plan to JSON for tf-summarize.
terragrunt show -json tfplan > tfplan.json

safe_dir=$(echo "$UNIT_DIR" | tr '/' '-')

{
  echo "### Terragrunt Plan: \`${UNIT_DIR}\`"
  echo ""
  echo "#### Resource Summary"
  tf-summarize -md tfplan.json
  echo ""
  echo "#### Raw Plan Output"
  echo ""
  echo "<details><summary><b>Click to expand</b></summary>"
  echo ""
  echo '```diff'
  sed -E 's/^([[:space:]]+)([-+~])/\2 /' plan_output.txt
  echo '```'
  echo ""
  echo "</details>"
} > "plan-summary-${safe_dir}.md"
