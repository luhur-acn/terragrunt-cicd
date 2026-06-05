#!/usr/bin/env bash
# Best-effort removal of stale S3 state locks for every Terragrunt unit found
# under ROOT_DIR. Intended for the failure/cancellation cleanup path only.
# Never fails the job (no `set -e`).
#
# Usage: cleanup-state-lock.sh <root_dir>
set -uo pipefail

ROOT_DIR="${1:?root dir required}"

find_hcl() {
  local name=$1 cur=$2
  cur=${cur#./}; cur=${cur#/}
  while [ -n "$cur" ] && [ "$cur" != "." ] && [ "$cur" != "/" ]; do
    [ -f "$cur/$name" ] && { echo "$cur/$name"; return 0; }
    cur=$(dirname "$cur")
  done
  [ -f "$name" ] && { echo "$name"; return 0; }
  return 1
}

unit_dirs=$(find "$ROOT_DIR" -name "terragrunt.hcl" -printf '%h\n' 2>/dev/null | sort -u)
[ -z "$unit_dirs" ] && { echo "No Terragrunt units under $ROOT_DIR."; exit 0; }

while IFS= read -r dir; do
  [ -z "$dir" ] && continue
  clean=${dir#./}; clean=${clean#/}
  echo "--- Checking lock for: $clean ---"

  account_hcl=$(find_hcl "account.hcl" "$clean") || { echo "Cannot find account.hcl"; continue; }
  region_hcl=$(find_hcl "region.hcl" "$clean")   || { echo "Cannot find region.hcl";  continue; }

  account_id=$(grep -E 'account_id\s*=' "$account_hcl" | sed -E 's/.*=\s*"([^"]+)".*/\1/' | tr -d '\r')
  aws_region=$(grep -E 'aws_region\s*=' "$region_hcl"  | sed -E 's/.*=\s*"([^"]+)".*/\1/' | tr -d '\r')
  [ -z "$account_id" ] || [ -z "$aws_region" ] && { echo "Cannot parse account/region"; continue; }

  bucket="terragrunt-state-${account_id}-${aws_region}"
  lock_key="${clean}/terraform.tfstate.tflock"
  lock_uri="s3://${bucket}/${lock_key}"

  if aws s3api head-object --bucket "$bucket" --key "$lock_key" --region "$aws_region" >/dev/null 2>&1; then
    echo "S3 state lock detected at $lock_uri — attempting removal..."
    lock_uuid=$(aws s3 cp "$lock_uri" - --region "$aws_region" 2>/dev/null | jq -r '.ID' 2>/dev/null || true)
    if [ -n "$lock_uuid" ] && [ "$lock_uuid" != "null" ]; then
      ( cd "$clean" && terragrunt force-unlock -force "$lock_uuid" ) \
        || aws s3 rm "$lock_uri" --region "$aws_region"
    else
      aws s3 rm "$lock_uri" --region "$aws_region"
    fi
    echo "State lock removed for $clean."
  else
    echo "No active state lock for $clean."
  fi
done <<< "$unit_dirs"
