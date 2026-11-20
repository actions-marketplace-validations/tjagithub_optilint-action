#!/usr/bin/env bash
# Decides failure but leaves it to a later step, so the SARIF upload still runs. Inputs arrive as env vars only.
set -euo pipefail

case "$OPTILINT_FAIL_ON" in findings | error | never) ;; *) echo "::error::fail-on must be findings, error or never, got '$OPTILINT_FAIL_ON'"; exit 2 ;; esac
case "$OPTILINT_MIN_IMPACT" in high | medium | low) ;; *) echo "::error::min-impact must be high, medium or low, got '$OPTILINT_MIN_IMPACT'"; exit 2 ;; esac

read -ra paths <<<"$OPTILINT_PATHS"
read -ra extra <<<"$OPTILINT_ARGS"
cmd=(npx --yes "@optilint/cli@$OPTILINT_VERSION" ${paths[@]+"${paths[@]}"} --min-impact "$OPTILINT_MIN_IMPACT" ${extra[@]+"${extra[@]}"})

out=$(mktemp)
status=0
"${cmd[@]}" --format github >"$out" || status=$?
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
  echo "sarif-file=$sarif" >>"$GITHUB_OUTPUT"
fi
