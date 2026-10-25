#!/usr/bin/env bash
# Runs the review-loop skill's codex-review.sh against a fake codex. The fake
# answers with findings that codex exec wrote on the final head of PR #9, and
# logs the arguments of each call, so no test reaches Codex.

set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
script=$root/skills/review-loop/scripts/codex-review.sh
fixtures=$root/tests/fixtures/review-loop
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

mkdir "$tmp/bin"
cat >"$tmp/bin/codex" <<'EOF'
#!/usr/bin/env bash
case $1 in
  login)
    [ "${FAKE_LOGGED_IN:-1}" = 1 ] || { echo 'Not logged in'; exit 1; }
    echo 'Logged in using ChatGPT' ;;
  exec)
    printf '%s\n' "$@" >"$FAKE/args"
    while [ $# -gt 0 ]; do
      case $1 in
        --output-schema) cp "$2" "$FAKE/schema.json"; shift ;;
        -o) out=$2; shift ;;
      esac
      shift
    done
    echo 'codex prints its session here'
    [ -z "${FAKE_FAIL:-}" ] || { echo 'ERROR: stream disconnected before completion'; exit 1; }
    [ -z "${FAKE_NO_MESSAGE:-}" ] || exit 0
    cp "$FIXTURES/codex-findings.json" "$out" ;;
  *) echo "fake codex: no answer for: $*" >&2; exit 1 ;;
esac
EOF
chmod +x "$tmp/bin/codex"
export FAKE="$tmp" FIXTURES="$fixtures"

fail() {
  printf 'FAIL: %s\n' "$1"
  [ -z "${2:-}" ] || printf '%s\n' "$2"
  exit 1
}
check() { [ "$2" = "$3" ] || fail "$1" "$(printf 'want: %s\ngot:  %s' "$2" "$3")"; }

# A branch with one commit past its base.
repo=$tmp/repo
git init -q -b main "$repo"
git -C "$repo" -c user.name=t -c user.email=t@example.com commit -q --allow-empty -m base
base=$(git -C "$repo" rev-parse HEAD)
git -C "$repo" -c user.name=t -c user.email=t@example.com commit -q --allow-empty -m change
head=$(git -C "$repo" rev-parse HEAD)
review() { (cd "$repo" && PATH="$tmp/bin:$PATH" bash "$script" "$@"); }

out=$(review "$base")
check 'prints the findings that codex wrote, and nothing of its session' "$(cat "$fixtures/codex-findings.json")" "$out"
check 'codex runs in the read-only sandbox' read-only "$(grep -A1 -xF -- -s "$tmp/args" | sed -n 2p)"
grep -qxF -- '--ephemeral' "$tmp/args" || fail 'codex keeps no session files' "$(cat "$tmp/args")"
grep -qF "git diff $base...$head" "$tmp/args" ||
  fail 'the prompt names the range of the whole branch, from the merge base to the SHA of HEAD' "$(cat "$tmp/args")"
check 'the schema asks for the fields of a finding' 'file line summary failure_scenario' \
  "$(jq -r '.properties.findings.items.required | join(" ")' "$tmp/schema.json")"
check 'the recorded findings fit the schema' 'true' \
  "$(jq --slurpfile s "$tmp/schema.json" '[.findings[] | keys_unsorted] | all(. == $s[0].properties.findings.items.required)' "$fixtures/codex-findings.json")"

code=0
out=$(FAKE_FAIL=1 review "$base" 2>"$tmp/err") || code=$?
check 'a failed codex run exits 1' 1 "$code"
check 'a failed codex run prints no findings' '' "$out"
grep -qF 'stream disconnected' "$tmp/err" || fail 'a failed codex run shows its log on stderr' "$(cat "$tmp/err")"

code=0
out=$(FAKE_NO_MESSAGE=1 review "$base" 2>"$tmp/err") || code=$?
check 'codex that ends with no findings file exits 1, not with no output' 1 "$code"
grep -qF 'codex prints its session here' "$tmp/err" || fail 'codex with no findings file shows its log on stderr' "$(cat "$tmp/err")"

rm -f "$tmp/args"
check 'not logged in: skipped, with the reason' 'skipped: codex is not logged in' "$(FAKE_LOGGED_IN=0 review "$base")"
[ ! -f "$tmp/args" ] || fail 'not logged in: codex exec does not run'

check 'no codex on PATH: skipped, with the reason' 'skipped: the codex CLI is not installed' \
  "$(cd "$repo" && PATH=/usr/bin:/bin bash "$script" "$base")"

code=0
review no-such-commit >/dev/null 2>"$tmp/err" || code=$?
check 'a base that is not a commit is a usage error' 2 "$code"
grep -qF 'no-such-commit' "$tmp/err" || fail 'the usage error names the base' "$(cat "$tmp/err")"

code=0
(cd "$repo" && PATH=/usr/bin:/bin bash "$script" no-such-commit) >/dev/null 2>&1 || code=$?
check 'a bad base is a usage error with no codex too, not a skip' 2 "$code"

echo 'review_loop_scripts_test: ok'
