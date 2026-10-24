#!/usr/bin/env bash
# Ranks the code files by their lines × the commits that touched them in 60
# days, highest first, and prints the top 15 as a Markdown table, then the ref
# and the SHA it read, and how many of the files the window moved.
#
#   measure.sh [path]
#
# The path is from the repository's root; without one, the whole tree. It reads
# origin/HEAD when the clone has it, else HEAD, through git, so it runs from any
# directory of any checkout. Documents, lockfiles, fixtures and other data are
# not code and are left out.
#
# Needs only bash, git and awk.

set -euo pipefail

[ $# -le 1 ] || {
  echo 'usage: measure.sh [path]' >&2
  exit 2
}
path=${1:-.}
cd "$(git rev-parse --show-toplevel)"
ref=$(git rev-parse --abbrev-ref --verify -q origin/HEAD || echo HEAD)
data='\.(md|txt|rst|json|ya?ml|toml|csv|svg|snap|lock)$|(^|/)(fixtures|testdata|vendor|__snapshots__)/|(^|/)go\.sum$'

# ponytail: renames are not followed, so a file moved inside the window counts
# its commits from the move; git log --follow per file if a hotspot hides
# behind one.
# core.quotePath=false keeps non-ASCII paths as they are, not as "\320...".
# ponytail: a path with a quote, a backslash, a tab or a newline still comes
# out quoted and counts as code; -z and NUL records if one turns up.
# The regex goes through ENVIRON, because awk -v turns \. into any character.
rows=$({
  git -c core.quotePath=false grep -I -c '' "$ref" -- "$path" || true
  echo '== log'
  git -c core.quotePath=false log --since=60.days --format= --name-only "$ref" -- "$path"
} | DATA=$data awk -v ref="$ref:" '
  $0 == "== log" { inlog = 1; next }
  !inlog {
    # ref:path:count; the path can hold a colon, the count cannot.
    n = $0; sub(/.*:/, "", n)
    f = substr($0, length(ref) + 1, length($0) - length(ref) - length(n) - 1)
    if (f !~ ENVIRON["DATA"]) lines[f] = n
    next
  }
  $0 in lines { commits[$0]++ }
  END { for (f in lines) printf "%d\t%d\t%d\t%s\n", lines[f] * commits[f], lines[f], commits[f], f }
' | sort -t $'\t' -k1,1nr -k2,2nr)

[ -n "$rows" ] || {
  echo "No code files under $path on $ref." >&2
  exit 1
}
echo '| File | Lines | Commits in 60 days | Score |'
echo '| --- | ---: | ---: | ---: |'
head -n 15 <<<"$rows" | awk -F'\t' '{ printf "| `%s` | %d | %d | %d |\n", $4, $2, $3, $1 }'
echo
echo "Measured on \`$ref\` at $(git rev-parse --short "$ref"), $(grep -c . <<<"$rows") code files."
# The renames of the whole tree: a move into the path has its source outside it.
moved=$(git -c core.quotePath=false log --since=60.days -M --diff-filter=R --name-only --format= "$ref" |
  sort -u | grep -cFxf <(cut -f4 <<<"$rows") || true)
[ "$moved" -eq 0 ] || echo "Code files moved in 60 days: $moved. Their commits count from the move."
