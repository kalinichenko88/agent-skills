#!/usr/bin/env bash
# The session-title hook, run on the prompts that Claude Code and Codex send:
# recorded payloads with their paths replaced, and a fake gh that answers from
# a recorded issue.

set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
fixtures=$root/tests/fixtures/hooks
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir "$tmp/bin"
# The hook gives the --jq filter last.
cat >"$tmp/bin/gh" <<'EOF'
#!/usr/bin/env bash
echo "$*" >>"$FAKE/calls"
[ -z "${FAKE_FAIL:-}" ] || { echo 'gh: HTTP 502' >&2; exit 1; }
jq -r "${!#}" "$FAKE/issue.json"
EOF
chmod +x "$tmp/bin/gh"
export PATH="$tmp/bin:$PATH" FAKE="$tmp"

fail() {
  printf 'FAIL: %s\n' "$1"
  [ -z "${2:-}" ] || printf '%s\n' "$2"
  exit 1
}
check() { [ "$2" = "$3" ] || fail "$1" "$(printf 'want: %s\ngot:  %s' "$2" "$3")"; }
# Runs the hook on the recorded payload $1 with the prompt $2, its last field.
run() {
  local payload
  IFS= read -r -d '' payload <"$fixtures/$1" || true
  rm -f "$tmp/calls"
  printf '%s"prompt":"%s"}%s' "${payload%%\"prompt\":*}" "$2" "${payload##*\}}" |
    "$root/hooks/session-title.sh"
}
title() { jq -r ".hookSpecificOutput.$1" <<<"$out"; }
calls() { cat "$tmp/calls" 2>/dev/null || true; }
recorded='#133 github: filing.md forbids a new label, so a debt issue from architecture or review-loop gets bug or no label'

cp "$fixtures/issue.json" "$tmp/issue.json"
out=$(run claude-prompt.json '#133') || fail "#133: exit $?"
check '#133: the title' "$recorded" "$(title sessionTitle)"
check '#133: the event' UserPromptSubmit "$(title hookEventName)"
check '#133: gh reads the issue' 'issue view 133' "$(calls | cut -d' ' -f1-3)"

url=https://github.com/kalinichenko88/agent-skills/issues/133
out=$(run claude-prompt.json "$url") || fail "URL: exit $?"
check 'URL: the title' "$recorded" "$(title sessionTitle)"
check 'URL: gh reads the issue' "issue view $url" "$(calls | cut -d' ' -f1-3)"

# Claude Code sent "  #91  " as it was typed. The prompts below are JSON text:
# \n is a pasted newline.
for prompt in '  #133  ' "$url"'\n' 'http://ghe.example.com/o/r/issues/133'; do
  out=$(run claude-prompt.json "$prompt") || fail "$prompt: exit $?"
  check "$prompt: the title" "$recorded" "$(title sessionTitle)"
done

# A quote, a backslash or a tab in the title must leave the JSON valid.
jq '.title = "a \"b\" \\ c\td"' "$fixtures/issue.json" >"$tmp/issue.json"
out=$(run claude-prompt.json '#133') || fail "escape: exit $?"
check 'escape: the title' '#133 a "b" \ c d' "$(title sessionTitle)"
cp "$fixtures/issue.json" "$tmp/issue.json"

# None of these is an issue on its own: no title, and no gh call.
for prompt in 'Look at #133' '#133 and #134' "$url#issuecomment-1"; do
  out=$(run claude-prompt.json "$prompt") || fail "$prompt: exit $?"
  check "$prompt: no title" '' "$out"
  check "$prompt: no gh call" '' "$(calls)"
done
out=$(run codex-prompt.json '#133') || fail "Codex: exit $?"
check 'Codex: no title, as Codex fails the run on a field it does not know' '' "$out"
check 'Codex: no gh call' '' "$(calls)"
# A host that sends neither prompt_id nor turn_id is not known to be Claude Code.
sed 's/"turn_id":"[^"]*",//' "$fixtures/codex-prompt.json" >"$tmp/other.json"
out=$(fixtures=$tmp run other.json '#133') || fail "other host: exit $?"
check 'other host: no title' '' "$out"
out=$(FAKE_FAIL=1 run claude-prompt.json '#133') || fail "gh fails: exit $?"
check 'gh fails: no title' '' "$out"

echo 'hooks_scripts_test: ok'
