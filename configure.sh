#!/usr/bin/env bash
# configure.sh — repoint this repo at a new AWS account (and optionally a new
# profile / region) in one shot. Built for Pluralsight sandboxes, where the
# account ID changes every time you spin up a new sandbox.
#
# It reads the CURRENT values from live/*/account.hcl (the source of truth),
# discovers every file that references the old account ID, and rewrites them —
# so the hardcoded copies in bootstrap/*.tf and .github/workflows/*.yml stay in
# sync with account.hcl, not just the Terragrunt-interpolated ones.
#
# Usage:
#   ./configure.sh                         # auto-detect new account from AWS creds
#   ./configure.sh 123456789012            # set new account explicitly
#   ./configure.sh 123456789012 --profile sandbox --region us-west-2
#   ./configure.sh --repo my-org/my-repo   # repoint the OIDC trust to a new repo
#   ./configure.sh --dry-run               # preview changes, write nothing
#
# Options:
#   --profile NAME      Also replace the AWS profile name everywhere.
#   --region  NAME      Also replace the AWS region everywhere (use with care).
#   --repo  OWNER/NAME  Also replace the GitHub repo in the OIDC trust policy.
#   --from    ID        Override the detected old account ID.
#   -n, --dry-run       Show what would change without writing.
#   -h, --help          This help.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

# ── pretty output ─────────────────────────────────────────────────────────────
if [ -t 1 ]; then BOLD=$'\e[1m'; RED=$'\e[31m'; GRN=$'\e[32m'; YEL=$'\e[33m'; DIM=$'\e[2m'; RST=$'\e[0m'
else BOLD=""; RED=""; GRN=""; YEL=""; DIM=""; RST=""; fi
info()  { echo "${GRN}▸${RST} $*"; }
warn()  { echo "${YEL}!${RST} $*" >&2; }
die()   { echo "${RED}✗${RST} $*" >&2; exit 1; }

# ── args ──────────────────────────────────────────────────────────────────────
NEW_ACCOUNT=""; NEW_PROFILE=""; NEW_REGION=""; NEW_REPO=""; OLD_OVERRIDE=""; DRY_RUN=0
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)    grep -E '^#' "$0" | sed '1d; s/^# \{0,1\}//'; exit 0 ;;
    -n|--dry-run) DRY_RUN=1; shift ;;
    --profile)    NEW_PROFILE="${2:?--profile needs a value}"; shift 2 ;;
    --region)     NEW_REGION="${2:?--region needs a value}"; shift 2 ;;
    --repo)       NEW_REPO="${2:?--repo needs a value}"; shift 2 ;;
    --from)       OLD_OVERRIDE="${2:?--from needs a value}"; shift 2 ;;
    -*)           die "Unknown option: $1" ;;
    *)            [ -z "$NEW_ACCOUNT" ] && NEW_ACCOUNT="$1" || die "Unexpected arg: $1"; shift ;;
  esac
done

