#!/usr/bin/env bash
# Runs the architecture skill's invariants.sh on repositories it builds: a grep
# check that finds a fetch outside the API client, in a file with a non-ASCII
# name, past a document that holds the same text; a pattern that starts with a
# dash; a pattern that looks like a shell command; an invariant with no Check:
# line, and one in a fenced example. Then the same file with CRLF line ends, at
# the root, from a subdirectory, with an untracked file and at a ref, and the
# calls that must stop with exit 2. A second repository holds the lines and
# files checks and the debt lists.

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

repo=$tmp/repo
new_repo "$repo"
mkdir -p "$repo/src/api" "$repo/src/feature" "$repo/src/styles" "$repo/docs"
echo 'export const get = (u) => fetch(u);' >"$repo/src/api/client.ts"
printf '%s\n' "import { get } from '../api/client';" "const r = fetch('/list');" >"$repo/src/feature/list.ts"
echo "fetch('/order');" >"$repo/src/feature/заказ.ts"
echo 'fetch( in a document' >"$repo/src/notes.md"
echo '.x { -webkit-box: 1; }' >"$repo/src/styles/a.css"
cat >"$repo/docs/ARCHITECTURE.md" <<'EOF'
# Architecture

```markdown
- **I-9.** An example in a fence.
  Check: grep `nothing` in `src/`.
```

## Invariants

- **I-1.** Only `src/api/client.ts` calls `fetch`.
  Check: grep `fetch\(` in `src/` except `src/api/client.ts`.
  ADR: 0001.
- **I-2.** No vendor prefix in styles.
  Check: grep `-webkit-` in `src/styles/`.
- **I-3.** A pattern is never a command.
  Check: grep `$(touch pwned)` in `src/`.
- **I-4.** Modules talk through their index files.
EOF
commit "$repo" 'add the tree'

want=$(printf '%s\n' 'I-1 FAIL' \
  "  src/feature/list.ts:2:const r = fetch('/list');" \
  "  src/feature/заказ.ts:1:fetch('/order');" \
  'I-2 FAIL' '  src/styles/a.css:1:.x { -webkit-box: 1; }' \
  'I-3 PASS' 'I-4 review only')
run "$repo"
check 'the working tree' "1 $want" "$code $out"
[ ! -e "$repo/pwned" ] && [ ! -e "$repo/src/pwned" ] || fail 'a pattern ran as a command'

run "$repo/src"
check 'a subdirectory' "1 $want" "$code $out"

awk '{ printf "%s\r\n", $0 }' "$repo/docs/ARCHITECTURE.md" >"$tmp/crlf"
cp "$tmp/crlf" "$repo/docs/ARCHITECTURE.md"
run "$repo"
check 'CRLF' "1 $want" "$code $out"
git -C "$repo" checkout -q -- .

mv "$repo/docs/ARCHITECTURE.md" "$repo/ARCHITECTURE.md"
run "$repo"
check 'the root file' "1 $want" "$code $out"
mv "$repo/ARCHITECTURE.md" "$repo/docs/ARCHITECTURE.md"

echo 'fetch(n);' >"$repo/src/feature/new.ts"
run "$repo"
check 'an untracked file' "1 $(printf '%s\n' 'I-1 FAIL' \
  "  src/feature/list.ts:2:const r = fetch('/list');" \
  '  src/feature/new.ts:1:fetch(n);' \
  "  src/feature/заказ.ts:1:fetch('/order');" \
  'I-2 FAIL' '  src/styles/a.css:1:.x { -webkit-box: 1; }' \
  'I-3 PASS' 'I-4 review only')" "$code $out"
run "$repo" HEAD
check 'a ref' "1 $want" "$code $out"
rm "$repo/src/feature/new.ts"

empty=$tmp/empty
new_repo "$empty"
mkdir "$empty/src"
echo 'fetch(u);' >"$empty/src/a.ts"
commit "$empty" 'add a'
run "$empty"
check 'no file' '0 No architecture file in the working tree.' "$code $out"
run "$empty" HEAD
check 'no file at a ref' '0 No architecture file at HEAD.' "$code $out"

