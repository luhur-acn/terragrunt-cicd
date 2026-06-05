#!/usr/bin/env bash
# Copy resolved Terraform sources + tfvars + plan JSON out of the Terragrunt
# cache into <export_base>/<safe-dir>/ so the security scanners see fully
# rendered configuration rather than raw HCL.
#
# Usage: export-rendered-tf.sh <unit_dir> <export_base>
set -uo pipefail

UNIT_DIR="${1:?unit dir required}"
EXPORT_BASE="${2:?export base required}"

cd "$UNIT_DIR" || exit 0

safe_dir=$(echo "$UNIT_DIR" | tr '/' '-')
dest="${EXPORT_BASE}/${safe_dir}"
mkdir -p "$dest"

echo "Searching for Terragrunt cache working directories containing main.tf..."

# All cache dirs with a main.tf, newest first. Filter out bootstrap/ paths —
# they sort in alphabetically before the real module.
mapfile -t cache_dirs < <(
  find .terragrunt-cache -type f -name "main.tf" -printf "%T@ %h\n" 2>/dev/null \
    | sort -rn | awk '{print $2}' | grep -v '/bootstrap/' | awk '!seen[$0]++'
)

if [ "${#cache_dirs[@]}" -eq 0 ]; then
  echo "WARNING: No cache dirs found (excluding bootstrap). Falling back to all..."
  mapfile -t cache_dirs < <(
    find .terragrunt-cache -type f -name "main.tf" -printf "%T@ %h\n" 2>/dev/null \
      | sort -rn | awk '{print $2}' | awk '!seen[$0]++'
  )
fi

copied=0
for wd in "${cache_dirs[@]}"; do
  echo "  -> Exporting from: $wd"
  ls -la "$wd" 2>/dev/null | head -30

  # Module source files.
  cp "$wd"/*.tf "$dest/" 2>/dev/null && copied=$((copied + 1)) || true

  # Terragrunt auto-generates terraform.tfvars.json with resolved HCL inputs —
  # the key file mapping module variables to their actual values.
  [ -f "$wd/terraform.tfvars.json" ] && \
    cp "$wd/terraform.tfvars.json" "$dest/terraform.tfvars.${copied}.json" && \
    echo "     Copied terraform.tfvars.json" || true

  # Large inventory is delivered via generate as *.auto.tfvars.json (file-based
  # to avoid the TF_VAR_* env-var size limit) — copy those for the scanners too.
  for avt in "$wd"/*.auto.tfvars.json; do
    [ -f "$avt" ] && cp "$avt" "$dest/$(basename "$avt" .json).${copied}.json" && \
      echo "     Copied $(basename "$avt")" || true
  done

  cp "$wd"/*.tfvars "$dest/" 2>/dev/null || true
done

[ "$copied" -eq 0 ] && echo "WARNING: No .tf files copied — scanners will use raw source."
[ -f "tfplan.json" ] && cp tfplan.json "$dest/" && echo "Copied tfplan.json"

echo "Export complete. Contents:"
ls -la "$dest"
