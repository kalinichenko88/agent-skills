#!/usr/bin/env bash
# Runs the debt skill's measure.sh on a repository it builds: a hot file, a
# large file last changed 90 days ago, a file whose name holds a colon, one
# whose name ends as a document's does, and one with a non-ASCII name, a
# document and a fixture that are data, not code, and a file moved into src/,
# one moved inside it, and a moved document. Then clones.sh, with a fake npx.

# shellcheck disable=SC2016 # the backticks are Markdown's
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
measure=$root/skills/debt/scripts/measure.sh
clones=$root/skills/debt/scripts/clones.sh
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
  "$(printf '%s\n' '| `src/hot.sh` | 55 | 3 | 165 |' '| `src/a:b.sh` | 10 | 1 | 10 |' '| `mvnw.cmd` | 7 | 1 | 7 |' '| `src/kept.sh` | 5 | 1 | 5 |' '| `src/new.sh` | 4 | 1 | 4 |' '| `src/заказ.sh` | 3 | 1 | 3 |' '| `big.sh` | 200 | 0 | 0 |')" \
  "$(grep '^| `' <<<"$out")"
check 'the measured line, without origin' \
  "Measured on \`HEAD\` at $(git -C "$repo" rev-parse --short HEAD), 7 code files." "$(grep '^Measured on' <<<"$out")"
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

# clones.sh, with a fake npx: it writes down where it ran and what it got, and
# writes the report that jscpd 5.4.2 wrote for a tree with code clones, SVG
# copies and fixtures.
mkdir -p "$tmp/bin" "$tmp/tree"
real=$(cd "$tmp/tree" && pwd -P)
cat >"$tmp/bin/npx" <<'EOF'
#!/usr/bin/env bash
pwd -P >"$FAKE_LOG"
echo "$*" >>"$FAKE_LOG"
[ -z "${FAKE_FAIL:-}" ] || exit 1
sed "s|@TREE@|$FAKE_TREE|g" "$FAKE_REPORT" >jscpd-report.json
EOF
chmod +x "$tmp/bin/npx"
export FAKE_LOG=$tmp/npx.log FAKE_TREE=$real FAKE_REPORT=$root/tests/fixtures/debt/jscpd-report.json
out=$(PATH=$tmp/bin:$PATH bash "$clones" "$tmp/tree" src)
check 'the code clones, longest first' \
  "$(printf '%s\n' '| Lines | File | Other file |' '| ---: | --- | --- |' '| 30 | `src/a.ts` 1-30 | `src/sub/e.ts` 1-30 |' '| 10 | `src/short1.ts` 1-10 | `src/short2.ts` 1-10 |')" "$out"
check 'jscpd on the path' "--yes jscpd@latest --min-lines 8 --absolute --reporters json --output . $real/src" "$(sed -n 2p "$FAKE_LOG")"
case $(head -n 1 "$FAKE_LOG") in "$real"*) fail 'jscpd ran in the tree' "$(cat "$FAKE_LOG")" ;; esac
FAKE_FAIL=1 PATH=$tmp/bin:$PATH bash "$clones" "$tmp/tree" 2>/dev/null && fail 'a failed jscpd exits 0'
FAKE_TREE=/elsewhere PATH=$tmp/bin:$PATH bash "$clones" "$tmp/tree" 2>/dev/null && fail 'a path outside the tree exits 0'
echo 'debt_scripts_test: ok'