mkdir "$empty/docs"
printf '%s\n' '- **I-1.** No fetch.' '  Check: grep fetch in src/' >"$empty/docs/ARCHITECTURE.md"
run "$empty"
check 'a line it cannot read' '2 invariants.sh: I-1: cannot read: Check: grep fetch in src/' "$code $err"
printf '%s\n' '- **I-1.** No fetch.' '  Check: grep `fetch\(` in `srcx/`.' >"$empty/docs/ARCHITECTURE.md"
run "$empty"
check 'a typo in a path' '2 invariants.sh: I-1: no code file under srcx/' "$code $err"

# A debt line belongs to the Check: line of its invariant wherever it stands
# in the block after it. A line that the script would drop changes what a
# check means, so it stops the run: a debt line with no Check: line, and a
# Check: line that a person or a formatter wrapped.
printf '%s\n' '- **I-1.** No code file in `src/` has a line.' '  Check: lines 0 in `src/`.' \
  '  ADR: 0001.' '' '  debt `src/a.ts`.' >"$empty/docs/ARCHITECTURE.md"
run "$empty"
check 'a debt line after the ADR line' "0 $(printf '%s\n' 'I-1 PASS' '  debt src/a.ts 1')" "$code $out"
printf '%s\n' '- **I-1.** No fetch.' '  debt `src/a.ts`.' >"$empty/docs/ARCHITECTURE.md"
run "$empty"
check 'a debt line with no Check: line' '2 invariants.sh: I-1: cannot read: debt `src/a.ts`.' "$code $err"
printf '%s\n' '- **I-1.** No fetch.' '  Check: grep `fetch\(` in `src/`' '  `lib/` except `src/a.ts`.' >"$empty/docs/ARCHITECTURE.md"
run "$empty"
check 'a Check: line that wraps at a path' '2 invariants.sh: I-1: cannot read: `lib/` except `src/a.ts`.' "$code $err"
printf '%s\n' '- **I-1.** No fetch.' '  Check: grep `fetch\(` in `src/`' '  except `src/a.ts`.' >"$empty/docs/ARCHITECTURE.md"
run "$empty"
check 'a Check: line that wraps at except' '2 invariants.sh: I-1: cannot read: except `src/a.ts`.' "$code $err"
printf '%s\n' '- **I-1.** No fetch.' '  Check: grep `fetch\(` in `src/`,' '  `lib/` (the legacy part).' >"$empty/docs/ARCHITECTURE.md"
run "$empty"
check 'a Check: line that wraps before words' '2 invariants.sh: I-1: cannot read: `lib/` (the legacy part).' "$code $err"
printf '%s\n' '- **I-1.** No fetch.' '  Check: grep `fetch\(` in `src/`.' '  debt `src/a.ts` until the split.' >"$empty/docs/ARCHITECTURE.md"
run "$empty"
check 'a debt line with words after its path' '2 invariants.sh: I-1: cannot read: debt `src/a.ts` until the split.' "$code $err"

# Prose is not a check: a wrapped sentence that starts with "debt", and one
# right after a Check: line that starts with "in".
printf '%s\n' '- **I-1.** No fetch, and the' '  debt is described in prose.' \
  '  Check: grep `fetch\(` in `src/` debt `src/a.ts`.' '  in the meantime the client wraps it.' >"$empty/docs/ARCHITECTURE.md"
run "$empty"
check 'prose that starts with debt or in' "0 $(printf '%s\n' 'I-1 PASS' '  debt src/a.ts:1:fetch(u);')" "$code $out"

# A Check: line with no invariant above it would never run: a * bullet, or the
# period outside the bold.
printf '%s\n' '* **I-1.** No fetch.' '  Check: grep `fetch\(` in `src/`.' >"$empty/docs/ARCHITECTURE.md"
run "$empty"
check 'a Check: line outside an invariant' \
  '2 invariants.sh: a Check: line outside an invariant: Check: grep `fetch\(` in `src/`.' "$code $err"

