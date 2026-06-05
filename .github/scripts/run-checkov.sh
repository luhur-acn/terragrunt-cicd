#!/usr/bin/env bash
# Two-pass Checkov scan via Docker, then merge every report into
# results_json.json:
#   Pass 1 — rendered-tf/      (terraform framework: .tf + resolved tfvars)
#   Pass 2 — each tfplan.json  (terraform_plan framework: fully resolved values)
# Override the image tag with CHECKOV_VERSION (default: latest).
#
# Usage: run-checkov.sh <workspace_dir>
set -uo pipefail

WS="${1:-$GITHUB_WORKSPACE}"
CHECKOV_VERSION="${CHECKOV_VERSION:-latest}"
IMG="bridgecrew/checkov:${CHECKOV_VERSION}"
mkdir -p security-results

# Run checkov in its official container. The workspace is mounted at /tf, so all
# paths passed to checkov are /tf-relative. HOME is set to a writable dir.
checkov_run() {
  docker run --rm -e HOME=/tmp -v "${WS}:/tf" "$IMG" "$@"
}

echo "Checkov image: $IMG"

# ── Pass 1: rendered-tf/ (terraform framework) ──────────────────────────────
if [ -d "rendered-tf" ] && [ -n "$(ls -A rendered-tf 2>/dev/null)" ]; then
  echo "Pass 1: Scanning rendered-tf/ (terraform framework)"
  checkov_run \
    --directory /tf/rendered-tf \
    --framework terraform \
    --output json \
    --output-file-path /tf/security-results \
    --soft-fail \
    --quiet \
    2>&1 | tee security-results/checkov-rendered.log
  mv security-results/results_json.json security-results/results_rendered.json 2>/dev/null || true
else
  echo "Pass 1 skipped: rendered-tf/ is empty"
fi

# ── Pass 2: each tfplan.json (terraform_plan framework) ─────────────────────
plan_files=$(find rendered-tf -name "tfplan.json" 2>/dev/null | head -20)
if [ -n "$plan_files" ]; then
  echo "Pass 2: Scanning tfplan.json files (terraform_plan framework)"
  while IFS= read -r plan; do
    safe_name=$(echo "$plan" | tr '/' '-')
    checkov_run \
      --file "/tf/${plan}" \
      --framework terraform_plan \
      --output json \
      --output-file-path /tf/security-results \
      --soft-fail \
      --quiet \
      2>&1 | tee -a security-results/checkov-plan.log
    mv security-results/results_json.json "security-results/results_plan_${safe_name}.json" 2>/dev/null || true
  done <<< "$plan_files"
else
  echo "Pass 2 skipped: no tfplan.json found in rendered-tf/"
fi

# ── Merge all results_*.json into results_json.json (jq) ────────────────────
# Each input is a single report (object) or a list of reports; flatten to one
# array. Exclude results_json.json itself so a stale copy can't self-merge.
mapfile -t report_files < <(
  find security-results -maxdepth 1 -name "results_*.json" ! -name "results_json.json" 2>/dev/null
)
if [ "${#report_files[@]}" -gt 0 ]; then
  jq -s 'reduce .[] as $f ([]; . + (if ($f | type) == "array" then $f else [$f] end))' \
    "${report_files[@]}" > security-results/results_json.json
  echo "Merged ${#report_files[@]} report file(s) into results_json.json"
else
  echo "[]" > security-results/results_json.json
  echo "No Checkov report files to merge."
fi
