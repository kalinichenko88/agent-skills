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
# A clone made before .gitattributes keeps rules.md in CRLF: an update rewrites
# only the files it changes. The hook must still give the rules.
cp "$root/hooks/rules.sh" "$crlf/hooks/"
sed 's/$/\r/' "$root/rules.md" >"$crlf/rules.md"
[ "$("$crlf/hooks/rules.sh" SessionStart)" = "$("$root/hooks/rules.sh" SessionStart)" ] || {
  echo "FAIL: the hook does not give the rules from a CRLF rules.md"
  exit 1
}
# NixOS has no /bin/bash: every script must find bash on PATH.
for script in $(git -C "$root" ls-files '*.sh'); do
  [ "$(head -1 "$root/$script")" = '#!/usr/bin/env bash' ] || {
    echo "FAIL: $script: the shebang must be #!/usr/bin/env bash"
    exit 1
  }
done

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
# A review subagent gets these rules too, as the loop above proves, and
# *Out-of-scope findings* tells it to file an issue without asking. One
# sentence must tell every read-only subagent, a review one included, to file
# nothing.
tr '\n' ' ' <"$root/rules.md" | grep -qE 'read-only subagent[^.]* review[^.]* files nothing' || {
  echo "FAIL: SubagentStart: no sentence tells a read-only review subagent to file nothing"
  exit 1
}
# superpowers' review skills start at the same moments as review-loop and give
# other steps, and its per-task reviewer is a review subagent too. The rules
# must say which skill wins, keep the per-task review out of the loop, and
# invoke the loop after the last task: that review is no longer the first one.
# shellcheck disable=SC2016 # Markdown backticks, not shell
tr '\n' ' ' <"$root/rules.md" | grep -qE 'review-loop` replaces `superpowers:requesting-code-review` and `superpowers:receiving-code-review`' || {
  echo "FAIL: no sentence says that review-loop replaces the superpowers review skills"
  exit 1
}
# shellcheck disable=SC2016 # Markdown backticks, not shell
tr '\n' ' ' <"$root/rules.md" | grep -qE 'subagent-driven-development`, the review after each task stays[^.]*\. Invoke review-loop after the last task' || {
  echo "FAIL: no sentence keeps the per-task review of subagent-driven development and invokes review-loop after the last task"
  exit 1
}
echo 'rules_test: ok'
