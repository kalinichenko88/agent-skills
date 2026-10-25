#!/usr/bin/env bash
# Runs the debt skill's measure.sh on a repository it builds: a hot file, a
# large file last changed 90 days ago, a file whose name holds a colon, one
# whose name ends as a document's does, one with a non-ASCII name, and a
# dotfile that is code; a document, a fixture and ignore files that are data,
# not code; and a file moved into src/, one moved inside it, and a moved
# document; and a fetch that lands during a run. Then clones.sh, with a fake
# npx.

# shellcheck disable=SC2016 # the backticks are Markdown's
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
# A person's color.ui=always must not reach what the scripts read from git; it
# goes after any configuration the environment already gives git.
n=${GIT_CONFIG_COUNT:-0}
export "GIT_CONFIG_KEY_$n=color.ui" "GIT_CONFIG_VALUE_$n=always" GIT_CONFIG_COUNT=$((n + 1))
measure=$root/skills/debt/scripts/measure.sh
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fail() {
  printf 'FAIL: %s\n' "$1"
  [ -z "${2:-}" ] || printf '%s\n' "$2"
  exit 1
}
check() { [ "$2" = "$3" ] || fail "$1" "$(printf 'want: %s\ngot:  %s' "$2" "$3")"; }
# Ends the test early: the note says what did not run, and the ok line stays
# last, as make test needs.
skip() { printf 'debt_scripts_test: %s\n' "$1"; echo 'debt_scripts_test: ok'; exit 0; }
# shellcheck disable=SC2317 # the echo runs only when skip does not exit
out=$(skip 'a note'; echo 'skip did not exit') || fail 'skip exits non-zero' "$out"
check 'skip prints its note, then the ok line last' "$(printf '%s\n' 'debt_scripts_test: a note' 'debt_scripts_test: ok')" "$out"
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
# A fetch that lands during a run, after a force push: the git on PATH moves
# origin/main back to the commit before the moves after each call that names
# origin/, but the --abbrev-ref call that reads only the branch's name. On that
# commit src/ has old.sh in place of kept.sh and new.sh, nothing has moved and
# the SHA is another, so a run that reads the branch more than once prints
# another output than above.
mkdir "$tmp/fetchbin"
cat >"$tmp/fetchbin/git" <<'EOF'
#!/usr/bin/env bash
# The test puts this directory first on PATH; the real git comes after it.
PATH=${PATH#*:}
git "$@" || exit
case $* in *--abbrev-ref*) ;; *origin/*) git update-ref refs/remotes/origin/main "$BACK" ;; esac
EOF
chmod +x "$tmp/fetchbin/git"
back=$(git -C "$tmp/clone" rev-parse main~1)
got=$(cd "$tmp/clone" && BACK=$back PATH=$tmp/fetchbin:$PATH bash "$measure" src)
check 'a fetch during the run' "$out" "$got"
check 'a fetch during the run moved origin/main' "$back" "$(git -C "$tmp/clone" rev-parse origin/main)"

out=$(cd "$repo" && bash "$measure" big.sh)
check 'no moved line when nothing moved' "Measured on \`HEAD\` at $(git -C "$repo" rev-parse --short HEAD), 1 code files." "$(tail -n 1 <<<"$out")"

err=$(cd "$repo" && bash "$measure" tests 2>&1) && fail 'a path with only data exits 0' "$err"
check 'a path with only data' 'No code files under tests on HEAD.' "$err"

# clones.sh, on the tree that tests/fixtures/debt/jscpd-report.json was
# recorded from, with a fake npx: it writes down its name, where it ran, what it
# got and the files it was given, and answers with that report. The README, the
# fixture, node_modules and the SQL hold copies of the code, and jscpd never
# gets them.
command -v node >/dev/null || skip 'clones.sh not run, no node'
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
umask 022
up=$(cd "$tmp" && pwd -P)
refused='belongs to another user, or a group or others can write it; set TMPDIR to a private directory'
taken='is above the temporary directory, and npm or jscpd would take it; set TMPDIR to a directory with none above it'

# clones.sh refuses this machine's temporary directory when it is below a
# shared one, as /tmp on Linux, or below a package.json, a node_modules or a
# .ignore: then nothing below can run.
out=$(PATH=$fake bash "$clones" "$tree" 2>"$tmp/err") || case $(cat "$tmp/err") in
  *"$refused" | *"$taken") skip "clones.sh not run: $(cat "$tmp/err")" ;;
  *) fail 'clones.sh on the tree' "$(cat "$tmp/err")" ;;
esac
check 'the code clones, longest first' "$rows" "$out"
run=$(sed -n 2p "$FAKE_LOG")
case $run in "$real"*) fail 'jscpd ran in the tree' "$(cat "$FAKE_LOG")" ;; esac
check 'npx, with only the code files' \
  "$(printf '%s\n' npx "--yes $args" ./src/a.ts ./src/short1.ts ./src/short2.ts ./src/sub/e.ts)" "$(sed 2d "$FAKE_LOG")"
out=$(cd "$tmp" && CDPATH=$tmp PATH=$fake bash "$clones" tree)
check 'a relative tree with CDPATH set' "$rows" "$out"
# bash 3.2 runs an EXIT trap with $? at 0 when set -u stops a script. A copy of
# clones.sh gets a stop after its trap and runs with a finished from the
# environment. Two stops: an unbound variable, the case itself, and an exit 0,
# which gives the trap the $? of 0 of bash 3.2 on any bash. Each must exit
# non-zero, show that it reached the stop, and leave nothing in TMPDIR.
cp -R "$root/skills/debt/scripts" "$tmp/stopped"
mkdir "$tmp/stoptmp"
for stop in unbound exit; do
  awk -v stop="$stop" '{ print } !/^[ \t]*#/ && /trap .* EXIT/ {
    print (stop == "exit" ? "echo stop-after-trap; exit 0" : ": \"$unbound_after_trap\"") }' "$clones" >"$tmp/stopped/clones.sh"
  mark='stop-after-trap'
  [ "$stop" = exit ] || mark='unbound_after_trap: unbound variable'
  out=$(finished=1 TMPDIR=$tmp/stoptmp PATH=$fake bash "$tmp/stopped/clones.sh" "$tree" 2>&1) && fail "clones.sh exits 0 after its $stop stop" "$out"
  case $out in *"$mark"*) ;; *) fail "clones.sh stops before its $stop stop" "$out" ;; esac
  check "clones.sh leaves nothing in TMPDIR after its $stop stop" '' "$(ls -A "$tmp/stoptmp")"
done
# No TMPDIR: the run goes to the person's real ~/.cache, as it does in use,
# unless this machine's home is refused.
if out=$(env -u TMPDIR PATH="$fake" bash "$clones" "$tree" 2>"$tmp/err"); then
  check 'no TMPDIR: the cache directory' "$rows" "$out"
  case $(sed -n 2p "$FAKE_LOG") in "$(cd "$HOME/.cache" && pwd -P)/clones."*) ;; *) fail 'no TMPDIR: the run in ~/.cache' "$(cat "$FAKE_LOG")" ;; esac
  [ ! -e "$(sed -n 2p "$FAKE_LOG")" ] || fail 'no TMPDIR: the run left in ~/.cache' "$(sed -n 2p "$FAKE_LOG")"
else
  case $(cat "$tmp/err") in
    *"$refused" | *"$taken") echo "debt_scripts_test: no TMPDIR not run: $(cat "$tmp/err")" ;;
    *) fail 'no TMPDIR' "$(cat "$tmp/err")" ;;
  esac
fi
err=$(env -u TMPDIR -u HOME PATH="$fake" bash "$clones" "$tree" 2>&1) && fail 'no TMPDIR and no HOME exits 0' "$err"
check 'no TMPDIR and no HOME' 'clones.sh: set TMPDIR or HOME' "$err"
err=$(TMPDIR=relative PATH=$fake bash "$clones" "$tree" 2>&1) && fail 'a relative TMPDIR exits 0' "$err"
check 'a relative TMPDIR' 'clones.sh: TMPDIR must be an absolute path' "$err"
err=$(cd "$tmp" && env -u TMPDIR HOME=relhome PATH="$fake" bash "$clones" "$tree" 2>&1) && fail 'a relative HOME exits 0' "$err"
check 'a relative HOME' 'clones.sh: HOME must be an absolute path' "$err"
[ ! -e "$tmp/relhome" ] || fail 'a relative HOME made a directory'
err=$(TMPDIR=$tmp/missing PATH=$fake bash "$clones" "$tree" 2>&1) && fail 'a TMPDIR that does not exist exits 0' "$err"
check 'a TMPDIR that does not exist' 'clones.sh: TMPDIR is not a directory' "$err"
jq '.duplicates = []' "$FAKE_REPORT" >"$tmp/none.json"
out=$(FAKE_REPORT=$tmp/none.json PATH=$fake bash "$clones" "$tree")
check 'no clones' 'No clones of 15 lines or more.' "$out"
echo null >"$tmp/null.json"
err=$(FAKE_REPORT=$tmp/null.json PATH=$fake bash "$clones" "$tree" 2>&1) && fail 'a report of another shape exits 0' "$err"
check 'a report of another shape' 'clones.sh: jscpd wrote no report that can be read' "$err"

err=$(PATH=$fake bash "$clones" "$tree" migrations 2>&1) && fail 'a path with only SQL exits 0' "$err"
check 'a path with only SQL' 'No code files under migrations.' "$err"
err=$(PATH=$fake bash "$clones" "$tmp" 2>&1) && fail 'a tree that is not a checkout exits 0' "$err"
FAKE_FAIL=1 PATH=$fake bash "$clones" "$tree" 2>/dev/null && fail 'a failed jscpd exits 0'
err=$(FAKE_ROOT=/elsewhere PATH=$fake bash "$clones" "$tree" 2>&1) && fail 'a path outside the copy exits 0' "$err"
check 'a path outside the copy' 'clones.sh: jscpd gave a path outside the copy' "$err"
above() {
  err=$(TMPDIR=$1 PATH=$fake bash "$clones" "$tree" 2>&1) && fail "$2 exits 0" "$err"
  check "$2" "clones.sh: $3" "$err"
}
for f in package.json node_modules .ignore; do
  mkdir -p "$tmp/above-$f/tmp"
  : >"$tmp/above-$f/$f"
  above "$tmp/above-$f/tmp" "a $f above the temporary directory" "$up/above-$f/$f $taken"
done
mkdir -p "$tmp/above-link/tmp" "$tmp/shared/tmp" "$tmp/group/tmp" "$tmp/plain/tmp"
ln -s missing "$tmp/above-link/node_modules"
above "$tmp/above-link/tmp" 'a node_modules link to nothing above' "$up/above-link/node_modules $taken"
chmod o+w "$tmp/shared"
above "$tmp/shared/tmp" 'a directory that others can write above' "$up/shared, above the temporary directory, $refused"
# A directory that a group can write passes only when the group is the
# person's own, as with user private groups; that run needs $tmp itself to be
# below private directories only, which /tmp on Linux is not.
chgrp "$(id -g)" "$tmp/group"
chmod g+w "$tmp/group"
if [ "$(id -gn)" != "$(id -un)" ]; then
  above "$tmp/group/tmp" 'a directory that a group can write above' "$up/group, above the temporary directory, $refused"
elif TMPDIR=$tmp/plain/tmp PATH=$fake bash "$clones" "$tree" >/dev/null 2>&1; then
  out=$(TMPDIR=$tmp/group/tmp PATH=$fake bash "$clones" "$tree")
  check 'a directory of the own group above' "$rows" "$out"
else
  echo 'debt_scripts_test: the own group not run, the test directory is below a shared one'
fi

# bunx with bun, on a PATH with no npx, where /usr/bin and /bin have none;
# bun itself, not a version manager's shim.
if command -v bun >/dev/null && [ ! -e /usr/bin/npx ] && [ ! -e /bin/npx ] &&
  "$(command -v bun)" --version >/dev/null 2>&1; then
  mkdir "$tmp/bunbin"
  cp "$tmp/bin/npx" "$tmp/bunbin/bunx"
  ln -s "$(command -v bun)" "$tmp/bunbin/bun"
  out=$(PATH=$tmp/bunbin:/usr/bin:/bin bash "$clones" "$tree")
  check 'bunx with bun' "$rows" "$out"
  check 'bunx' "$(printf '%s\n' bunx "$args")" "$(sed -n '1p;3p' "$FAKE_LOG")"
  case $(sed -n 2p "$FAKE_LOG") in "$real"*) fail 'bunx ran in the tree' "$(cat "$FAKE_LOG")" ;; esac
else
  echo 'debt_scripts_test: bunx not run, no bun of its own or an npx in /usr/bin or /bin'
fi
echo 'debt_scripts_test: ok'