# A fenced example is skipped when its fence is indented, or made of tildes.
printf '%s\n' '- **I-1.** No fetch.' '  Check: grep `fetch\(` in `src/` debt `src/a.ts`.' '  ```ts' \
  '  Check: grep `x` in `nope/`.' '  ```' '~~~markdown' '- **I-2.** An example.' '  Check: grep `x` in `nope/`.' \
  '~~~' >"$empty/docs/ARCHITECTURE.md"
run "$empty"
check 'an indented and a tilde fence' "0 $(printf '%s\n' 'I-1 PASS' '  debt src/a.ts:1:fetch(u);')" "$code $out"
# A fence at the start of a line ends the invariant, as any such line does, so
# a debt line after it is outside the invariant.
printf '%s\n' '- **I-1.** No fetch.' '  Check: grep `fetch\(` in `src/`.' '```text' '```' \
  '  debt `src/a.ts`.' >"$empty/docs/ARCHITECTURE.md"
run "$empty"
check 'a fence at the start of a line' '2 invariants.sh: a debt line outside an invariant: debt `src/a.ts`.' "$code $err"
# A fence closes only at a line of its own character, as long or longer, with
# nothing after it. One that never closes would hide each invariant below it.
printf '%s\n' '- **I-1.** No fetch.' '  Check: grep `fetch\(` in `src/` debt `src/a.ts`.' '````markdown' \
  '- **I-2.** An example.' '  ```ts' '  Check: grep `x` in `nope/`.' '  ```' '````' >"$empty/docs/ARCHITECTURE.md"
run "$empty"
check 'a fence that holds a shorter one' "0 $(printf '%s\n' 'I-1 PASS' '  debt src/a.ts:1:fetch(u);')" "$code $out"
printf '%s\n' '```' '- **I-1.** No fetch.' '  Check: grep `fetch\(` in `src/`.' >"$empty/docs/ARCHITECTURE.md"
run "$empty"
check 'a fence that does not close' '2 invariants.sh: a code fence that does not close, at line 1' "$code $err"
# A fence closes at its closing line, indented as far as its opening line or
# up to 3 more. A non-blank line indented less before that, as at the end of
# the list item that holds the fence, stops the run: the lines that the fence
# hides could hold a check.
printf '%s\n' '- **I-1.** No fetch. Example:' '  ```ts' '  fetch(u)' '  Check: grep `fetch\(` in `src/`.' \
  '- **I-2.** Other.' >"$empty/docs/ARCHITECTURE.md"
run "$empty"
check 'a fence that its invariant does not close' \
  '2 invariants.sh: a code fence at line 2 does not close before line 5' "$code $err"
printf '%s\n' '- A note:' '  ```' '  x' '- **I-1.** No fetch.' '  Check: grep `fetch\(` in `src/`.' \
  '- **I-2.** Example:' '  ```ts' '  foo' '  ```' >"$empty/docs/ARCHITECTURE.md"
run "$empty"
check 'a fence that its list item does not close' \
  '2 invariants.sh: a code fence at line 2 does not close before line 4' "$code $err"
printf '%s\n' '- **I-1.** An example.' '  ```' '  x' '```' '- **I-2.** No fetch.' \
  '  Check: grep `fetch\(` in `src/`.' >"$empty/docs/ARCHITECTURE.md"
run "$empty"
check 'a closing line indented less than its fence' \
  '2 invariants.sh: a code fence at line 2 does not close before line 4' "$code $err"
# A closing line closes a fence in a list item only at the fence's own indent;
# one indented 4 or more past it is a line of code. One indented 1 to 3 past
# it stops the run: Markdown counts those 3 from the margin of the list item,
# which the script does not know.
printf '%s\n' '- **I-1.** An example.' '  ```' '      ```' '  Check: grep `fetch\(` in `src/`.' '     ```' \
  '- **I-2.** No fetch.' '  Check: grep `fetch\(` in `src/`.' >"$empty/docs/ARCHITECTURE.md"
run "$empty"
check 'a closing line indented past its fence' \
  '2 invariants.sh: a code fence at line 2 has a closing line indented past it, at line 5' "$code $err"