[ -n "$NEW_REPO" ] && { [[ "$NEW_REPO" == */* ]] || die "--repo must be OWNER/NAME, got: '$NEW_REPO'"; }

# ── locate the source of truth ────────────────────────────────────────────────
ACCOUNT_HCL=$(find live -name account.hcl 2>/dev/null | head -1 || true)
[ -n "$ACCOUNT_HCL" ] || die "Could not find live/*/account.hcl — run this from the repo root."

hcl_value() { # hcl_value <key> <file> → value of `key = "value"`
  grep -E "^[[:space:]]*$1[[:space:]]*=" "$2" 2>/dev/null | head -1 \
    | sed -E 's/.*=[[:space:]]*"([^"]*)".*/\1/' | tr -d '\r'
}

OLD_ACCOUNT="${OLD_OVERRIDE:-$(hcl_value account_id "$ACCOUNT_HCL")}"
OLD_PROFILE="$(hcl_value aws_profile "$ACCOUNT_HCL")"
REGION_HCL=$(find live -name region.hcl 2>/dev/null | head -1 || true)
OLD_REGION="$([ -n "$REGION_HCL" ] && hcl_value aws_region "$REGION_HCL" || true)"

# Old GitHub repo (OWNER/NAME) from the OIDC trust policy: "repo:OWNER/NAME:*".
OIDC_TF=$(find bootstrap -name oidc.tf 2>/dev/null | head -1 || true)
OLD_REPO="$([ -n "$OIDC_TF" ] && grep -oE 'repo:[^:"]+' "$OIDC_TF" | head -1 | sed 's/^repo://' || true)"
[ -n "$NEW_REPO" ] && [ -z "$OLD_REPO" ] && die "--repo given but couldn't find an existing repo in bootstrap/oidc.tf."

[ -n "$OLD_ACCOUNT" ] || die "Could not read current account_id from $ACCOUNT_HCL (use --from)."

# ── determine the new account ─────────────────────────────────────────────────
# Are we changing anything besides the account? If so, a missing account is
# non-fatal — we just leave it unchanged.
HAS_OTHER_REPL=""
if [ -n "$NEW_REPO" ] || [ -n "$NEW_PROFILE" ] || [ -n "$NEW_REGION" ]; then HAS_OTHER_REPL=1; fi

PROFILE_FOR_LOOKUP="${NEW_PROFILE:-$OLD_PROFILE}"
if [ -z "$NEW_ACCOUNT" ]; then
  info "No account ID given — detecting from AWS creds (profile: ${BOLD}${PROFILE_FOR_LOOKUP:-default}${RST})..."
  if command -v aws >/dev/null 2>&1; then
    NEW_ACCOUNT="$(aws sts get-caller-identity \
                     ${PROFILE_FOR_LOOKUP:+--profile "$PROFILE_FOR_LOOKUP"} \
                     --query Account --output text 2>/dev/null || true)"
  fi
  if ! [[ "$NEW_ACCOUNT" =~ ^[0-9]{12}$ ]]; then
    if [ -n "$HAS_OTHER_REPL" ]; then
      warn "Could not detect a new account — leaving the account unchanged."
      NEW_ACCOUNT="$OLD_ACCOUNT"
    else
      die "Couldn't detect account from AWS. Configure the profile first, or pass the ID: ./configure.sh <ID>"
    fi
  fi
fi

[[ "$NEW_ACCOUNT" =~ ^[0-9]{12}$ ]] || die "Account ID must be 12 digits, got: '$NEW_ACCOUNT'"

# ── build the replacement plan ────────────────────────────────────────────────
# Each entry: "label|OLD|NEW". Only included when OLD is set and OLD != NEW.
declare -a PLAN=()
add_repl() { [ -n "$2" ] && [ "$2" != "$3" ] && PLAN+=("$1|$2|$3") || true; }
add_repl "account ID" "$OLD_ACCOUNT" "$NEW_ACCOUNT"
[ -n "$NEW_PROFILE" ] && add_repl "AWS profile" "$OLD_PROFILE" "$NEW_PROFILE"
[ -n "$NEW_REGION" ]  && add_repl "AWS region"  "$OLD_REGION"  "$NEW_REGION"
[ -n "$NEW_REPO" ]    && add_repl "GitHub repo" "$OLD_REPO"    "$NEW_REPO"

[ "${#PLAN[@]}" -gt 0 ] || { info "Nothing to change — already configured for ${BOLD}$NEW_ACCOUNT${RST}."; exit 0; }

echo
echo "${BOLD}Planned replacements${RST}  ${DIM}(repo: $ROOT)${RST}"
for entry in "${PLAN[@]}"; do
  IFS='|' read -r label old new <<<"$entry"
  printf "  %-12s %s${DIM} →${RST} %s\n" "$label:" "$old" "$new"
done
echo

# Files to scan: everything containing any OLD value, minus caches / VCS / self.
declare -a GREP_PATTERNS=(-e "$OLD_ACCOUNT")
[ -n "$NEW_PROFILE" ] && [ -n "$OLD_PROFILE" ] && GREP_PATTERNS+=(-e "$OLD_PROFILE")
[ -n "$NEW_REGION" ]  && [ -n "$OLD_REGION" ]  && GREP_PATTERNS+=(-e "$OLD_REGION")
[ -n "$NEW_REPO" ]    && [ -n "$OLD_REPO" ]    && GREP_PATTERNS+=(-e "$OLD_REPO")

mapfile -t SCAN_FILES < <(
  grep -rIl "${GREP_PATTERNS[@]}" . \
    --exclude-dir=.terragrunt-cache --exclude-dir=.terraform --exclude-dir=.git \
    --exclude=configure.sh 2>/dev/null | sed 's|^\./||' | sort -u || true
)

CHANGED=0
for f in "${SCAN_FILES[@]}"; do
  [ -z "$f" ] || [ ! -f "$f" ] && continue
  hits=""
  for entry in "${PLAN[@]}"; do
    IFS='|' read -r label old new <<<"$entry"
    n=$(grep -c -F "$old" "$f" 2>/dev/null || true); n=${n:-0}
    [ "$n" -gt 0 ] && hits+="    ${DIM}${n}× ${old} → ${new}${RST}\n"
  done
  [ -z "$hits" ] && continue

  CHANGED=$((CHANGED + 1))
  echo "  ${BOLD}$f${RST}"
  printf "%b" "$hits"

  if [ "$DRY_RUN" -eq 0 ]; then
    for entry in "${PLAN[@]}"; do
      IFS='|' read -r label old new <<<"$entry"
      sed -i "s#${old}#${new}#g" "$f"
    done
  fi
done

echo
if [ "$DRY_RUN" -eq 1 ]; then
  warn "Dry run — no files written. Re-run without --dry-run to apply."
elif [ "$CHANGED" -eq 0 ]; then
  info "No matching references found to update."
else
  info "Updated ${BOLD}$CHANGED${RST} file(s) for account ${BOLD}$NEW_ACCOUNT${RST}."
  echo
  echo "${BOLD}Next steps${RST} (a new sandbox is a clean account, so re-bootstrap):"
  echo "  1) cd bootstrap && terraform init && terraform apply   ${DIM}# create state bucket + OIDC role${RST}"
  echo "  2) cd live/dev/<region>/<unit> && terragrunt init -reconfigure && terragrunt plan"
  echo "  ${DIM}(bootstrap uses local state; the old sandbox's state does not carry over)${RST}"
fi
