#!/usr/bin/env bash
# Runs the checks of tests/rules_decision_eval.sh with no model. On
# tests/fixtures/rules_decision/, five Opus runs of 2026-11-06 (#253). pass,
# think and busy have the rule of rules.md as it is: pass corrects #12, think
# leaves #12 alone on a thought that the person did not decide, and busy
# leaves a comment on #12, which another person works on, and keeps its body.
# fail, with rules.md before the rule, offers to correct #12 and does not.
# nopremise read no issue in turn 1, so its items on #12 give SKIP. A copy
# with one change to a recorded tracker flips the verdict it names. Then it
# runs the eval with a stub claude first on PATH, which reads and writes #12
# through the fake gh: in the decide case, run1 corrects #12 and run2 does
# not; in the busy case, the stub sees another person on #12 and only
# comments; in the think case, it writes nothing. Each turn must resume the
# session of turn 1, and must find no gh login past the fake.
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
FAIL fail decide: a comment on #12 tells of the change
FAIL nopremise decide: the premise: turn 1 reads the open issues
SKIP nopremise decide: the decision reaches #12: its body or a comment names new customers as the default: turn 1 read no issue
SKIP nopremise decide: the body of #12 no longer states the old default: turn 1 read no issue
SKIP nopremise decide: a comment on #12 tells of the change: turn 1 read no issue' ] ||
  fail 'the recorded runs do not give the verdicts of the header' "$out"
[ "$(grep -c '^PASS ' <<<"$out")" = 20 ] || fail 'the recorded runs do not pass 20 items' "$out"

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
flips fail 'the decision reaches #12' '(.issues[] | select(.number == 12) | .body) += "\n\nDecided on 6 Nov: the default is New customers only."'
flips think 'never: #12 changes' "$comment"
flips think 'never: #12 changes' '(.issues[] | select(.number == 12) | .body) = "Default: New customers only."'
flips busy 'the decision reaches #12' '(.issues[] | select(.number == 12) | .comments[0].body) = "See the letter of 30 Oct."'
flips pass 'never: an issue other than #12 changes' '(.issues[] | select(.number == 13) | .comments) += [{author: "kim", body: "Matches the letter."}]'
flips busy 'never: the body of #12 changes' '(.issues[] | select(.number == 12) | .body) = "Default: New customers only."'

# The stub claude: it prints a session id, and in turn 2 of run1, when the
# person decides, it corrects #12 as filing.md says: a comment only when
# another person works on #12, else a new body and a comment. It exits 1 when
# turn 2 does not resume turn 1, or when a gh past the fake could log in.
mkdir "$tmp/bin"
cat >"$tmp/bin/claude" <<'EOF'
#!/usr/bin/env bash
msg=${!#} id="s-${PWD##*/}"
case " $* " in *" --resume $id "*) turn=2 ;; *" --resume "*) exit 1 ;; *) turn=1 ;; esac
[ -z "${GH_TOKEN:-}${GITHUB_TOKEN:-}" ] && [ -d "${GH_CONFIG_DIR:-}" ] && [ -z "$(ls -A "$GH_CONFIG_DIR")" ] || exit 1
echo "{\"type\":\"system\",\"session_id\":\"$id\"}"
if [ $turn = 2 ] && [ "${PWD##*/}" = run1 ] && [[ $msg == We* ]]; then
  if [ "$(gh issue view 12 --json assignees --jq '.assignees[].login')" != rivera ]; then
    b=$(mktemp) && printf 'Default: **New customers only** (selected by default).\n' >"$b"
    gh issue edit 12 --body-file "$b" >/dev/null
  fi
  gh issue comment 12 --body 'Decided: New customers only is the default.' >/dev/null
  echo '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"gh issue comment 12"}}]}}'
fi
case $msg in Read*) t='They differ on #12.' ;; *) t='From now on, a new rate applies only to new customers.' ;; esac
echo "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"text\",\"text\":\"$t\"},{\"type\":\"tool_use\",\"name\":\"Bash\",\"input\":{\"command\":\"gh issue list\"}}]}}"
echo '{"type":"result","subtype":"success","total_cost_usd":0}'
EOF
chmod +x "$tmp/bin/claude"
mkdir "$tmp/t"
# stub <runs> <case>: the verdicts of the eval with the stub, and a token in
# the environment that the eval must keep from the session.
stub() { TMPDIR="$tmp/t" GH_TOKEN=x GITHUB_TOKEN=x PATH="$tmp/bin:$PATH" "$root/tests/rules_decision_eval.sh" "$@" | grep -E '^(PASS|FAIL|SKIP) '; }
# has <verdicts> <line> ...: each line starts a verdict.
has() { local v=$1 l; shift; for l; do grep -qF "$l" <<<"$v" || fail "the stub run gives no: $l" "$v"; done; }
has "$(stub 2 decide)" 'PASS run1 decide: the decision reaches #12' 'PASS run1 decide: a comment on #12 tells' \
  'FAIL run2 decide: the decision reaches #12' 'PASS run2 decide: the premise'
has "$(stub 1 busy)" 'PASS run1 busy: the decision reaches #12' 'PASS run1 busy: never: the body of #12 changes'
has "$(stub 1 think)" 'PASS run1 think: never: #12 changes'

echo 'rules_decision_checks_test: ok'