# The case of #115: the closing line is 3 past its fence, and 4 past its list
# item, so Markdown keeps the fence open. A second fence-like line then hid
# the Check: line, and the run passed.
printf '%s\n' '- **I-1.** No fetch.' '   ```' '   a' '      ```' '   ```' '   Check: grep `fetch\(` in `src/`.' '' \
  '      ```' >"$empty/docs/ARCHITECTURE.md"
run "$empty"
check 'a closing line past the margin of its list item' \
  '2 invariants.sh: a code fence at line 2 has a closing line indented past it, at line 4' "$code $err"
# A tab moves to the next multiple of 4 columns, as in Markdown: two tabs are
# 8 columns, a line of code in a fence at 2.
printf '%s\n' '- **I-1.** An example.' '  ```' $'\t\t```' '  Check: grep `x` in `nope/`.' '  ```' \
  '- **I-2.** No fetch.' '  Check: grep `fetch\(` in `src/`.' >"$empty/docs/ARCHITECTURE.md"
run "$empty"
check 'a closing line indented by tabs' "1 $(printf '%s\n' 'I-1 review only' 'I-2 FAIL' '  src/a.ts:1:fetch(u);')" "$code $out"
# A fence at column 0 is in no list item, so its margin is 0, and a closing
# line up to 3 past it closes it. The shape of 4 of 2,359 fences in a sample
# of real documents: 300 files, of private projects, so the text is neutral.
printf '%s\n' '```' 'x' '   ```' '- **I-1.** No fetch.' '  Check: grep `fetch\(` in `src/`.' >"$empty/docs/ARCHITECTURE.md"
run "$empty"
check 'a fence at column 0 that closes past it' "1 $(printf '%s\n' 'I-1 FAIL' '  src/a.ts:1:fetch(u);')" "$code $out"
# A run of backticks with another backtick later on the line is inline code,
# not a fence.
printf '%s\n' '```x``` is code.' '- **I-1.** An example.' '  ```' '  x' '  ```' '- **I-2.** No fetch.' \
  '  Check: grep `fetch\(` in `src/`.' >"$empty/docs/ARCHITECTURE.md"
run "$empty"
check 'fences that close' "1 $(printf '%s\n' 'I-1 review only' 'I-2 FAIL' '  src/a.ts:1:fetch(u);')" "$code $out"

# An except path that covers each code file of the check leaves it nothing to
# read, as a typo does.
printf '%s\n' '- **I-1.** No fetch.' '  Check: grep `fetch\(` in `src/` except `src/`.' >"$empty/docs/ARCHITECTURE.md"
run "$empty"
check 'an except path over the whole check' '2 invariants.sh: I-1: no code file under src/' "$code $err"

# An empty code file is a code file: a files check counts it.
: >"$empty/src/b.ts"
printf '%s\n' '- **I-1.** One code file in `src/`.' '  Check: files 1 in `src/`.' >"$empty/docs/ARCHITECTURE.md"
run "$empty"
check 'an empty code file' "1 $(printf '%s\n' 'I-1 FAIL' '  src 2')" "$code $out"
rm "$empty/src/b.ts"

# Without the debt skill beside it, the script cannot tell code from data.
mkdir -p "$tmp/alone/scripts"
cp "$inv" "$tmp/alone/scripts/"
code=0
out=$(cd "$empty" && bash "$tmp/alone/scripts/invariants.sh" 2>"$tmp/err") || code=$?
check 'no debt skill beside it' "2 invariants.sh: the debt skill's data.ere is not beside this skill" "$code $(cat "$tmp/err")"

# The lines and files checks, and debt lists: a file and a folder past their
# limits, a file and a folder that are known debt, a debt path that no longer
# breaks its check, a document past the limit that is not code, and a
# subfolder whose files do not count for the folder above it.
repo2=$tmp/repo2
new_repo "$repo2"
mkdir -p "$repo2/src/feature" "$repo2/src/legacy" "$repo2/src/many/sub" "$repo2/docs"
seq 11 >"$repo2/src/feature/big.ts"
seq 3 >"$repo2/src/feature/small.ts"
seq 11 >"$repo2/src/legacy/report.ts"
echo 'fetch(x);' >>"$repo2/src/legacy/report.ts"
seq 50 >"$repo2/src/notes.md"
for f in m1 m2 m3 m4 sub/s1 sub/s2; do echo 1 >"$repo2/src/many/$f.ts"; done
cat >"$repo2/docs/ARCHITECTURE.md" <<'EOF'
- **I-1.** No code file in `src/` has more than 10 lines.
  Check: lines 10 in `src/` debt `src/legacy/report.ts`
  debt `src/legacy/old.ts`.
