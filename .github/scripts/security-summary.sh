#!/usr/bin/env bash
# Render security-results/security-summary.md from KICS + Checkov JSON output,
# using only bash + jq (no Python). Layout:
#   - cross-scanner overview table + verdict
#   - per scanner: a severity-sorted findings table (worst first)
#   - per scanner: a collapsed <details> drawer with full detail
#
# Reads:
#   security-results/kics-results.json   (KICS)
#   security-results/results_json.json   (merged Checkov reports — array)
# Writes:
#   security-results/security-summary.md
# Sets GitHub step outputs issues_found / issues_count (CRITICAL+HIGH total).
set -uo pipefail

mkdir -p security-results
OUT="security-results/security-summary.md"
KICS_JSON="security-results/kics-results.json"
CHK_JSON=$(find security-results -name "results_json.json" 2>/dev/null | head -1)

# Shared jq helpers, prepended to every jq program.
JQ_LIB='
  def cell: (. // "") | tostring | @html | gsub("\\|"; "\\|") | gsub("[\r\n]+"; " ");
  def md:   (. // "") | tostring | @html | gsub("[\r\n]+"; " ");
  def val:  (if . == null then "" elif . == true then "True" elif . == false then "False" else . end) | tostring;
  def emoji($s): if ($s=="HIGH" or $s=="CRITICAL") then "🔴" elif $s=="MEDIUM" then "🟡" elif $s=="LOW" then "🟢" else "ℹ️" end;
  def rank($s):  if $s=="CRITICAL" then 0 elif $s=="HIGH" then 1 elif $s=="MEDIUM" then 2 elif $s=="LOW" then 3 else 4 end;
  def base($p):  ($p // "" | tostring | split("/") | last);
'

# ── Gather KICS counts ───────────────────────────────────────────────────────
kics_high=0; kics_med=0; kics_low=0; kics_info=0; kics_files=0; kics_queries=0
kics_present=""
if [ -f "$KICS_JSON" ]; then
  kics_present=1
  read -r kics_high kics_med kics_low kics_info kics_files kics_queries < <(
    jq -r '
      ( [ .queries[]? as $q | $q.files[]? | ($q.severity // "INFO") ]
        | reduce .[] as $s ({h:0,m:0,l:0,i:0};
            if   ($s=="HIGH" or $s=="CRITICAL") then .h += 1
            elif  $s=="MEDIUM"                  then .m += 1
            elif  $s=="LOW"                     then .l += 1
            else                                     .i += 1 end)
      ) as $c
      | "\($c.h) \($c.m) \($c.l) \($c.i) \(.files_scanned // 0) \(.queries_total // 0)"
    ' "$KICS_JSON"
  )
  kics_high=${kics_high:-0}; kics_med=${kics_med:-0}; kics_low=${kics_low:-0}
  kics_info=${kics_info:-0}; kics_files=${kics_files:-0}; kics_queries=${kics_queries:-0}
fi
kics_total=$(( kics_high + kics_med + kics_low + kics_info ))

# ── Gather Checkov counts ────────────────────────────────────────────────────
chk_passed=0; chk_failed=0; chk_skipped=0; chk_high=0; chk_med=0; chk_low=0
chk_present=""
if [ -n "$CHK_JSON" ] && [ -f "$CHK_JSON" ]; then
  chk_present=1
  read -r chk_passed chk_failed chk_skipped chk_high chk_med chk_low < <(
    jq -r '
      (if type=="object" then [.] else . end) as $r
      | ([ $r[].results.failed_checks[]? | ((.severity // "MEDIUM") | ascii_upcase) ]) as $sevs
      | "\([$r[].summary.passed // 0] | add // 0) \([$r[].summary.failed // 0] | add // 0) \([$r[].summary.skipped // 0] | add // 0) "
        + "\([ $sevs[] | select(. == "HIGH" or . == "CRITICAL") ] | length) "
        + "\([ $sevs[] | select(. == "MEDIUM") ] | length) "
        + "\([ $sevs[] | select(. == "LOW") ] | length)"
    ' "$CHK_JSON"
  )
  chk_passed=${chk_passed:-0}; chk_failed=${chk_failed:-0}; chk_skipped=${chk_skipped:-0}
  chk_high=${chk_high:-0}; chk_med=${chk_med:-0}; chk_low=${chk_low:-0}
fi

# ── Per-scanner result cells ─────────────────────────────────────────────────
if   [ -z "$kics_present" ];                              then kics_result="⚠️ No results"
elif [ "$kics_high" -gt 0 ];                              then kics_result="🔴 Fail"
elif [ "$kics_med" -gt 0 ] || [ "$kics_low" -gt 0 ];      then kics_result="🟡 Warn"
else                                                           kics_result="✅ Pass"; fi

if   [ -z "$chk_present" ];        then chk_result="⚠️ No results"; chk_hi_cell="—"; chk_md_cell="—"; chk_lo_cell="—"
elif [ "$chk_high" -gt 0 ];        then chk_result="🔴 Fail"
elif [ "$chk_failed" -gt 0 ];      then chk_result="🟡 Warn"
else                                    chk_result="✅ Pass"; fi
[ -n "$kics_present" ] && { kics_hi_cell=$kics_high; kics_md_cell=$kics_med; kics_lo_cell=$kics_low; } || { kics_hi_cell="—"; kics_md_cell="—"; kics_lo_cell="—"; }
[ -n "$chk_present" ]  && { chk_hi_cell=$chk_high;  chk_md_cell=$chk_med;  chk_lo_cell=$chk_low;  }

total_high_critical=$(( kics_high + chk_high ))
minor=$(( kics_med + kics_low + chk_failed ))
if   [ "$total_high_critical" -gt 0 ]; then verdict="🔴 **${total_high_critical} critical/high finding(s) must be resolved.**"
elif [ "$minor" -gt 0 ];               then verdict="🟡 Minor issues found — review recommended."
else                                        verdict="✅ No security issues found."; fi

# ── Header + overview ────────────────────────────────────────────────────────
{
  echo "## 🔒 Security Scan Results"
  echo ""
  echo "_commit \`${GITHUB_SHA:-unknown}\` · [KICS v2.1.20](https://kics.io) · [Checkov](https://checkov.io)_"
  echo ""
  echo "| Scanner | 🔴 Crit/High | 🟡 Med | 🟢 Low | Result |"
  echo "|---------|:-----------:|:------:|:------:|--------|"
  echo "| KICS    | ${kics_hi_cell} | ${kics_md_cell} | ${kics_lo_cell} | ${kics_result} |"
  echo "| Checkov | ${chk_hi_cell} | ${chk_md_cell} | ${chk_lo_cell} | ${chk_result} |"
  echo ""
  echo "**Verdict:** ${verdict}"
  echo ""
  echo "---"
  echo ""
} > "$OUT"

# ── KICS section ─────────────────────────────────────────────────────────────
{
  echo "### KICS — Keeping Infrastructure as Code Secure"
  echo ""
} >> "$OUT"

if [ -z "$kics_present" ]; then
  { echo "⚠️ Scan did not produce results."; echo ""; } >> "$OUT"
elif [ "$kics_total" -eq 0 ]; then
  { echo "✅ No findings · ${kics_files} files scanned · ${kics_queries} queries."; echo ""; } >> "$OUT"
else
  {
    echo "**${kics_total} finding(s)** · ${kics_files} files scanned · ${kics_queries} queries"
    echo ""
    echo "| Sev | Query | Location | Issue |"
    echo "|-----|-------|----------|-------|"
    jq -r "$JQ_LIB"'
      [ .queries[]? as $q | $q.files[]?
        | { sev: ($q.severity // "INFO"), query: $q.query_name, file: .file_name, line: (.line // ""), issue: .issue_type } ]
      | sort_by(rank(.sev), (.file // ""))
      | .[]
      | "| \(emoji(.sev)) \(.sev) | \(.query|cell) | \(base(.file)|cell):\(.line) | \(.issue|cell) |"
    ' "$KICS_JSON"
    echo ""
    echo "<details><summary>🔍 KICS detail — expected vs actual</summary>"
    echo ""
    jq -r "$JQ_LIB"'
      [ .queries[]? as $q | $q.files[]?
        | { sev: ($q.severity // "INFO"), query: $q.query_name, file: .file_name, line: (.line // ""),
            issue: .issue_type, exp: .expected_value, act: .actual_value } ]
      | sort_by(rank(.sev), (.file // ""))
      | .[]
      | "**\(emoji(.sev)) \(.sev) · \(.query|md)** — `\(.file|md):\(.line)`\n"
        + "- Issue: \(.issue|md)\n"
        + "- Expected: \(.exp|val|md)\n"
        + "- Actual: \(.act|val|md)\n"
    ' "$KICS_JSON"
    echo "</details>"
    echo ""
  } >> "$OUT"
fi

{ echo "---"; echo ""; } >> "$OUT"

# ── Checkov section ──────────────────────────────────────────────────────────
{
  echo "### Checkov — Policy-as-Code Security Scanner"
  echo ""
} >> "$OUT"

if [ -z "$chk_present" ]; then
  { echo "⚠️ Scan did not produce results."; echo ""; } >> "$OUT"
elif [ "$chk_failed" -eq 0 ]; then
  { echo "✅ All checks passed · ${chk_passed} passed · ${chk_skipped} skipped."; echo ""; } >> "$OUT"
else
  {
    echo "**${chk_failed} failed** · ✅ ${chk_passed} passed · ⏭️ ${chk_skipped} skipped"
    echo ""
    echo "| Sev | Check | Resource | Location |"
    echo "|-----|-------|----------|----------|"
    jq -r "$JQ_LIB"'
      (if type=="object" then [.] else . end)
      | [ .[].results.failed_checks[]?
          | { sev: ((.severity // "MEDIUM") | ascii_upcase), id: .check_id, name: .check_name,
              res: .resource, file: (.file_abs_path // .file_path), line: ((.file_line_range[0]) // 0) } ]
      | sort_by(rank(.sev), (.id // ""))
      | .[]
      | "| \(emoji(.sev)) \(.sev) | `\(.id|cell)` \(.name|cell) | `\(.res|cell)` | \(base(.file)|cell):\(.line) |"
    ' "$CHK_JSON"
    echo ""
    echo "<details><summary>🔍 Checkov detail — code &amp; guidelines</summary>"
    echo ""
    jq -r "$JQ_LIB"'
      (if type=="object" then [.] else . end)
      | [ .[].results.failed_checks[]?
          | { sev: ((.severity // "MEDIUM") | ascii_upcase), id: .check_id, name: .check_name, res: .resource,
              file: (.file_abs_path // .file_path), line: ((.file_line_range[0]) // 0),
              guideline: (.guideline // ""), code: .code_block } ]
      | sort_by(rank(.sev), (.id // ""))
      | .[]
      | "**\(emoji(.sev)) \(.id|md) · \(.name|md)** — `\(.res|md)` at `\(.file|md):\(.line)`\n"
        + (if (.guideline) != "" then "Guideline: \(.guideline|md)\n" else "" end)
        + (if (.code) != null then
            "\n```hcl\n"
            + ( [ .code[]
                  | (.[0] | tostring) as $n
                  | (((4 - ($n | length)) as $p | if $p > 0 then (" " * $p) else "" end) + $n)
                    + " | " + (.[1] | sub("[ \t\r\n]+$"; "")) ]
                | join("\n") )
            + "\n```\n"
          else "" end)
        + "\n"
    ' "$CHK_JSON"
    echo "</details>"
    echo ""
  } >> "$OUT"
fi

# ── Footer ───────────────────────────────────────────────────────────────────
{
  echo "---"
  echo ""
  echo "[🔗 View full scan logs in Actions](https://github.com/${GITHUB_REPOSITORY:-}/actions/runs/${GITHUB_RUN_ID:-})"
} >> "$OUT"

# ── Gate output ──────────────────────────────────────────────────────────────
{
  if [ "$total_high_critical" -gt 0 ]; then echo "issues_found=true"; else echo "issues_found=false"; fi
  echo "issues_count=${total_high_critical}"
} >> "$GITHUB_OUTPUT"
if [ "$total_high_critical" -gt 0 ]; then
  echo "::error::Found ${total_high_critical} CRITICAL/HIGH security issues!"
fi
