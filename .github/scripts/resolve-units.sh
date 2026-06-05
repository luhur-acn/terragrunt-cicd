#!/usr/bin/env bash
# Map changed file paths (read from stdin, one per line) up to the nearest
# ancestor directory that contains the given marker file, then emit a compact
# JSON array of the unique matching directories.
#
# Used by both workflows: marker "terragrunt.hcl" detects changed units (plan),
# marker "region.hcl" detects changed regions (apply).
#
# Usage: <something producing paths> | resolve-units.sh <marker_filename>
set -uo pipefail

MARKER="${1:?marker filename required}"

valid=""
while IFS= read -r path; do
  [ -z "$path" ] && continue
  case "$path" in
    environments/*) ;;
    *) continue ;;
  esac

  dir=$(dirname "$path")
  while [ -n "$dir" ] && [ "$dir" != "." ] && [ "$dir" != "/" ] && [ "$dir" != "environments" ]; do
    if [ -f "$dir/$MARKER" ]; then
      valid="${valid}${dir}"$'\n'
      break
    fi
    dir=$(dirname "$dir")
  done
done

printf '%s' "$valid" | sort -u | jq -R -s -c 'split("\n") | map(select(length > 0))'