- **I-2.** No folder in `src/` holds more than 3 code files of its own.
  Check: files 3 in `src/`.
- **I-3.** The same, with the folder as debt.
  Check: files 3 in `src/many/` debt `src/many/`.
- **I-4.** No `fetch` outside the API client.
  Check: grep `fetch\(` in `src/` debt `src/legacy/report.ts`.
EOF
commit "$repo2" 'add the tree'
run "$repo2"
check 'lines, files and debt' "1 $(printf '%s\n' 'I-1 FAIL' '  src/feature/big.ts 11' \
  '  debt src/legacy/report.ts 12' '  no longer debt src/legacy/old.ts' \
  'I-2 FAIL' '  src/many 4' \
  'I-3 PASS' '  debt src/many 4' \
  'I-4 PASS' '  debt src/legacy/report.ts:12:fetch(x);')" "$code $out"

# --new-since: a file renamed with no edit stays old, a hit that the branch
# adds to an old file or in a new one is new, a known debt that grows is new
# debt, and a file that moves into the checked folder is new. The base has no
# architecture file.
repo3=$tmp/repo3
new_repo "$repo3"
mkdir -p "$repo3/src/api" "$repo3/src/feature" "$repo3/src/legacy" "$repo3/src/many" "$repo3/tools"
echo 'export const get = (u) => fetch(u);' >"$repo3/src/api/client.ts"
printf '%s\n' 'const x = 1;' 'fetch(u);' >"$repo3/src/feature/a.ts"
seq 11 >"$repo3/src/legacy/report.ts"
echo 'fetch(x);' >>"$repo3/src/legacy/report.ts"
seq 11 >"$repo3/src/legacy/grow.ts"
for f in m1 m2 m3 m4; do echo 1 >"$repo3/src/many/$f.ts"; done
seq 15 >"$repo3/tools/migrate.ts"
commit "$repo3" 'add the base'
base=$(git -C "$repo3" rev-parse HEAD)
mkdir -p "$repo3/src/cli" "$repo3/docs"
git -C "$repo3" mv src/legacy/report.ts src/legacy/summary.ts
git -C "$repo3" mv tools/migrate.ts src/cli/migrate.ts
seq 14 >"$repo3/src/legacy/grow.ts"
echo 'fetch(u);' >>"$repo3/src/feature/a.ts"
echo 'fetch(v);' >"$repo3/src/feature/b.ts"
echo 1 >"$repo3/src/many/m5.ts"
cat >"$repo3/docs/ARCHITECTURE.md" <<'EOF'
- **I-1.** Only `src/api/client.ts` calls `fetch`.
  Check: grep `fetch\(` in `src/` except `src/api/client.ts` debt `src/legacy/summary.ts`.
- **I-2.** No code file in `src/` has more than 10 lines.
  Check: lines 10 in `src/` debt `src/legacy/summary.ts`
  debt `src/legacy/grow.ts`.
- **I-3.** No folder in `src/` holds more than 3 code files of its own.
  Check: files 3 in `src/` debt `src/many/`.
EOF
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
run "$repo3" --new-since "$base" "$base"
check 'no file at the ref' "0 No architecture file at $base." "$code $out"
run "$repo3" --new-since nosuchref
check 'a base that is not a commit' '2 invariants.sh: not a commit: nosuchref' "$code $err"

run "$repo" nosuchref
check 'not a commit' '2 invariants.sh: not a commit: nosuchref' "$code $err"
run "$repo" a b
check 'usage' '2 usage: invariants.sh [--new-since <base>] [ref]' "$code $err"

echo 'architecture_scripts_test: ok'
