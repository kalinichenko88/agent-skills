#!/usr/bin/env bash
# Runs the debt skill's measure.sh on a repository it builds: a hot file, a
# large file last changed 90 days ago, a file whose name holds a colon, one
# whose name ends as a document's does, one with a non-ASCII name, and a
# dotfile that is code; a document, a fixture and ignore files that are data,
# not code; and a file moved into src/, one moved inside it, and a moved
# document. Then clones.sh, with a fake npx and bunx.

# shellcheck disable=SC2016 # the backticks are Markdown's
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
measure=$root/skills/debt/scripts/measure.sh
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fail() {
  printf 'FAIL: %s\n' "$1"
  [ -z "${2:-}" ] || printf '%s\n' "$2"
  exit 1
}
check() { [ "$2" = "$3" ] || fail "$1" "$(printf 'want: %s\ngot:  %s' "$2" "$3")"; }
commit() { git -C "$repo" add -A && git -C "$repo" commit -qm "$1"; }

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

# clones.sh, with a fake npx and bunx: each writes down its name, where it ran,
# what it got and the files it was given, and writes the report that jscpd
# 5.4.2 wrote for this tree. The README, the fixture and the SQL hold copies of
# the code there, and jscpd never got them.
{ command -v node || command -v bun; } >/dev/null || {
  echo 'debt_scripts_test: ok; clones.sh not run, no node or bun'
  exit 0
}
clones=$root/skills/debt/scripts/clones.sh
tree=$tmp/tree
mkdir -p "$tree/src/sub" "$tree/tests/fixtures" "$tree/migrations" "$tmp/bin" "$tmp/project/tmp"
for f in src/a.ts src/sub/e.ts tests/fixtures/x.ts README.md; do seq 30 >"$tree/$f"; done
for f in src/short1.ts 'src/short|2.ts' migrations/001.sql migrations/002.sql; do seq 10 >"$tree/$f"; done
git -C "$tree" init -q
git -C "$tree" add -A
real=$(cd "$tree" && pwd -P)
cat >"$tmp/bin/npx" <<'EOF'
#!/usr/bin/env bash
{ basename "$0"; pwd -P; echo "$*"; (cd "${!#}" && find . -type f | LC_ALL=C sort); } >"$FAKE_LOG"
[ -z "${FAKE_FAIL:-}" ] || exit 1
sed "s|@ROOT@|${FAKE_ROOT:-$(cd "${!#}" && pwd -P)}|g" "$FAKE_REPORT" >jscpd-report.json
EOF
cp "$tmp/bin/npx" "$tmp/bin/bunx"
chmod +x "$tmp/bin/npx" "$tmp/bin/bunx"
export FAKE_LOG=$tmp/runner.log FAKE_REPORT=$root/tests/fixtures/debt/jscpd-report.json
fake=$tmp/bin:$PATH
args='jscpd@latest --min-lines 8 --absolute --reporters json --output . code'

out=$(PATH=$fake bash "$clones" "$tree")
check 'the code clones, longest first' \
  "$(printf '%s\n' '| Lines | File | Other file |' '| ---: | --- | --- |' '| 30 | `src/a.ts` 1-30 | `src/sub/e.ts` 1-30 |' '| 10 | `src/short1.ts` 1-10 | `src/short\|2.ts` 1-10 |')" "$out"
check 'npx, with only the code files' "$(printf '%s\n' npx "--yes $args" ./src/a.ts ./src/short1.ts './src/short|2.ts' ./src/sub/e.ts)" "$(sed 2d "$FAKE_LOG")"
case $(sed -n 2p "$FAKE_LOG") in "$real"*) fail 'jscpd ran in the tree' "$(cat "$FAKE_LOG")" ;; esac
out=$(cd "$tmp" && CDPATH=$tmp PATH=$fake bash "$clones" tree)
check 'a relative tree with CDPATH set' '| Lines | File | Other file |' "$(head -n 1 <<<"$out")"
: >"$tree/bun.lock"
PATH=$fake bash "$clones" "$tree" >/dev/null
check 'bunx in a Bun project' "$(printf '%s\n' bunx "$args")" "$(sed -n '1p;3p' "$FAKE_LOG")"
rm "$tree/bun.lock"
check 'a path with only SQL' 'No code files under migrations.' "$(PATH=$fake bash "$clones" "$tree" migrations)"

: >"$tmp/project/package.json"
err=$(TMPDIR=$tmp/project/tmp PATH=$fake bash "$clones" "$tree" 2>&1) && fail 'a package.json above the temporary directory exits 0' "$err"
check 'a package.json above the temporary directory' \
  "clones.sh: $(cd "$tmp/project" && pwd -P)/package.json is above the temporary directory; set TMPDIR to another one" "$err"
FAKE_FAIL=1 PATH=$fake bash "$clones" "$tree" 2>/dev/null && fail 'a failed jscpd exits 0'
FAKE_ROOT=/elsewhere PATH=$fake bash "$clones" "$tree" 2>/dev/null && fail 'a path outside the copy exits 0'
echo 'debt_scripts_test: ok'
