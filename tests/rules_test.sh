#!/bin/bash
# The hook hand-escapes rules.md into JSON. Both Claude Code and Codex drop
# context that does not parse, so the real file must come back byte for byte.

set -eu

root=$(cd "$(dirname "$0")/.." && pwd)

for event in SessionStart SubagentStart; do
  output=$("$root/hooks/rules.sh" "$event")
  [ "$(jq -r .hookSpecificOutput.hookEventName <<<"$output")" = "$event" ] || {
    echo "FAIL: $event: wrong hookEventName"
    exit 1
  }
  diff <(jq -r .hookSpecificOutput.additionalContext <<<"$output") \
    "$root/rules.md" || {
    echo "FAIL: $event: context differs from rules.md"
    exit 1
  }
  # Claude Code moves additionalContext over 10,000 characters to a file and
  # shows only a 2,000-character preview.
  chars=$(jq -r '.hookSpecificOutput.additionalContext | length' <<<"$output")
  [ "$chars" -le 10000 ] || {
    echo "FAIL: $event: context is $chars characters, the cap is 10000"
    exit 1
  }
done
echo 'rules_test: ok'
