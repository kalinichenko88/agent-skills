#!/usr/bin/env bash
# Runs the architecture skill's invariants.sh on architecture files with code
# fences: the lines inside a fence are skipped, as Markdown shows them as code,
# and a fence that the script cannot read as Markdown does stops the run.

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

empty=$tmp/empty
new_repo "$empty"
mkdir "$empty/src" "$empty/docs"
echo 'fetch(u);' >"$empty/src/a.ts"
commit "$empty" 'add a'

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
# nothing but spaces or tabs after it. One that never closes would hide each
# invariant below it.
printf '%s\n' '- **I-1.** No fetch.' '  Check: grep `fetch\(` in `src/` debt `src/a.ts`.' '````markdown' \
  '- **I-2.** An example.' '  ```ts' '  Check: grep `x` in `nope/`.' '  ```' '````' >"$empty/docs/ARCHITECTURE.md"
run "$empty"
check 'a fence that holds a shorter one' "0 $(printf '%s\n' 'I-1 PASS' '  debt src/a.ts:1:fetch(u);')" "$code $out"
printf '%s\n' '```' '- **I-1.** No fetch.' '  Check: grep `fetch\(` in `src/`.' >"$empty/docs/ARCHITECTURE.md"
run "$empty"
check 'a fence that does not close' '2 invariants.sh: a code fence that does not close, at line 1' "$code $err"
# A non-blank line indented less than a fence, before its closing line, as at
# the end of the list item that holds the fence, stops the run: the lines that
# the fence hides could hold a check.
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
# A closing line closes an indented fence only at the fence's own indent;
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
# 8 columns, a line of code in a fence indented by 2.
printf '%s\n' '- **I-1.** An example.' '  ```' $'\t\t```' '  Check: grep `x` in `nope/`.' '  ```' \
  '- **I-2.** No fetch.' '  Check: grep `fetch\(` in `src/`.' >"$empty/docs/ARCHITECTURE.md"
run "$empty"
check 'a closing line indented by tabs' "1 $(printf '%s\n' 'I-1 review only' 'I-2 FAIL' '  src/a.ts:1:fetch(u);')" "$code $out"
# A fence at column 0 is in no list item, so its margin is 0, and a closing
# line up to 3 past it closes it. 4 of 2,359 fences in a sample of 300 real
# files have this shape. The files are from private projects, so the test
# text is neutral.
printf '%s\n' '```' 'x' '   ```' '- **I-1.** No fetch.' '  Check: grep `fetch\(` in `src/`.' >"$empty/docs/ARCHITECTURE.md"
run "$empty"
check 'a fence at column 0 that closes past it' "1 $(printf '%s\n' 'I-1 FAIL' '  src/a.ts:1:fetch(u);')" "$code $out"
# A run of backticks with another backtick later on the line is inline code,
# not a fence.
printf '%s\n' '```x``` is code.' '- **I-1.** An example.' '  ```' '  x' '  ```' '- **I-2.** No fetch.' \
  '  Check: grep `fetch\(` in `src/`.' >"$empty/docs/ARCHITECTURE.md"
run "$empty"
check 'fences that close' "1 $(printf '%s\n' 'I-1 review only' 'I-2 FAIL' '  src/a.ts:1:fetch(u);')" "$code $out"

echo 'architecture_fences_test: ok'
