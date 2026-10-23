#!/usr/bin/env bash
# The hook hand-escapes rules.md into JSON. Both Claude Code and Codex drop
# context that does not parse, so the real file must come back byte for byte.

set -eu

root=$(cd "$(dirname "$0")/.." && pwd)

# Git for Windows checks out with core.autocrlf=true by default. bash reads a CR
# as part of the command, so that checkout must keep LF too: the hook, and every
# script the skills run.
crlf=$(mktemp -d)
trap 'rm -rf "$crlf"' EXIT
git -C "$root" -c core.autocrlf=true checkout-index -a --prefix="$crlf/"
if grep -rIl $'\r' "$crlf"; then
  echo "FAIL: a core.autocrlf=true checkout has CRLF in the files above"
  exit 1
fi
# hooks.json runs the hook through its shebang, and NixOS has no /bin/bash.
[ "$(head -1 "$root/hooks/rules.sh")" = '#!/usr/bin/env bash' ] || {
  echo "FAIL: the hook's shebang must find bash on PATH: #!/usr/bin/env bash"
  exit 1
}

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
