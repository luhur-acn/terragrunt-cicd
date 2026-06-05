#!/usr/bin/env bash
# Run a KICS scan (via Docker) against rendered-tf/, falling back to the whole
# workspace when rendered-tf/ is empty. Results land in security-results/.
# Override the image tag with the KICS_VERSION env var (default: latest).
#
# Usage: run-kics.sh <workspace_dir>
set -uo pipefail

WS="${1:-$GITHUB_WORKSPACE}"
KICS_VERSION="${KICS_VERSION:-latest}"
mkdir -p security-results

# Prefer rendered-tf/ (resolved HCL inputs from plan); otherwise scan workspace.
scan_target="/path/rendered-tf"
if [ ! -d "${WS}/rendered-tf" ] || [ -z "$(ls -A "${WS}/rendered-tf" 2>/dev/null)" ]; then
  echo "WARNING: rendered-tf/ is empty — falling back to workspace scan"
  scan_target="/path"
else
  echo "Scanning rendered-tf/ ($(find "${WS}/rendered-tf" -name '*.tf' | wc -l) .tf files)"
fi

# KICS bundles its queries in the image. exit 0=no findings, 50=findings (both OK).
docker run --rm \
  -v "${WS}:/path" \
  "checkmarx/kics:${KICS_VERSION}" scan \
    -p "$scan_target" \
    --report-formats json \
    -o /path/security-results \
    --output-name kics-results \
    --exclude-paths /path/.git \
    --exclude-paths /path/.github \
    --exclude-paths /path/.terraform \
    --exclude-paths /path/.terragrunt-cache \
    --exclude-paths /path/security-results \
    --ignore-on-exit results \
  2>&1 | tee security-results/kics-scan.log

echo "KICS exit code: ${PIPESTATUS[0]}"
