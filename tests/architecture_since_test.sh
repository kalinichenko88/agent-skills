#!/usr/bin/env bash
# Runs the architecture skill's invariants.sh --new-since on a repository it
# builds, commit by commit: a base with no architecture file, a branch that
# renames and adds hits under rules it keeps, a branch that changes its rules,
# and a base file that the script cannot read.

# shellcheck disable=SC2016 # the backticks are Markdown's
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
# A person's color.ui=always or grep.column=true must not reach what the
# script reads from git; they go after any configuration the environment
# already gives git.
n=${GIT_CONFIG_COUNT:-0}
export "GIT_CONFIG_KEY_$n=color.ui" "GIT_CONFIG_VALUE_$n=always" \
  "GIT_CONFIG_KEY_$((n + 1))=grep.column" "GIT_CONFIG_VALUE_$((n + 1))=true" GIT_CONFIG_COUNT=$((n + 2))
inv=$root/skills/architecture/scripts/invariants.sh
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fail() {
  printf 'FAIL: %s\n' "$1"
  [ -z "${2:-}" ] || printf '%s\n' "$2"
  exit 1
}
check() { [ "$2" = "$3" ] || fail "$1" "$(printf 'want: %s\ngot:  %s' "$2" "$3")"; }

new_repo() {
  mkdir -p "$1"
  git -C "$1" init -q -b main
  git -C "$1" config user.name test
  git -C "$1" config user.email test@example.com
}
# -f, so that a global gitignore cannot drop a file the test needs.
commit() { git -C "$1" add -A -f && git -C "$1" commit -qm "$2"; }
# run <dir> [arg...]: runs invariants.sh in <dir>, and sets code, out and err.
run() {
  local dir=$1
  shift
  code=0
  out=$(cd "$dir" && bash "$inv" "$@" 2>"$tmp/err") || code=$?
  err=$(cat "$tmp/err")
}

# --new-since: a file renamed with no edit stays old, a hit that the branch
# adds to an old file or in a new one is new, a known debt that grows is new
# debt, and a file that moves into the checked folder is new. The base has the
# same rules, with the old name of the renamed debt file. The commit before it
# has no architecture file, so against it each hit is new.
repo3=$tmp/repo3
new_repo "$repo3"
mkdir -p "$repo3/src/api" "$repo3/src/feature" "$repo3/src/legacy" "$repo3/src/many" "$repo3/tools" "$repo3/docs"
echo 'export const get = (u) => fetch(u);' >"$repo3/src/api/client.ts"
printf '%s\n' 'const x = 1;' 'fetch(u);' >"$repo3/src/feature/a.ts"
seq 11 >"$repo3/src/legacy/report.ts"
echo 'fetch(x);' >>"$repo3/src/legacy/report.ts"
seq 11 >"$repo3/src/legacy/grow.ts"
for f in m1 m2 m3 m4; do echo 1 >"$repo3/src/many/$f.ts"; done
seq 15 >"$repo3/tools/migrate.ts"
commit "$repo3" 'add the code'
first=$(git -C "$repo3" rev-parse HEAD)
cat >"$tmp/rules" <<'EOF'
- **I-1.** Only `src/api/client.ts` calls `fetch`.
  Check: grep `fetch\(` in `src/` except `src/api/client.ts` debt `src/legacy/report.ts`.
- **I-2.** No code file in `src/` has more than 10 lines.
  Check: lines 10 in `src/` debt `src/legacy/report.ts`
  debt `src/legacy/grow.ts`.
- **I-3.** No folder in `src/` holds more than 3 code files of its own.
  Check: files 3 in `src/` debt `src/many/`.
EOF
cp "$tmp/rules" "$repo3/docs/ARCHITECTURE.md"
commit "$repo3" 'add the rules'
base=$(git -C "$repo3" rev-parse HEAD)
run "$repo3" --new-since "$first" "$base"
check 'no file at the base' "1 $(printf '%s\n' 'I-1 FAIL' '  new src/feature/a.ts:2:fetch(u);' \
  '  new debt src/legacy/report.ts:12:fetch(x);' \
  'I-2 PASS' '  new debt src/legacy/grow.ts 11' '  new debt src/legacy/report.ts 12' \
  'I-3 PASS' '  new debt src/many 4')" "$code $out"
