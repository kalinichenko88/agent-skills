#!/usr/bin/env bash
# Runs the architecture skill's invariants.sh on repositories it builds: a grep
# check that finds a fetch outside the API client, in a file with a non-ASCII
# name, past a document that holds the same text; a pattern that starts with a
# dash; a pattern that looks like a shell command; an invariant with no Check:
# line, and one in a fenced example. Then the same file with CRLF line ends, at
# the root, from a subdirectory, with an untracked file and at a ref, and the
# calls that must stop with exit 2.

# shellcheck disable=SC2016 # the backticks are Markdown's
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
# A person's color.ui=always must not reach what the script reads from git; it
# goes after any configuration the environment already gives git.
n=${GIT_CONFIG_COUNT:-0}
export "GIT_CONFIG_KEY_$n=color.ui" "GIT_CONFIG_VALUE_$n=always" GIT_CONFIG_COUNT=$((n + 1))
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

run "$repo" nosuchref
check 'not a commit' '2 invariants.sh: not a commit: nosuchref' "$code $err"
run "$repo" a b
check 'usage' '2 usage: invariants.sh [--new-since <base>] [ref]' "$code $err"

echo 'architecture_scripts_test: ok'
