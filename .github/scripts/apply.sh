#!/usr/bin/env bash
# Init + apply all units in a region (terragrunt run --all), render an apply
# summary into <region>/apply_summary.md, and append it to the step summary.
# Requires terraform and terragrunt on PATH.
#
# Usage: apply-region.sh <region_dir>
set -uo pipefail

REGION="${1:?region required}"

cd "$REGION" || exit 1

echo "Cleaning caches in ${REGION}..."
find . -type d -name ".terraform"          -exec rm -rf {} + 2>/dev/null || true
find . -type d -name ".terragrunt-cache"   -exec rm -rf {} + 2>/dev/null || true
find . -type f -name ".terraform.lock.hcl" -delete         2>/dev/null || true

echo "Initializing all units in ${REGION}..."
terragrunt run --all -- init -no-color -reconfigure || {
  echo "Terragrunt Init FAILED"
  exit 1
}

echo "Applying all units in ${REGION}..."
# -lock-timeout lets a queued apply wait briefly for a releasing lock instead
# of failing immediately on contention.
set -o pipefail
terragrunt run --all -- apply -no-color -auto-approve -input=false -lock-timeout=5m 2>&1 | tee apply_output.txt
exit_code=${PIPESTATUS[0]}

# Strip ANSI escape codes, then pull the run-summary counts.
sed -E "s/\x1b\[([0-9]{1,3}(;[0-9]{1,2})?)?[mGK]//g" apply_output.txt > apply_output_clean.txt

succeeded=$(grep -A 5 "Run Summary" apply_output_clean.txt | grep -E 'Succeeded' | awk '{print $NF}' | tr -d '\r\n')
failed=$(grep -A 5 "Run Summary" apply_output_clean.txt | grep -E 'Failed' | awk '{print $NF}' | tr -d '\r\n')
[ -z "$succeeded" ] && succeeded=0
[ -z "$failed" ] && failed=0

run_url="https://github.com/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}"

{
  echo "### Terragrunt Apply — ${REGION}"
  echo ""
  if [ "$failed" -eq 0 ] && [ "$succeeded" -gt 0 ]; then
    echo "**Status**: Apply Succeeded"
  elif [ "$failed" -gt 0 ]; then
    echo "**Status**: Apply FAILED"
  else
    echo "**Status**: No units applied"
  fi
  echo "**Stats**: $succeeded succeeded, $failed failed"
  echo ""
  echo "[View full Actions log]($run_url)"
  echo ""
  echo "#### Full Terragrunt Output"
  echo ""
  echo '```text'
  cat apply_output_clean.txt
  echo '```'
} > apply_summary.md

cat apply_summary.md >> "$GITHUB_STEP_SUMMARY"

if [ "$exit_code" -ne 0 ]; then
  echo "Terragrunt Apply FAILED with exit code $exit_code"
  exit "$exit_code"
fi
