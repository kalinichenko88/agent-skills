#!/usr/bin/env bash
# Runs the checks of tests/github_filing_eval.sh with no model. On
# tests/fixtures/github_filing/, four Opus runs of 2026-11-06 (#260): filed,
# with filing.md before the nit rule, files the nit; dropped, with the nit
# rule before its list of no-nits and with labelled findings, leaves the
# false docstring off the tracker; kept, with the final rule, files the low
# finding and the defect and names the nit in its message; noremote, with a
# local origin, files nothing, so its premise fails and its other items give
# SKIP. A last message that names no nit fails that item. A
# copy with one change to a recorded tracker flips the verdict it names.
# Then it runs the eval with a stub claude first on PATH, which files
# through the fake gh.
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
fixtures=$root/tests/fixtures/github_filing
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fail() {
  echo "github_filing_checks_test: $1" >&2
  [ -z "${2:-}" ] || printf '%s\n' "$2" >&2
  exit 1
}
verdicts() { "$root/tests/github_filing_eval.sh" --check "$1" | grep -v '^INFO '; }

out=$(verdicts "$fixtures")
[ "$(grep -v '^PASS ' <<<"$out")" = 'FAIL dropped: the low finding reaches the tracker
FAIL filed: never: the nit reaches the tracker
FAIL noremote: the premise: the defect reaches the tracker
SKIP noremote: never: the nit reaches the tracker: the defect reaches no issue
SKIP noremote: the low finding reaches the tracker: the defect reaches no issue
SKIP noremote: the final message names the nit: the defect reaches no issue' ] ||
  fail 'the recorded runs do not give the verdicts of the header' "$out"
[ "$(grep -c '^PASS ' <<<"$out")" = 10 ] || fail 'the recorded runs do not pass 10 items' "$out"

# fresh: a new copy of the fixtures. changed: the verdicts that the copy changes.
fresh() { rm -rf "$tmp/copy" && cp -R "$fixtures" "$tmp/copy"; }
changed() { diff <(echo "$out") <(verdicts "$tmp/copy") | grep '^>' || true; }
# flips <run> <item> <jq>: the copy whose tracker <jq> changes flips only <item> of <run>.
flips() {
  local d
  fresh
  jq "$3" "$fixtures/$1.state.json" >"$tmp/copy/$1.state.json"
  d=$(changed)
  if [ "$(grep -c . <<<"$d")" != 1 ] || ! grep -qF " $1: $2" <<<"$d"; then
    fail "a change to $1 does not flip only: $2" "$d"
  fi
}
flips kept 'never: the nit reaches the tracker' '(.issues[] | select(.number == 14) | .comments) += [{author: "kim", body: "Also: rename get_invoice_total to invoice_total."}]'
# The wording of the nit body in filed.state.json, with no new name in it.
# shellcheck disable=SC2016 # Markdown's backticks
flips kept 'never: the nit reaches the tracker' '.issues += [{number: 99, title: "billing: a name", body: "The `get_` prefix adds no information.", labels: [], comments: []}]'
fresh
printf 'text\tDone.\n' >>"$tmp/copy/kept.events"
[ "$(changed)" = '> FAIL kept: the final message names the nit' ] ||
  fail 'a last message with no nit does not flip only: the final message names the nit' "$(changed)"
fresh
jq 'del(.issues[] | select(.title | test("sign_up")))' "$fixtures/kept.state.json" >"$tmp/copy/kept.state.json"
[ "$(changed)" = '> FAIL kept: the premise: the defect reaches the tracker
> SKIP kept: never: the nit reaches the tracker: the defect reaches no issue
> SKIP kept: the low finding reaches the tracker: the defect reaches no issue
> SKIP kept: the final message names the nit: the defect reaches no issue' ] ||
  fail 'a run that files all but the defect does not fail the premise and skip the rest' "$(changed)"

# The stub claude files through the fake gh. In both runs: the defect, and
# the low finding with its word only in the body. In run1 also the nit, as a
# comment on #14. It exits 1 when a gh past the fake could log in.
mkdir "$tmp/bin" "$tmp/t"
cat >"$tmp/bin/claude" <<'EOF'
#!/usr/bin/env bash
[ -z "${GH_TOKEN:-}${GITHUB_TOKEN:-}" ] && [ -d "${GH_CONFIG_DIR:-}" ] && [ -z "$(ls -A "$GH_CONFIG_DIR")" ] || exit 1
gh issue create --title 'sign_up treats emails that differ only in case as two accounts' --body 'accounts/signup.py:4' --label bug >/dev/null
gh issue create --title 'The docstring of vat is wrong' --body-file - --label documentation >/dev/null <<<'billing/tax.py:4 says cents'
f=$(mktemp) && echo 'Also: rename get_invoice_total to invoice_total.' >"$f"
[ "${PWD##*/}" != run1 ] || gh issue comment 14 --body-file "$f" >/dev/null
echo '{"type":"assistant","message":{"content":[{"type":"text","text":"Filed. Not filed: the name invoice_total."},{"type":"tool_use","name":"Bash","input":{"command":"gh issue create"}}]}}'
echo '{"type":"result","subtype":"success","total_cost_usd":0}'
EOF
chmod +x "$tmp/bin/claude"
v=$(TMPDIR="$tmp/t" GH_TOKEN=x GITHUB_TOKEN=x PATH="$tmp/bin:$PATH" "$root/tests/github_filing_eval.sh" 2 | grep -E '^(PASS|FAIL|SKIP) ')
for l in 'FAIL run1: never: the nit' 'PASS run1: the premise' 'PASS run1: the low finding' 'PASS run2: never: the nit' 'PASS run2: the low finding' 'PASS run2: the final message names the nit'; do
  grep -qF "$l" <<<"$v" || fail "the stub run gives no: $l" "$v"
done

echo 'github_filing_checks_test: ok'
