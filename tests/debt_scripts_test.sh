#!/usr/bin/env bash
# Runs the debt skill's measure.sh on a repository it builds: a hot file, a
# large file last changed 90 days ago, a file whose name holds a colon, one
# whose name ends as a document's does, one with a non-ASCII name, and a
# dotfile that is code; a document, a fixture and ignore files that are data,
# not code; and a file moved into src/, one moved inside it, and a moved
# document. Then clones.sh, with a fake npx.

# shellcheck disable=SC2016 # the backticks are Markdown's
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
# A person's color.ui=always must not reach what the scripts read from git.
export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=color.ui GIT_CONFIG_VALUE_0=always
measure=$root/skills/debt/scripts/measure.sh
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fail() {
  printf 'FAIL: %s\n' "$1"
  [ -z "${2:-}" ] || printf '%s\n' "$2"
  exit 1
}
check() { [ "$2" = "$3" ] || fail "$1" "$(printf 'want: %s\ngot:  %s' "$2" "$3")"; }
# -f, so that a global gitignore cannot drop a file the test needs.
commit() { git -C "$repo" add -A -f && git -C "$repo" commit -qm "$1"; }

repo=$tmp/repo
mkdir -p "$repo/src" "$repo/tests/fixtures"
git -C "$repo" init -q -b main
git -C "$repo" config user.name test
git -C "$repo" config user.email test@example.com
git -C "$repo" config core.quotePath true
old="$(($(date +%s) - 90 * 86400)) +0000"
seq 200 >"$repo/big.sh"
GIT_AUTHOR_DATE=$old GIT_COMMITTER_DATE=$old commit 'add big'
for i in 1 2 3; do
  seq $((40 + i * 5)) >"$repo/src/hot.sh"
  seq $((290 + i)) >"$repo/notes.md"
  seq 100 >"$repo/tests/fixtures/data.sh"
  echo "$i" >>"$repo/tests/fixtures/data.sh"
  commit "change $i"
done
seq 10 >"$repo/src/a:b.sh"
seq 7 >"$repo/mvnw.cmd"
seq 3 >"$repo/src/заказ.sh"
seq 50 >"$repo/заметки.md"
seq 6 >"$repo/src/.gitignore"
seq 6 >"$repo/Dockerfile.dockerignore"
seq 6 >"$repo/.eslintrc.js"
mkdir -p "$repo/node_modules/lib"
seq 6 >"$repo/node_modules/lib/index.js"
commit 'add a:b, mvnw.cmd and two non-ASCII names'
seq 5 >"$repo/first.sh"
seq 4 >"$repo/src/old.sh"
commit 'add first and old'
mkdir "$repo/docs"
git -C "$repo" mv first.sh src/kept.sh
git -C "$repo" mv src/old.sh src/new.sh
git -C "$repo" mv notes.md docs/notes.md
commit 'move first, old and notes'

out=$(cd "$repo/src" && bash "$measure")
check 'the rows, by score, with no data' \
  "$(printf '%s\n' '| `src/hot.sh` | 55 | 3 | 165 |' '| `src/a:b.sh` | 10 | 1 | 10 |' '| `mvnw.cmd` | 7 | 1 | 7 |' '| `.eslintrc.js` | 6 | 1 | 6 |' '| `src/kept.sh` | 5 | 1 | 5 |' '| `src/new.sh` | 4 | 1 | 4 |' '| `src/заказ.sh` | 3 | 1 | 3 |' '| `big.sh` | 200 | 0 | 0 |')" \
  "$(grep '^| `' <<<"$out")"
check 'the measured line, without origin' \
  "Measured on \`HEAD\` at $(git -C "$repo" rev-parse --short HEAD), 8 code files." "$(grep '^Measured on' <<<"$out")"
check 'the moved code files' 'Code files moved in 60 days: 2. Their commits count from the move.' "$(tail -n 1 <<<"$out")"

git clone -q "$repo" "$tmp/clone"
out=$(cd "$tmp/clone" && bash "$measure" src)
check 'a path, in a clone' '`src/hot.sh` `src/a:b.sh` `src/kept.sh` `src/new.sh` `src/заказ.sh`' "$(grep -o '^| `[^`]*`' <<<"$out" | cut -c3- | paste -sd' ' -)"
case $(grep '^Measured on' <<<"$out") in 'Measured on `origin/main` at '*', 5 code files.') ;; *) fail 'the clone reads origin/main' "$out" ;; esac
check 'a move into the path and one inside it' 'Code files moved in 60 days: 2. Their commits count from the move.' "$(tail -n 1 <<<"$out")"
out=$(cd "$repo" && bash "$measure" big.sh)
check 'no moved line when nothing moved' "Measured on \`HEAD\` at $(git -C "$repo" rev-parse --short HEAD), 1 code files." "$(tail -n 1 <<<"$out")"

err=$(cd "$repo" && bash "$measure" tests 2>&1) && fail 'a path with only data exits 0' "$err"
check 'a path with only data' 'No code files under tests on HEAD.' "$err"

