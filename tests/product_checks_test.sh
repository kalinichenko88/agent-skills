#!/usr/bin/env bash
# Runs the checks of tests/product_eval.sh, without the model, on
# tests/fixtures/product/logs: the sessions' tool calls and last texts, in the
# layout an eval run leaves. Each shape has two logs, start three. The runs
# numbered 1 pass and are recorded runs with the skill. The others fail: worth,
# stop, fork, foreign and start are recorded runs with no skill, or with a
# skill that wrote before its panel; bug, traced, plain and store are recorded
# runs of another shape that a check must fail:
#   start-2    loaded no skill before its first write
#   start-3    no Codex login: the skill and Fable, and no codex exec
#   bug-2      a start run: Fable and Codex before the first write
#   traced-2   a worth run: a verdict of "do it another way"
#   plain-2    a fork run: a verdict line
#   store-2    a foreign run: no docs/decisions.md and no D4
# The logs keep the assistant's tool calls and the result, with their
# absolute paths replaced. A change to a check that moves a verdict changes
# the output and fails here.
# Then it gives the eval an argument too many, as `--check <folder> extra`
# and `3 --check <folder>`, with a stub claude: the eval must refuse before it
# starts a paid run. Last, it runs the paid path once with that stub, whose
# every session ends in an error: a guard shape must fail on it too.

set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"

expected() {
  cat <<'OUT'
worth: 1 of 2 runs pass
  fail worth-2
stop: 1 of 2 runs pass
  fail stop-2
fork: 1 of 2 runs pass
  fail fork-2
foreign: 1 of 2 runs pass
  fail foreign-2
start: 1 of 3 runs pass
  fail start-2
  fail start-3
bug: 1 of 2 runs pass
  fail bug-2
traced: 1 of 2 runs pass
  fail traced-2
plain: 1 of 2 runs pass
  fail plain-2
store: 1 of 2 runs pass
  fail store-2
OUT
}

# counts <output>: the count and fail lines, without the texts of stop.
counts() {
  grep -E '^[a-z]+: [0-9]+ of [0-9]+ runs pass$|^  fail ' <<<"$1" || true
}

code=0
out=$(tests/product_eval.sh --check tests/fixtures/product/logs/ 2>&1) || code=$?
[ "$code" = 0 ] || {
  printf 'FAIL: --check exited %s, not 0\n%s\n' "$code" "$out"
  exit 1
}
[ "$(counts "$out")" = "$(expected)" ] || {
  echo 'FAIL: --check gives other verdicts on the fixture (- expected, + got)'
  diff <(expected) <(counts "$out") || true
  exit 1
}

# refused <argument>...: the eval must exit 2 with its usage and start no run.
# The claude on PATH is a stub that records each call, so a broken guard costs
# no tokens, and the logs of such a run go into the stub's folder.
stub=$(mktemp -d)
trap 'rm -rf "$stub"' EXIT
cat >"$stub/claude" <<'STUB'
#!/usr/bin/env bash
touch "$(dirname "$0")/called"
echo '{"type":"result","is_error":true}'
STUB
chmod +x "$stub/claude"
found=$(PATH="$stub:$PATH" command -v claude || true)
[ "$found" = "$stub/claude" ] || {
  echo "FAIL: claude is '$found', not the stub $stub/claude"
  exit 1
}
refused() {
  local code=0 err
  rm -f "$stub/called"
  err=$(PATH="$stub:$PATH" TMPDIR="$stub" tests/product_eval.sh "$@" 2>&1 >/dev/null) || code=$?
  if [ "$code" != 2 ] || [ "${err#usage:}" = "$err" ] || [ -e "$stub/called" ]; then
    echo "FAIL: '$*' exited $code with '$err': it must exit 2 with the usage and not run claude"
    exit 1
  fi
}
refused --check tests/fixtures/product/logs extra
refused 3 --check tests/fixtures/product/logs
refused 1 nope

code=0
out=$(PATH="$stub:$PATH" TMPDIR="$stub" tests/product_eval.sh 1 worth bug 2>&1) || code=$?
[ "$code" = 0 ] && [ "$(counts "$out")" = "$(printf '%s\n' 'worth: 0 of 1 runs pass' '  fail worth-1' 'bug: 0 of 1 runs pass' '  fail bug-1')" ] || {
  printf 'FAIL: a run whose sessions end in an error exited %s, and must fail worth and bug\n%s\n' "$code" "$out"
  exit 1
}
echo 'product_checks_test: ok'
