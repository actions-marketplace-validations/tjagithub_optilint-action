#!/usr/bin/env bash
# Decides failure but leaves it to a later step, so the SARIF upload still runs. Inputs arrive as env vars only.
set -euo pipefail

case "$OPTILINT_FAIL_ON" in findings | error | never) ;; *) echo "::error::fail-on must be findings, error or never, got '$OPTILINT_FAIL_ON'"; exit 2 ;; esac
case "$OPTILINT_MIN_IMPACT" in high | medium | low) ;; *) echo "::error::min-impact must be high, medium or low, got '$OPTILINT_MIN_IMPACT'"; exit 2 ;; esac

read -ra paths <<<"$OPTILINT_PATHS"
read -ra extra <<<"$OPTILINT_ARGS"
cmd=(npx --yes "@optilint/cli@$OPTILINT_VERSION" ${paths[@]+"${paths[@]}"} --min-impact "$OPTILINT_MIN_IMPACT" ${extra[@]+"${extra[@]}"})

# optilint reports paths from where it runs; GitHub wants them from the repository root.
prefix=$(realpath --relative-to="${GITHUB_WORKSPACE:-$PWD}" "$PWD")
[ "$prefix" = . ] && prefix='' || prefix="$prefix/"

out=$(mktemp)
status=0
"${cmd[@]}" --format github >"$out" || status=$?
if [ -n "$prefix" ]; then
  esc=$(printf '%s' "$prefix" | sed -e 's/%/%25/g' -e 's/:/%3A/g' -e 's/,/%2C/g' -e 's/[#&\\]/\\&/g')
  sed -i.bak "s#^\(::[a-z]* file=\)\([^/]\)#\1${esc}\2#" "$out"
fi
cat "$out"
if [ "$status" -gt 1 ]; then
  echo "::error::optilint exited with $status"
  exit "$status"
fi

findings=$(grep -c '^::' "$out" || true)
failed=false
case "$OPTILINT_FAIL_ON" in
  findings) [ "$status" -eq 1 ] && failed=true ;;
  error) grep -q '^::error ' "$out" && failed=true ;;
esac
{
  echo "findings=$findings"
  echo "failed=$failed"
} >>"$GITHUB_OUTPUT"
echo "optilint: $findings finding(s)" >>"$GITHUB_STEP_SUMMARY"

if [ "$OPTILINT_SARIF" = "true" ]; then
  sarif="$RUNNER_TEMP/optilint.sarif"
  "${cmd[@]}" --format sarif >"$sarif" || [ $? -eq 1 ]
  if [ -n "$prefix" ]; then
    jq --arg p "$prefix" '(.runs[].results[].locations[].physicalLocation.artifactLocation | select(.uriBaseId == "%SRCROOT%") | .uri) |= ($p + .)' "$sarif" >"$sarif.tmp"
    mv "$sarif.tmp" "$sarif"
  fi
  echo "sarif-file=$sarif" >>"$GITHUB_OUTPUT"
fi