check 'no file at the base, on stderr' "invariants.sh: at $first: no architecture file, so each hit is new" "$err"
mkdir -p "$repo3/src/cli"
git -C "$repo3" mv src/legacy/report.ts src/legacy/summary.ts
git -C "$repo3" mv tools/migrate.ts src/cli/migrate.ts
seq 14 >"$repo3/src/legacy/grow.ts"
echo 'fetch(u);' >>"$repo3/src/feature/a.ts"
echo 'fetch(v);' >"$repo3/src/feature/b.ts"
echo 1 >"$repo3/src/many/m5.ts"
sed 's/report\.ts/summary.ts/' "$tmp/rules" >"$repo3/docs/ARCHITECTURE.md"
commit "$repo3" 'add the branch'
want=$(printf '%s\n' 'I-1 FAIL' \
  '  src/feature/a.ts:2:fetch(u);' \
  '  new src/feature/a.ts:3:fetch(u);' \
  '  new src/feature/b.ts:1:fetch(v);' \
  '  debt src/legacy/summary.ts:12:fetch(x);' \
  'I-2 FAIL' '  new src/cli/migrate.ts 15' \
  '  new debt src/legacy/grow.ts 14' '  debt src/legacy/summary.ts 12' \
  'I-3 PASS' '  new debt src/many 5')
run "$repo3" --new-since "$base" HEAD
check 'new since the base' "1 $want" "$code $out"
run "$repo3" --new-since "$base"
check 'new since the base, working tree' "1 $want" "$code $out"
run "$repo3" --new-since "$first" "$first"
check 'no file at the ref' "0 No architecture file at $first." "$code $out"

# A branch that changes its rules: I-1 loses its except path, I-2 takes a
# folder as debt, and I-4 is new. A hit is new when the base does not have it
# with the same status: a file moved out from under a debt path fails now, and
# a file that failed is now debt.
mid=$(git -C "$repo3" rev-parse HEAD)
git -C "$repo3" mv src/cli/migrate.ts src/legacy/migrate.ts
git -C "$repo3" mv src/legacy/grow.ts src/feature/grow.ts
cat >"$repo3/docs/ARCHITECTURE.md" <<'EOF'
- **I-1.** Nothing calls `fetch`.
  Check: grep `fetch\(` in `src/` debt `src/legacy/summary.ts`.
- **I-2.** No code file in `src/` has more than 10 lines.
  Check: lines 10 in `src/` debt `src/legacy/`.
- **I-3.** No folder in `src/` holds more than 3 code files of its own.
  Check: files 3 in `src/` debt `src/many/`.
- **I-4.** No `const`.
  Check: grep `const` in `src/`.
EOF
commit "$repo3" 'change the rules'
run "$repo3" --new-since "$mid" HEAD
check 'changed rules' "1 $(printf '%s\n' 'I-1 FAIL' \
  '  new src/api/client.ts:1:export const get = (u) => fetch(u);' \
  '  src/feature/a.ts:2:fetch(u);' '  src/feature/a.ts:3:fetch(u);' '  src/feature/b.ts:1:fetch(v);' \
  '  debt src/legacy/summary.ts:12:fetch(x);' \
  'I-2 FAIL' '  new src/feature/grow.ts 14' '  new debt src/legacy/migrate.ts 15' \
  '  debt src/legacy/summary.ts 12' 'I-3 PASS' '  debt src/many 5' \
  'I-4 FAIL' '  new src/api/client.ts:1:export const get = (u) => fetch(u);' \
  '  new src/feature/a.ts:1:const x = 1;')" "$code $out"