# clones.sh, on the tree that tests/fixtures/debt/jscpd-report.json was
# recorded from, with a fake npx: it writes down its name, where it ran, what it
# got and the files it was given, and answers with that report. The README, the
# fixture, node_modules and the SQL hold copies of the code, and jscpd never
# gets them.
command -v node >/dev/null || {
  echo 'debt_scripts_test: ok; clones.sh not run, no node'
  exit 0
}
clones=$root/skills/debt/scripts/clones.sh
tree=$tmp/tree
bash "$root/tests/fixtures/debt/tree.sh" "$tree"
git -C "$tree" init -q
git -C "$tree" add -A -f
real=$(cd "$tree" && pwd -P)
mkdir "$tmp/bin"
cat >"$tmp/bin/npx" <<'EOF'
#!/usr/bin/env bash
{ basename "$0"; pwd -P; echo "$*"; (cd "${!#}" && find . -type f | LC_ALL=C sort); } >"$FAKE_LOG"
[ -z "${FAKE_FAIL:-}" ] || exit 1
sed "s|@ROOT@|${FAKE_ROOT:-$(cd "${!#}" && pwd -P)}|g" "$FAKE_REPORT" >jscpd-report.json
EOF
chmod +x "$tmp/bin/npx"
export FAKE_LOG=$tmp/runner.log FAKE_REPORT=$root/tests/fixtures/debt/jscpd-report.json
fake=$tmp/bin:$PATH
args='jscpd@5.4.2 --min-lines 15 --no-gitignore --absolute --reporters json --output . code'
rows=$(printf '%s\n' '| Lines | File | Other file |' '| ---: | --- | --- |' '| 30 | `src/a.ts` 1-30 | `src/sub/e.ts` 1-30 |' '| 20 | `src/short1.ts` 1-20 | `src/short2.ts` 1-20 |')

check 'the code clones, longest first' "$rows" "$(PATH=$fake bash "$clones" "$tree")"
run=$(sed -n 2p "$FAKE_LOG")
case $run in "$real"*) fail 'jscpd ran in the tree' "$(cat "$FAKE_LOG")" ;; esac
check 'npx, with only the code files' \
  "$(printf '%s\n' npx "--yes $args" ./src/a.ts ./src/short1.ts ./src/short2.ts ./src/sub/e.ts)" "$(sed 2d "$FAKE_LOG")"
check 'a relative tree with CDPATH set' "$rows" "$(cd "$tmp" && CDPATH=$tmp PATH=$fake bash "$clones" tree)"
jq '.duplicates = []' "$FAKE_REPORT" >"$tmp/none.json"
check 'no clones' 'No clones of 15 lines or more in code files.' "$(FAKE_REPORT=$tmp/none.json PATH=$fake bash "$clones" "$tree")"

err=$(PATH=$fake bash "$clones" "$tree" migrations 2>&1) && fail 'a path with only SQL exits 0' "$err"
check 'a path with only SQL' 'No code files under migrations.' "$err"
err=$(PATH=$fake bash "$clones" "$tmp" 2>&1) && fail 'a tree that is not a checkout exits 0' "$err"
FAKE_FAIL=1 PATH=$fake bash "$clones" "$tree" 2>/dev/null && fail 'a failed jscpd exits 0'
err=$(FAKE_ROOT=/elsewhere PATH=$fake bash "$clones" "$tree" 2>&1) && fail 'a path outside the copy exits 0' "$err"
check 'a path outside the copy' 'clones.sh: jscpd gave a path outside the copy' "$err"
for f in node_modules .ignore; do
  mkdir -p "$tmp/above-$f/tmp"
  : >"$tmp/above-$f/$f"
  err=$(TMPDIR=$tmp/above-$f/tmp PATH=$fake bash "$clones" "$tree" 2>&1) && fail "a $f above the temporary directory exits 0" "$err"
  check "a $f above the temporary directory" \
    "clones.sh: $(cd "$tmp/above-$f" && pwd -P)/$f is above the temporary directory; set TMPDIR to another one" "$err"
done

# bunx with bun, on a PATH with no npx and no node, where /usr/bin and /bin
# have neither; bun itself, not a version manager's shim.
if command -v bun >/dev/null && [ ! -e /usr/bin/npx ] && [ ! -e /bin/npx ] &&
  "$(command -v bun)" --version >/dev/null 2>&1; then
  mkdir "$tmp/bunbin"
  cp "$tmp/bin/npx" "$tmp/bunbin/bunx"
  ln -s "$(command -v bun)" "$tmp/bunbin/bun"
  check 'bunx with bun' "$rows" "$(PATH=$tmp/bunbin:/usr/bin:/bin bash "$clones" "$tree")"
  check 'bunx' "$(printf '%s\n' bunx "$args")" "$(sed -n '1p;3p' "$FAKE_LOG")"
  case $(sed -n 2p "$FAKE_LOG") in "$real"*) fail 'bunx ran in the tree' "$(cat "$FAKE_LOG")" ;; esac
fi
echo 'debt_scripts_test: ok'
