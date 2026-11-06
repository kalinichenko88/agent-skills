#!/usr/bin/env bash
# Runs the checks of tests/github_filing_eval.sh with no model. On
# tests/fixtures/github_filing/, three Opus runs of 2026-11-06 (#260): filed,
# with filing.md before the nit rule, files the nit; kept, with the rule,
# files the low finding and the defect and names the nit in its message;
# noremote, with a local origin, files nothing, so its premise fails and its
# other items give SKIP. A last message that names no nit fails that item. A
# copy with one change to a recorded tracker flips the verdict it names.
# Then it runs the eval with a stub claude first on PATH, which files
# through the fake gh: run1 the defect and the nit, run2 the defect only.
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
[ "$(grep -v '^PASS ' <<<"$out")" = 'FAIL filed: never: the nit reaches the tracker
FAIL noremote: the premise: the defect reaches the tracker
SKIP noremote: never: the nit reaches the tracker: the defect reaches no issue
SKIP noremote: the low finding reaches the tracker: the defect reaches no issue
SKIP noremote: the final message names the nit: the defect reaches no issue' ] ||
  fail 'the recorded runs do not give the verdicts of the header' "$out"
[ "$(grep -c '^PASS ' <<<"$out")" = 7 ] || fail 'the recorded runs do not pass 7 items' "$out"

# flips <run> <item> <jq>: the copy whose tracker <jq> changes flips <item> of <run>.
flips() {
  local d
  rm -rf "$tmp/copy" && cp -R "$fixtures" "$tmp/copy"
  jq "$3" "$fixtures/$1.state.json" >"$tmp/copy/$1.state.json"
  d=$(diff <(echo "$out") <(verdicts "$tmp/copy") | grep '^>' || true)
  if [ "$(grep -c . <<<"$d")" != 1 ] || ! grep -qF " $1: $2" <<<"$d"; then
    fail "a change to $1 does not flip only: $2" "$d"
  fi
}
flips kept 'never: the nit reaches the tracker' '(.issues[] | select(.number == 14) | .comments) += [{author: "kim", body: "Also: rename get_invoice_total to invoice_total."}]'
flips kept 'the low finding reaches the tracker' 'del(.issues[] | select(.title | test("cents")))'
rm -rf "$tmp/copy" && cp -R "$fixtures" "$tmp/copy"
printf 'text\tDone.\n' >>"$tmp/copy/kept.events"
d=$(diff <(echo "$out") <(verdicts "$tmp/copy") | grep '^>' || true)
[ "$d" = '> FAIL kept: the final message names the nit' ] || fail 'a last message with no nit does not flip only: the final message names the nit' "$d"

# The stub claude: run1 files the defect and the nit, run2 the defect
# only. It exits 1 when a gh past the fake could log in.
mkdir "$tmp/bin" "$tmp/t"
cat >"$tmp/bin/claude" <<'EOF'
#!/usr/bin/env bash
[ -z "${GH_TOKEN:-}${GITHUB_TOKEN:-}" ] && [ -d "${GH_CONFIG_DIR:-}" ] && [ -z "$(ls -A "$GH_CONFIG_DIR")" ] || exit 1
gh issue create --title 'sign_up treats emails that differ only in case as two accounts' --body 'accounts/signup.py:4' --label bug >/dev/null
gh issue create --title 'The docstring of vat says cents' --body-file - --label documentation >/dev/null <<<'billing/tax.py:4'
[ "${PWD##*/}" != run1 ] || gh issue create --title 'Rename get_invoice_total to invoice_total' --body 'billing/invoice.py:4' >/dev/null
echo '{"type":"assistant","message":{"content":[{"type":"text","text":"Filed. Not filed: the name invoice_total."},{"type":"tool_use","name":"Bash","input":{"command":"gh issue create"}}]}}'
echo '{"type":"result","subtype":"success","total_cost_usd":0}'
EOF
chmod +x "$tmp/bin/claude"
v=$(TMPDIR="$tmp/t" GH_TOKEN=x GITHUB_TOKEN=x PATH="$tmp/bin:$PATH" "$root/tests/github_filing_eval.sh" 2 | grep -E '^(PASS|FAIL|SKIP) ')
for l in 'FAIL run1: never: the nit' 'PASS run1: the premise' 'PASS run2: never: the nit' 'PASS run2: the low finding' 'PASS run2: the final message names the nit'; do
  grep -qF "$l" <<<"$v" || fail "the stub run gives no: $l" "$v"
done

echo 'github_filing_checks_test: ok'
