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
# The hook gives the issue third and the --jq filter last.
cat >"$tmp/bin/gh" <<'EOF'
#!/usr/bin/env bash
echo "$1 $2 $3" >>"$FAKE/calls"
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
field() { jq -r ".hookSpecificOutput.$1" <<<"$out"; }
calls() { cat "$tmp/calls" 2>/dev/null || true; }
recorded='#133 filing.md forbids a new label'

cp "$fixtures/issue.json" "$tmp/issue.json"
out=$(run claude-prompt.json '#133') || fail "#133: exit $?"
check '#133: the title' "$recorded" "$(field sessionTitle)"
check '#133: the event' UserPromptSubmit "$(field hookEventName)"
check '#133: gh reads the issue' 'issue view 133' "$(calls)"

url=https://github.com/kalinichenko88/agent-skills/issues/133
out=$(run claude-prompt.json "$url") || fail "URL: exit $?"
check 'URL: the title' "$recorded" "$(field sessionTitle)"
check 'URL: gh reads the issue' "issue view $url" "$(calls)"

# Claude Code sent "  #91  " as it was typed. The prompts below are JSON text:
# \n is a pasted newline. Each line is the prompt|the issue gh gets.
while IFS='|' read -r prompt issue; do
  out=$(run claude-prompt.json "$prompt") || fail "$prompt: exit $?"
  check "$prompt: the title" "$recorded" "$(field sessionTitle)"
  check "$prompt: gh reads the issue" "issue view $issue" "$(calls)"
done <<EOF
  #133  |133
$url\n|$url
#133\t|133
#133\r\n|133
EOF

# A quote, a backslash or a tab in the title must leave the JSON valid.
jq '.title = "a \"b\" \\ c\td"' "$fixtures/issue.json" >"$tmp/issue.json"
out=$(run claude-prompt.json '#133') || fail "escape: exit $?"
check 'escape: the title' '#133 a "b" \ c d' "$(field sessionTitle)"

# The name keeps the number and the first part of the title whole up to 50
# characters, and cuts a longer part at a word end to 40. Each line is the
# title|the name. Rows 1 to 5 are titles of this tracker, row 6 a short form
# of #64. Rows 7 to 13 are titles of this tracker and vaultmd: with the
# number, the first part has 48 characters in row 7, 50 in row 8 and 51 in
# row 9, which then drops a "(" with no ")" after the cut; row 10 stops at
# " — "; row 11 drops a "(" with no ")" after a comma, row 12 after the cut;
# row 13 drops the last double quote of an odd count; row 14 keeps a "(" with
# its ")". Then a short title keeps its last small word; a Russian title
# counts in characters, not bytes; a word longer than the limit is cut inside.
while IFS='|' read -r issue_title name; do
  jq --arg t "$issue_title" '.title = $t' "$fixtures/issue.json" >"$tmp/issue.json"
  out=$(run claude-prompt.json '#133') || fail "$issue_title: exit $?"
  check "$issue_title: the title" "$name" "$(field sessionTitle)"
done <<'EOF'
architecture: first-file.md asks for patterns in step 2, but its parts of the file have no place for them|#133 first-file.md asks for patterns in step 2
architecture: I-8 fails on main: tests/architecture_scripts_test.sh has 353 lines, past the limit of 330|#133 I-8 fails on main
roadmap: no step triages a new issue: no check of its report, no label, no importance, no milestone|#133 no step triages a new issue
react-conventions has no rule for a component that holds several jobs: loading, creating and form state in one body|#133 react-conventions has no rule
skill scripts: an unbound variable exits 0 through the EXIT trap, and collect.sh keeps its half-written file|#133 an unbound variable exits 0 through
review-loop: the agent stops; nothing says to open the pull request|#133 the agent stops
fs-atomic: the tmp is never synced before it is placed, and a failed write leaves it behind|#133 the tmp is never synced before it is placed
review-loop: in Claude Code every review runs on one model; add Codex as a second reviewer for xhigh changes|#133 in Claude Code every review runs on one model
Post-1.0 non-goal: bulk tag rename (the other four were promoted)|#133 bulk tag rename
1.0: full revision of the public API — signatures and contracts|#133 full revision of the public API
notes: bulk write API for imports (one lock cycle, one index transaction)|#133 bulk write API for imports
query: richer where filters (in / not / ranges / missing) and multi-tag matching|#133 richer where filters
review-loop: a review subagent gets "file it, do not ask first" from rules.md, and no "file nothing"|#133 a review subagent gets
vault-io: folder enumeration (listFolders)|#133 folder enumeration (listFolders)
Hooks fail when logged in|#133 Hooks fail when logged in
Хук ставит в имя сессии весь заголовок issue, и имя получается длинным|#133 Хук ставит в имя сессии весь заголовок issue
skills/architecture/scripts/invariants.sh fails on bash 3.2|#133 skills/architecture/scripts/invaria
EOF
cp "$fixtures/issue.json" "$tmp/issue.json"

# None of these is an issue on its own: no title, and no gh call. gh would
# send a token to the host of the last two.
for prompt in 'Look at #133' '#133 and #134' "$url#issuecomment-1" \
  https://example.com/o/r/issues/133 https://github.com.example.com/o/r/issues/133; do
  out=$(run claude-prompt.json "$prompt") || fail "$prompt: exit $?"
  check "$prompt: no title" '' "$out"
  check "$prompt: no gh call" '' "$(calls)"
done
out=$(run codex-prompt.json '#133') || fail "Codex: exit $?"
check 'Codex: no title, as Codex fails the run on a field it does not know' '' "$out"
check 'Codex: no gh call' '' "$(calls)"
# A host is Claude Code only with prompt_id and no turn_id.
sed 's/"turn_id":"[^"]*",//' "$fixtures/codex-prompt.json" >"$tmp/no-ids.json"
sed 's/"prompt_id"/"turn_id":"x","prompt_id"/' "$fixtures/claude-prompt.json" >"$tmp/both-ids.json"
for payload in no-ids.json both-ids.json; do
  out=$(fixtures=$tmp run "$payload" '#133') || fail "$payload: exit $?"
  check "$payload: no title" '' "$out"
  check "$payload: no gh call" '' "$(calls)"
done
out=$(FAKE_FAIL=1 run claude-prompt.json '#133') || fail "gh fails: exit $?"
check 'gh fails: no title' '' "$out"

echo 'hooks_scripts_test: ok'