# A base file whose I-1 has a pattern that git rejects and whose I-3 the
# script cannot read: I-2 is compared as before, each hit of I-1 and I-3 is
# new, and stderr says why, at the base.
printf '%s\n' '- **I-1.** a' '  Check: grep `fetch(u` in `src/feature/`.' \
  '- **I-2.** b' '  Check: grep `fetch\(v\)` in `src/feature/`.' \
  '- **I-3.** c' '  Check: grep const in src/' >"$repo3/docs/ARCHITECTURE.md"
commit "$repo3" 'break the rules'
printf '%s\n' '- **I-1.** a' '  Check: grep `fetch\(u\)` in `src/feature/`.' \
  '- **I-2.** b' '  Check: grep `fetch\(v\)` in `src/feature/`.' \
  '- **I-3.** c' '  Check: grep `const` in `src/feature/`.' >"$repo3/docs/ARCHITECTURE.md"
run "$repo3" --new-since HEAD
check 'a base file it cannot read' "1 $(printf '%s\n' 'I-1 FAIL' \
  '  new src/feature/a.ts:2:fetch(u);' '  new src/feature/a.ts:3:fetch(u);' \
  'I-2 FAIL' '  src/feature/b.ts:1:fetch(v);' 'I-3 FAIL' '  new src/feature/a.ts:1:const x = 1;')" "$code $out"
for line in 'invariants.sh: at HEAD: I-3: cannot read: Check: grep const in src/' \
  'invariants.sh: at HEAD: each hit of an invariant that the script did not read whole there is new' \
  'invariants.sh: at HEAD: I-1: git grep failed' 'invariants.sh: at HEAD: each hit of I-1 is new'; do
  grep -qxF "$line" <<<"$err" || fail "no line on stderr: $line" "$err"
done

# A base file whose I-2 holds, after its Check: line, a code fence that does
# not close: I-1 is compared, and I-2, which holds the fence, is not whole,
# as I-3 after it.
cp "$repo3/docs/ARCHITECTURE.md" "$tmp/head"
printf '%s\n' '- **I-1.** a' '  Check: grep `fetch\(u\)` in `src/feature/`.' \
  '- **I-2.** b' '  Check: grep `fetch\(v\)` in `src/feature/`.' '  ```text' \
  '- **I-3.** c' '  Check: grep `const` in `src/feature/`.' >"$repo3/docs/ARCHITECTURE.md"
commit "$repo3" 'open a fence'
cp "$tmp/head" "$repo3/docs/ARCHITECTURE.md"
run "$repo3" --new-since HEAD
check 'a base fence that does not close' "1 $(printf '%s\n' 'I-1 FAIL' \
  '  src/feature/a.ts:2:fetch(u);' '  src/feature/a.ts:3:fetch(u);' 'I-2 FAIL' \
  '  new src/feature/b.ts:1:fetch(v);' 'I-3 FAIL' '  new src/feature/a.ts:1:const x = 1;')" "$code $out"
grep -qxF 'invariants.sh: at HEAD: a code fence at line 5 does not close before line 6' <<<"$err" ||
  fail 'no line on stderr for the fence' "$err"

# A debt line with no indent in the base's file ends I-1 there: the base's
# I-1 has no debt list, so the hits under it are new debt.
printf '%s\n' '- **I-1.** a' '  Check: grep `fetch\(u\)` in `src/feature/`.' 'debt `src/feature/a.ts`.' >"$repo3/docs/ARCHITECTURE.md"
commit "$repo3" 'unindent a debt line'
printf '%s\n' '- **I-1.** a' '  Check: grep `fetch\(u\)` in `src/feature/`.' '  debt `src/feature/a.ts`.' >"$repo3/docs/ARCHITECTURE.md"
run "$repo3" --new-since HEAD
check 'a base debt line with no indent' "0 $(printf '%s\n' 'I-1 PASS' \
  '  new debt src/feature/a.ts:2:fetch(u);' '  new debt src/feature/a.ts:3:fetch(u);')" "$code $out"
run "$repo3" --new-since nosuchref
check 'a base that is not a commit' '2 invariants.sh: not a commit: nosuchref' "$code $err"

echo 'architecture_since_test: ok'
