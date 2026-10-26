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

# A branch with one commit past its base, which adds a file.
repo=$tmp/repo
git init -q -b main "$repo"
git -C "$repo" -c user.name=t -c user.email=t@example.com commit -q --allow-empty -m base
base=$(git -C "$repo" rev-parse HEAD)
echo change >"$repo/a.txt"
git -C "$repo" add a.txt
git -C "$repo" -c user.name=t -c user.email=t@example.com commit -q -m change
head=$(git -C "$repo" rev-parse HEAD)
review() { (cd "$repo" && PATH="$tmp/bin:$PATH" bash "$script" "$@"); }
# A PATH with git and no codex.
mkdir "$tmp/nocodex"
ln -s "$(command -v git)" "$tmp/nocodex/git"
nocodex() { (cd "$repo" && PATH="$tmp/nocodex" "$BASH" "$script" "$@"); }

out=$(review "$base")
check 'prints the findings that codex wrote, and nothing of its session' "$(cat "$fixtures/codex-findings.json")" "$out"
check 'codex runs in the read-only sandbox' read-only "$(grep -A1 -xF -- -s "$tmp/args" | sed -n 2p)"
grep -qxF -- '--ephemeral' "$tmp/args" || fail 'codex keeps no session files' "$(cat "$tmp/args")"
grep -qF 'file nothing' "$tmp/args" || fail 'the prompt tells codex, which loads rules.md too, to file nothing' "$(cat "$tmp/args")"
grep -qF "git diff $base...$head" "$tmp/args" ||
  fail 'the prompt names the range of the whole branch, from the merge base to the SHA of HEAD' "$(cat "$tmp/args")"
rm -f "$tmp/args"
review HEAD~1 >/dev/null
grep -qF "git diff $base...$head" "$tmp/args" || fail 'a base given as a name goes into the prompt as its SHA' "$(cat "$tmp/args")"
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

check 'no codex on PATH: skipped, with the reason' 'skipped: the codex CLI is not installed' "$(nocodex "$base")"

code=0
review no-such-commit >/dev/null 2>"$tmp/err" || code=$?
check 'a base that is not a commit is a usage error' 2 "$code"
grep -qF 'no-such-commit is not a commit' "$tmp/err" || fail 'the usage error names the base' "$(cat "$tmp/err")"

code=0
out=$(nocodex no-such-commit 2>&1) || code=$?
check 'a bad base is a usage error with no codex too, not a skip' \
  '2 codex-review.sh: no-such-commit is not a commit' "$code $out"

# GIT_CEILING_DIRECTORIES keeps git from finding a repository above $tmp.
mkdir "$tmp/outside"
code=0
(cd "$tmp/outside" && GIT_CEILING_DIRECTORIES="$tmp" PATH="$tmp/bin:$PATH" bash "$script" "$base") \
  >/dev/null 2>"$tmp/err" || code=$?
check 'a working directory outside a repository is a usage error' 2 "$code"
grep -qF 'fatal: not a git repository' "$tmp/err" || fail "the usage error keeps git's own reason" "$(cat "$tmp/err")"
grep -qxF "codex-review.sh: no git repository at $tmp/outside" "$tmp/err" ||
  fail 'the usage error names the working directory' "$(cat "$tmp/err")"

rm -f "$tmp/args"
code=0
review HEAD >/dev/null 2>"$tmp/err" || code=$?
check 'a range that changes nothing is a usage error, not a clean review' 2 "$code"
grep -qF 'changes nothing' "$tmp/err" || fail 'the usage error says the range changes nothing' "$(cat "$tmp/err")"
[ ! -f "$tmp/args" ] || fail 'a range that changes nothing: codex exec does not run'

# A commit with no history in common with HEAD.
rm -f "$tmp/args"
orphan=$(git -C "$repo" -c user.name=t -c user.email=t@example.com \
  commit-tree -m orphan "$(git -C "$repo" hash-object -t tree /dev/null)")
code=0
review "$orphan" >/dev/null 2>"$tmp/err" || code=$?
check 'a range that git cannot diff is a usage error, not a clean review' 2 "$code"
grep -qF 'git cannot diff' "$tmp/err" || fail 'the usage error says git cannot diff the range' "$(cat "$tmp/err")"
grep -qF 'no merge base' "$tmp/err" || fail "the usage error keeps git's own reason for the range" "$(cat "$tmp/err")"
[ ! -f "$tmp/args" ] || fail 'a range that git cannot diff: codex exec does not run'

echo 'review_loop_scripts_test: ok'
