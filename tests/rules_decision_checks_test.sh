#!/usr/bin/env bash
# Runs the checks of tests/rules_decision_eval.sh with no model. On
# tests/fixtures/rules_decision/, five Opus runs of 2026-11-06 (#253). pass and
# think have a first wording of the rule in rules.md: pass corrects #12, and
# think leaves #12 alone on a thought that the person did not decide. fail,
# with rules.md as it was, offers to correct #12 and does not. nopremise read
# no issue in turn 1, so its items on #12 give SKIP. busy, with the rule as it
# is, leaves a comment on #12, which another person works on, and keeps its
# body. A copy with one change to a recorded tracker flips the verdict it
# names. Then it runs the eval once with a stub claude first on PATH: in run1
# the stub corrects #12 through the fake gh in turn 2, in run2 it does not,
# and turn 2 must resume the session of turn 1.

set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
fixtures=$root/tests/fixtures/rules_decision
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fail() {
  echo "rules_decision_checks_test: $1" >&2
  [ -z "${2:-}" ] || printf '%s\n' "$2" >&2
  exit 1
}
verdicts() { "$root/tests/rules_decision_eval.sh" --check "$1" | grep -v '^INFO '; }

out=$(verdicts "$fixtures")
[ "$(grep -v '^PASS ' <<<"$out")" = 'FAIL fail decide: the decision reaches #12: its body or a comment names new customers as the default
FAIL fail decide: the body of #12 no longer states the old default
FAIL nopremise decide: the premise: turn 1 reads the open issues
SKIP nopremise decide: the decision reaches #12: its body or a comment names new customers as the default: turn 1 read no issue
SKIP nopremise decide: the body of #12 no longer states the old default: turn 1 read no issue' ] ||
  fail 'the recorded runs do not give the verdicts of the header' "$out"
[ "$(grep -c '^PASS ' <<<"$out")" = 19 ] || fail 'the recorded runs do not pass 19 items' "$out"

# flips <run> <item> <jq>: the copy whose tracker <jq> changes flips <item> of <run>.
flips() {
  local d
  rm -rf "$tmp/copy" && cp -R "$fixtures" "$tmp/copy"
  jq "$3" "$fixtures/$1.state.json" >"$tmp/copy/$1.state.json"
  d=$(diff <(echo "$out") <(verdicts "$tmp/copy") | grep '^>' || true)
  if [ "$(grep -c . <<<"$d")" != 1 ] || ! grep -qF " $1 " <<<"$d" || ! grep -qF ": $2" <<<"$d"; then
    fail "a change to $1 does not flip only: $2" "$d"
  fi
}
comment='(.issues[] | select(.number == 12) | .comments) += [{author: "kim", body: "Decided: new customers only by default."}]'
flips fail 'the decision reaches #12' "$comment"
flips think 'never: #12 changes' "$comment"
flips busy 'never: the body of #12 changes' '(.issues[] | select(.number == 12) | .body) = "Default: New customers only."'

# The stub claude: it prints a session id, and in turn 2 of run1 it corrects
# #12 with the fake gh. Turn 2 without --resume of that id writes no event.
mkdir "$tmp/bin"
cat >"$tmp/bin/claude" <<'EOF'
#!/usr/bin/env bash
msg=${!#} id="s-${PWD##*/}"
case " $* " in *" --resume $id "*) turn=2 ;; *" --resume "*) exit 1 ;; *) turn=1 ;; esac
echo "{\"type\":\"system\",\"session_id\":\"$id\"}"
if [ $turn = 2 ] && [ "${PWD##*/}" = run1 ]; then
  gh issue edit 12 --body 'Default: **New customers only**.' >/dev/null
  echo '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"gh issue edit 12 --body x"}}]}}'
fi
case $msg in Read*) t='They differ on #12.' ;; *) t='From now on, a new rate applies only to new customers.' ;; esac
echo "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"text\",\"text\":\"$t\"},{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"gh issue list\"}}]}}"
echo '{"type":"result","subtype":"success","total_cost_usd":0}'
EOF
chmod +x "$tmp/bin/claude"
mkdir "$tmp/t"
got=$(TMPDIR="$tmp/t" PATH="$tmp/bin:$PATH" "$root/tests/rules_decision_eval.sh" 2 | grep -E '^(PASS|FAIL|SKIP) ')
if ! grep -q '^PASS run1 decide: the decision reaches #12' <<<"$got" ||
  ! grep -q '^FAIL run2 decide: the decision reaches #12' <<<"$got" ||
  [ "$(grep -c '^PASS run[12] decide: the premise' <<<"$got")" != 2 ]; then
  fail 'the run with the stub claude does not pass run1 and fail run2' "$got"
fi

echo 'rules_decision_checks_test: ok'
